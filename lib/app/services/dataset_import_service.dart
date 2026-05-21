import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/dataset_split.dart';
import '../utils/image_utils.dart';
import 'image_scan_service.dart';

class DatasetImportResult {
  const DatasetImportResult({
    required this.importedCount,
    required this.skippedCount,
    required this.importedRelativePaths,
    required this.logs,
  });

  final int importedCount;
  final int skippedCount;
  final List<String> importedRelativePaths;
  final List<String> logs;
}

class _ImportItem {
  const _ImportItem({required this.file, required this.relativePath});

  final File file;
  final String relativePath;
}

/// 负责把外部图片复制到标准 YOLO split，导入失败只跳过当前文件。
class DatasetImportService {
  const DatasetImportService();

  Future<DatasetImportResult> importFiles({
    required String datasetDir,
    required List<String> filePaths,
    required DatasetSplit split,
  }) {
    final items = [
      for (final filePath in filePaths)
        _ImportItem(file: File(filePath), relativePath: p.basename(filePath)),
    ];
    return _importItems(datasetDir: datasetDir, items: items, split: split);
  }

  Future<DatasetImportResult> importDirectory({
    required String datasetDir,
    required String sourceDir,
    required DatasetSplit split,
  }) async {
    final root = Directory(sourceDir);
    if (!await root.exists()) {
      throw FileSystemException('图片来源目录不存在', sourceDir);
    }

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

    final items = [
      for (final file in files)
        _ImportItem(
          file: file,
          relativePath: p.relative(file.path, from: root.path),
        ),
    ];
    return _importItems(datasetDir: datasetDir, items: items, split: split);
  }

  Future<DatasetImportResult> _importItems({
    required String datasetDir,
    required List<_ImportItem> items,
    required DatasetSplit split,
  }) async {
    final trimmedDatasetDir = datasetDir.trim();
    if (trimmedDatasetDir.isEmpty) {
      throw const FormatException('数据集目录不能为空');
    }
    final normalizedDatasetDir = p.normalize(trimmedDatasetDir);
    if (items.isEmpty) {
      throw const FormatException('未选择可导入的图片');
    }

    final imageRoot = Directory(
      p.join(normalizedDatasetDir, 'images', split.directoryName),
    );
    final labelRoot = Directory(
      p.join(normalizedDatasetDir, 'labels', split.directoryName),
    );
    await imageRoot.create(recursive: true);
    await labelRoot.create(recursive: true);

    final logs = <String>[];
    final importedRelativePaths = <String>[];
    var skippedCount = 0;

    for (final item in items) {
      final source = item.file;
      final extension = p.extension(source.path).toLowerCase();
      if (!ImageScanService.supportedExtensions.contains(extension)) {
        skippedCount++;
        logs.add('非图片文件已跳过：${source.path}');
        continue;
      }
      if (!await source.exists()) {
        skippedCount++;
        logs.add('来源文件不存在，已跳过：${source.path}');
        continue;
      }

      try {
        await ImageUtils.readImageSize(source);
        final safeRelativePath = _safeRelativePath(item.relativePath);
        final targetImage = await _uniqueTargetFile(
          p.join(imageRoot.path, safeRelativePath),
        );
        await targetImage.parent.create(recursive: true);
        await source.copy(targetImage.path);

        final splitRelativePath = p.relative(
          targetImage.path,
          from: imageRoot.path,
        );
        await Directory(
          p.dirname(
            p.join(labelRoot.path, p.setExtension(splitRelativePath, '.txt')),
          ),
        ).create(recursive: true);
        importedRelativePaths.add(
          p.join('images', split.directoryName, splitRelativePath),
        );
      } catch (error) {
        skippedCount++;
        logs.add('图片导入失败：${source.path}，原因：$error');
      }
    }

    if (importedRelativePaths.isEmpty) {
      throw FormatException('没有图片被导入：${logs.join('；')}');
    }

    logs.add(
      '导入完成：${split.label} ${importedRelativePaths.length} 张，跳过 $skippedCount 张。',
    );
    return DatasetImportResult(
      importedCount: importedRelativePaths.length,
      skippedCount: skippedCount,
      importedRelativePaths: List.unmodifiable(importedRelativePaths),
      logs: List.unmodifiable(logs),
    );
  }

  String _safeRelativePath(String value) {
    final normalized = p.normalize(value.trim());
    if (normalized.isEmpty ||
        normalized == '.' ||
        p.isAbsolute(normalized) ||
        normalized.split(p.separator).contains('..')) {
      return p.basename(value);
    }
    return normalized;
  }

  Future<File> _uniqueTargetFile(String desiredPath) async {
    var candidate = File(desiredPath);
    if (!await candidate.exists()) {
      return candidate;
    }

    final directory = p.dirname(desiredPath);
    final basename = p.basenameWithoutExtension(desiredPath);
    final extension = p.extension(desiredPath);
    for (var index = 1; index < 100000; index++) {
      candidate = File(p.join(directory, '${basename}_$index$extension'));
      if (!await candidate.exists()) {
        return candidate;
      }
    }
    throw FileSystemException('无法生成唯一文件名', desiredPath);
  }
}
