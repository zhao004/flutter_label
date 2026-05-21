import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/dataset_split.dart';
import '../models/image_item.dart';
import '../utils/image_utils.dart';

class DatasetPaths {
  const DatasetPaths({
    required this.datasetRoot,
    required this.imageDir,
    required this.labelDir,
    required this.dataYamlPath,
  });

  final String datasetRoot;
  final String imageDir;
  final String labelDir;
  final String dataYamlPath;
}

class ImageScanResult {
  const ImageScanResult({
    required this.paths,
    required this.images,
    required this.warnings,
  });

  final DatasetPaths paths;
  final List<ImageItem> images;
  final List<String> warnings;
}

class ImageScanService {
  const ImageScanService();

  static const supportedExtensions = {'.jpg', '.jpeg', '.png', '.bmp', '.webp'};

  Future<ImageScanResult> scanImagesDirectory(String imageDir) async {
    final paths = validateDatasetImagesDir(imageDir);
    final directory = Directory(paths.imageDir);
    if (!await directory.exists()) {
      throw FileSystemException('图片目录不存在', paths.imageDir);
    }

    final files = await directory
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where(
          (file) => supportedExtensions.contains(
            p.extension(file.path).toLowerCase(),
          ),
        )
        .toList();

    files.sort(
      (left, right) => p
          .relative(left.path, from: paths.imageDir)
          .compareTo(p.relative(right.path, from: paths.imageDir)),
    );

    final images = <ImageItem>[];
    final warnings = <String>[];
    for (final file in files) {
      try {
        final size = await ImageUtils.readImageSize(file);
        final relativePath = p.relative(file.path, from: paths.imageDir);
        final labelPath = p.join(
          paths.labelDir,
          p.setExtension(relativePath, '.txt'),
        );
        images.add(
          ImageItem(
            path: file.path,
            labelPath: labelPath,
            fileName: p.basename(file.path),
            relativePath: relativePath,
            width: size.width,
            height: size.height,
          ),
        );
      } catch (error) {
        warnings.add('${file.path}: 图片无法解码，已跳过（$error）');
      }
    }

    if (images.isEmpty) {
      throw const FormatException('图片目录内未找到可用图片');
    }

    return ImageScanResult(paths: paths, images: images, warnings: warnings);
  }

  Future<ImageScanResult> scanDatasetRoot(String datasetRoot) async {
    final paths = validateDatasetRoot(datasetRoot);
    final files =
        <({File file, DatasetSplit split, String splitRelativePath})>[];
    for (final split in DatasetSplit.values) {
      final splitImageDir = Directory(
        p.join(paths.imageDir, split.directoryName),
      );
      if (!await splitImageDir.exists()) {
        continue;
      }
      final splitFiles = await splitImageDir
          .list(recursive: true, followLinks: false)
          .where((entity) => entity is File)
          .cast<File>()
          .where(
            (file) => supportedExtensions.contains(
              p.extension(file.path).toLowerCase(),
            ),
          )
          .toList();
      for (final file in splitFiles) {
        files.add((
          file: file,
          split: split,
          splitRelativePath: p.relative(file.path, from: splitImageDir.path),
        ));
      }
    }

    files.sort(
      (left, right) => p
          .join(left.split.directoryName, left.splitRelativePath)
          .compareTo(
            p.join(right.split.directoryName, right.splitRelativePath),
          ),
    );

    final images = <ImageItem>[];
    final warnings = <String>[];
    for (final item in files) {
      try {
        final size = await ImageUtils.readImageSize(item.file);
        final relativePath = p.join(
          'images',
          item.split.directoryName,
          item.splitRelativePath,
        );
        final labelPath = p.join(
          paths.labelDir,
          item.split.directoryName,
          p.setExtension(item.splitRelativePath, '.txt'),
        );
        images.add(
          ImageItem(
            path: item.file.path,
            labelPath: labelPath,
            fileName: p.basename(item.file.path),
            relativePath: relativePath,
            width: size.width,
            height: size.height,
          ),
        );
      } catch (error) {
        warnings.add('${item.file.path}: 图片无法解码，已跳过（$error）');
      }
    }

    return ImageScanResult(paths: paths, images: images, warnings: warnings);
  }

  DatasetPaths validateDatasetImagesDir(String imageDir) {
    final trimmed = imageDir.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('请选择数据集根目录或 images 目录');
    }

    final normalized = p.normalize(trimmed);
    final datasetRoot = p.basename(normalized).toLowerCase() == 'images'
        ? p.dirname(normalized)
        : normalized;
    final resolvedImageDir = p.join(datasetRoot, 'images');
    if (!Directory(resolvedImageDir).existsSync() &&
        p.basename(normalized).toLowerCase() != 'images') {
      throw const FormatException('请选择数据集根目录或 images 目录');
    }

    return DatasetPaths(
      datasetRoot: datasetRoot,
      imageDir: resolvedImageDir,
      labelDir: p.join(datasetRoot, 'labels'),
      dataYamlPath: p.join(datasetRoot, 'data.yaml'),
    );
  }

  DatasetPaths validateDatasetRoot(String datasetRoot) {
    final trimmed = datasetRoot.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('请选择数据集项目根目录');
    }
    final normalized = p.normalize(trimmed);
    final dataYaml = File(p.join(normalized, 'data.yaml'));
    if (!dataYaml.existsSync()) {
      throw FileSystemException('数据集根目录缺少 data.yaml', dataYaml.path);
    }
    return DatasetPaths(
      datasetRoot: normalized,
      imageDir: p.join(normalized, 'images'),
      labelDir: p.join(normalized, 'labels'),
      dataYamlPath: dataYaml.path,
    );
  }
}
