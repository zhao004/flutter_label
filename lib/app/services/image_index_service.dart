import 'dart:async';
import 'dart:io';

import 'package:drift/drift.dart' as drift;
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../database/database.dart';
import '../models/dataset_split.dart';
import '../models/image_annotation_status.dart';
import '../models/image_item.dart';
import '../utils/image_utils.dart';
import 'image_scan_service.dart';
import 'yolo_label_service.dart';

enum ImageIndexScanMode {
  imagesDirectory('images_directory'),
  datasetRoot('dataset_root');

  const ImageIndexScanMode(this.storageValue);

  final String storageValue;
}

class ImageIndexSnapshot {
  const ImageIndexSnapshot({
    required this.images,
    required this.statuses,
    required this.warnings,
  });

  final List<ImageItem> images;
  final Map<String, ImageAnnotationStatus> statuses;
  final List<String> warnings;
}

class ImageIndexUpdate {
  const ImageIndexUpdate({
    required this.upserts,
    required this.statuses,
    required this.removedRelativePaths,
    required this.warnings,
    required this.processedCount,
    required this.totalCount,
    required this.isComplete,
  });

  final List<ImageItem> upserts;
  final Map<String, ImageAnnotationStatus> statuses;
  final List<String> removedRelativePaths;
  final List<String> warnings;
  final int processedCount;
  final int totalCount;
  final bool isComplete;
}

class _DiscoveredImage {
  const _DiscoveredImage({
    required this.file,
    required this.relativePath,
    required this.labelPath,
  });

  final File file;
  final String relativePath;
  final String labelPath;
}

class _IndexedImageResult {
  const _IndexedImageResult({
    required this.image,
    required this.status,
    required this.warning,
    required this.companion,
  });

  final ImageItem image;
  final ImageAnnotationStatus status;
  final String? warning;
  final ImageIndexRecordsCompanion companion;
}

/// 使用 SQLite 缓存图片元数据，并以小批次刷新，避免大数据集打开时阻塞界面。
class ImageIndexService {
  const ImageIndexService({
    AppDatabase? database,
    YoloLabelService yoloLabelService = const YoloLabelService(),
  }) : _database = database,
       _yoloLabelService = yoloLabelService;

  static const int metadataBatchSize = 256;
  static const int dimensionScanConcurrency = 8;
  static const int statusScanConcurrency = 16;
  static const int _deleteBatchSize = 500;

  final AppDatabase? _database;
  final YoloLabelService _yoloLabelService;

  AppDatabase get _db {
    final injected = _database;
    if (injected != null) {
      return injected;
    }
    if (!Get.isRegistered<AppDatabase>()) {
      throw StateError('图片索引数据库未初始化');
    }
    return Get.find<AppDatabase>();
  }

  Future<ImageIndexSnapshot> loadCachedSnapshot({
    required DatasetPaths paths,
    required ImageIndexScanMode scanMode,
  }) async {
    final db = _db;
    final records =
        await (db.select(db.imageIndexRecords)
              ..where(
                (record) =>
                    record.datasetRoot.equals(paths.datasetRoot) &
                    record.scanMode.equals(scanMode.storageValue),
              )
              ..orderBy([
                (record) => drift.OrderingTerm(expression: record.relativePath),
              ]))
            .get();

    return ImageIndexSnapshot(
      images: [
        for (final record in records)
          ImageItem(
            path: record.imagePath,
            labelPath: record.labelPath,
            fileName: p.basename(record.imagePath),
            relativePath: record.relativePath,
            width: record.width,
            height: record.height,
          ),
      ],
      statuses: {
        for (final record in records)
          if (_statusFromStorage(record.annotationStatus) != null)
            record.relativePath: _statusFromStorage(record.annotationStatus)!,
      },
      warnings: const [],
    );
  }

  Future<ImageItem> resolveImageDimensions(ImageItem item) async {
    final size = await ImageUtils.readImageSize(File(item.path));
    return item.copyWith(width: size.width, height: size.height);
  }

  Future<void> refreshIndex({
    required DatasetPaths paths,
    required ImageIndexScanMode scanMode,
    required int classCount,
    required Set<String> completedImages,
    required bool Function() isCancelled,
    required void Function(ImageIndexUpdate update) onUpdate,
  }) async {
    final db = _db;
    final existingRecords = await loadCachedSnapshot(
      paths: paths,
      scanMode: scanMode,
    );
    if (isCancelled()) {
      return;
    }

    final existingByRelativePath = {
      for (final image in existingRecords.images) image.relativePath: image,
    };
    final discovered = await _discoverImages(paths, scanMode);
    if (isCancelled()) {
      return;
    }

    final discoveredPaths = discovered
        .map((image) => image.relativePath)
        .toSet();
    final removed = existingByRelativePath.keys
        .where((relativePath) => !discoveredPaths.contains(relativePath))
        .toList(growable: false);
    await _deleteRemoved(paths, scanMode, removed);
    if (isCancelled()) {
      return;
    }
    if (removed.isNotEmpty) {
      onUpdate(
        ImageIndexUpdate(
          upserts: const [],
          statuses: const {},
          removedRelativePaths: removed,
          warnings: const [],
          processedCount: 0,
          totalCount: discovered.length,
          isComplete: false,
        ),
      );
    }

    final cacheRecords = await _loadRecordMap(paths, scanMode);
    var processedCount = 0;
    for (var start = 0; start < discovered.length; start += metadataBatchSize) {
      if (isCancelled()) {
        return;
      }
      final end = start + metadataBatchSize > discovered.length
          ? discovered.length
          : start + metadataBatchSize;
      final batch = discovered.sublist(start, end);
      final results = await _mapWithConcurrency(
        batch,
        dimensionScanConcurrency,
        (image) => _indexImage(
          paths: paths,
          scanMode: scanMode,
          discovered: image,
          cachedRecord: cacheRecords[image.relativePath],
          classCount: classCount,
          completedImages: completedImages,
        ),
      );
      processedCount += results.length;
      if (isCancelled()) {
        return;
      }

      await db.batch((batchWriter) {
        batchWriter.insertAll(db.imageIndexRecords, [
          for (final result in results) result.companion,
        ], mode: drift.InsertMode.insertOrReplace);
      });
      if (isCancelled()) {
        return;
      }

      onUpdate(
        ImageIndexUpdate(
          upserts: [for (final result in results) result.image],
          statuses: {
            for (final result in results)
              result.image.relativePath: result.status,
          },
          removedRelativePaths: const [],
          warnings: [
            for (final result in results)
              if (result.warning != null) result.warning!,
          ],
          processedCount: processedCount,
          totalCount: discovered.length,
          isComplete: processedCount >= discovered.length,
        ),
      );
    }

    if (discovered.isEmpty && !isCancelled()) {
      onUpdate(
        ImageIndexUpdate(
          upserts: const [],
          statuses: const {},
          removedRelativePaths: const [],
          warnings: const [],
          processedCount: 0,
          totalCount: 0,
          isComplete: true,
        ),
      );
    }
  }

  Future<Map<String, ImageIndexRecord>> _loadRecordMap(
    DatasetPaths paths,
    ImageIndexScanMode scanMode,
  ) async {
    final db = _db;
    final records =
        await (db.select(db.imageIndexRecords)..where(
              (record) =>
                  record.datasetRoot.equals(paths.datasetRoot) &
                  record.scanMode.equals(scanMode.storageValue),
            ))
            .get();
    return {for (final record in records) record.relativePath: record};
  }

  Future<List<_DiscoveredImage>> _discoverImages(
    DatasetPaths paths,
    ImageIndexScanMode scanMode,
  ) async {
    return switch (scanMode) {
      ImageIndexScanMode.imagesDirectory => _discoverImagesDirectory(paths),
      ImageIndexScanMode.datasetRoot => _discoverDatasetRoot(paths),
    };
  }

  Future<List<_DiscoveredImage>> _discoverImagesDirectory(
    DatasetPaths paths,
  ) async {
    final root = Directory(paths.imageDir);
    if (!await root.exists()) {
      throw FileSystemException('图片目录不存在', paths.imageDir);
    }
    final files = await _listImageFiles(root);
    return [
      for (final file in files)
        _DiscoveredImage(
          file: file,
          relativePath: p.relative(file.path, from: paths.imageDir),
          labelPath: p.join(
            paths.labelDir,
            p.setExtension(p.relative(file.path, from: paths.imageDir), '.txt'),
          ),
        ),
    ];
  }

  Future<List<_DiscoveredImage>> _discoverDatasetRoot(
    DatasetPaths paths,
  ) async {
    final images = <_DiscoveredImage>[];
    for (final split in DatasetSplit.values) {
      final splitImageDir = Directory(
        p.join(paths.imageDir, split.directoryName),
      );
      if (!await splitImageDir.exists()) {
        continue;
      }
      final files = await _listImageFiles(splitImageDir);
      for (final file in files) {
        final splitRelativePath = p.relative(
          file.path,
          from: splitImageDir.path,
        );
        images.add(
          _DiscoveredImage(
            file: file,
            relativePath: p.join(
              'images',
              split.directoryName,
              splitRelativePath,
            ),
            labelPath: p.join(
              paths.labelDir,
              split.directoryName,
              p.setExtension(splitRelativePath, '.txt'),
            ),
          ),
        );
      }
    }
    images.sort(
      (left, right) => left.relativePath.compareTo(right.relativePath),
    );
    return images;
  }

  Future<List<File>> _listImageFiles(Directory root) async {
    final files = await root
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where(
          (file) => ImageScanService.supportedExtensions.contains(
            p.extension(file.path).toLowerCase(),
          ),
        )
        .toList();
    files.sort((left, right) => left.path.compareTo(right.path));
    return files;
  }

  Future<_IndexedImageResult> _indexImage({
    required DatasetPaths paths,
    required ImageIndexScanMode scanMode,
    required _DiscoveredImage discovered,
    required ImageIndexRecord? cachedRecord,
    required int classCount,
    required Set<String> completedImages,
  }) async {
    final stat = await discovered.file.stat();
    int? width;
    int? height;
    String? errorMessage;
    final cacheIsFresh =
        cachedRecord != null &&
        cachedRecord.fileSize == stat.size &&
        cachedRecord.modifiedAtMillis == stat.modified.millisecondsSinceEpoch &&
        cachedRecord.width != null &&
        cachedRecord.height != null &&
        cachedRecord.errorMessage == null;

    if (cacheIsFresh) {
      width = cachedRecord.width;
      height = cachedRecord.height;
    } else {
      try {
        final size = await ImageUtils.readImageSize(discovered.file);
        width = size.width;
        height = size.height;
      } catch (error) {
        errorMessage = '图片无法解码：$error';
      }
    }

    final status = errorMessage == null
        ? await _yoloLabelService.inspectLabelStatus(
            labelPath: discovered.labelPath,
            classCount: classCount,
            isCompleted: completedImages.contains(discovered.relativePath),
          )
        : ImageAnnotationStatus.labelError;
    final image = ImageItem(
      path: discovered.file.path,
      labelPath: discovered.labelPath,
      fileName: p.basename(discovered.file.path),
      relativePath: discovered.relativePath,
      width: width,
      height: height,
    );

    return _IndexedImageResult(
      image: image,
      status: status,
      warning: errorMessage == null
          ? null
          : '${discovered.file.path}: $errorMessage',
      companion: ImageIndexRecordsCompanion.insert(
        datasetRoot: paths.datasetRoot,
        scanMode: scanMode.storageValue,
        imagePath: discovered.file.path,
        relativePath: discovered.relativePath,
        labelPath: discovered.labelPath,
        fileSize: stat.size,
        modifiedAtMillis: stat.modified.millisecondsSinceEpoch,
        width: drift.Value(width),
        height: drift.Value(height),
        annotationStatus: drift.Value(status.name),
        errorMessage: drift.Value(errorMessage),
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<void> _deleteRemoved(
    DatasetPaths paths,
    ImageIndexScanMode scanMode,
    List<String> removed,
  ) async {
    if (removed.isEmpty) {
      return;
    }
    final db = _db;
    for (var start = 0; start < removed.length; start += _deleteBatchSize) {
      final end = start + _deleteBatchSize > removed.length
          ? removed.length
          : start + _deleteBatchSize;
      final batch = removed.sublist(start, end);
      await (db.delete(db.imageIndexRecords)..where(
            (record) =>
                record.datasetRoot.equals(paths.datasetRoot) &
                record.scanMode.equals(scanMode.storageValue) &
                record.relativePath.isIn(batch),
          ))
          .go();
    }
  }

  Future<List<T>> _mapWithConcurrency<S, T>(
    List<S> items,
    int concurrency,
    Future<T> Function(S item) mapper,
  ) async {
    if (concurrency <= 0) {
      throw ArgumentError.value(concurrency, 'concurrency', '并发数必须大于 0');
    }
    if (items.isEmpty) {
      return const [];
    }

    final results = List<T?>.filled(items.length, null);
    var nextIndex = 0;
    Future<void> worker() async {
      while (true) {
        final index = nextIndex;
        nextIndex += 1;
        if (index >= items.length) {
          return;
        }
        results[index] = await mapper(items[index]);
      }
    }

    final workerCount = concurrency > items.length ? items.length : concurrency;
    await Future.wait([
      for (var index = 0; index < workerCount; index += 1) worker(),
    ]);
    return [for (final result in results) result as T];
  }

  ImageAnnotationStatus? _statusFromStorage(String? value) {
    if (value == null) {
      return null;
    }
    for (final status in ImageAnnotationStatus.values) {
      if (status.name == value) {
        return status;
      }
    }
    return null;
  }
}
