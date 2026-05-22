import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:path/path.dart' as p;

import '../models/dataset_export_config.dart';
import '../utils/image_utils.dart';
import 'data_yaml_service.dart';

typedef DatasetExportCancelChecker = bool Function();

class DatasetExportCancelledException implements Exception {
  const DatasetExportCancelledException();

  @override
  String toString() => '数据集导出已停止';
}

void _throwIfDatasetExportCancelled(DatasetExportCancelChecker? isCancelled) {
  if (isCancelled?.call() ?? false) {
    throw const DatasetExportCancelledException();
  }
}

Future<void> _yieldForDatasetExportCancellation(
  DatasetExportCancelChecker? isCancelled,
) async {
  _throwIfDatasetExportCancelled(isCancelled);
  await Future<void>.delayed(Duration.zero);
  _throwIfDatasetExportCancelled(isCancelled);
}

class _ExportItem {
  const _ExportItem({
    required this.imageFile,
    required this.labelFile,
    required this.relativeImagePath,
    required this.isEmptyLabel,
  });

  final File imageFile;
  final File labelFile;
  final String relativeImagePath;
  final bool isEmptyLabel;
}

class _SplitItems {
  const _SplitItems({
    required this.train,
    required this.val,
    required this.test,
  });

  final List<_ExportItem> train;
  final List<_ExportItem> val;
  final List<_ExportItem> test;
}

/// 负责把当前标注项目整理为可直接用于 Ultralytics YOLO 训练的数据集。
class DatasetExportService {
  const DatasetExportService({
    DataYamlService dataYamlService = const DataYamlService(),
  }) : _dataYamlService = dataYamlService;

  static const imageExtensions = {'.jpg', '.jpeg', '.png', '.bmp', '.webp'};
  static const _shuffleSeed = 20260519;

  final DataYamlService _dataYamlService;

  Future<DatasetExportResult> export(
    DatasetExportConfig config, {
    DatasetExportCancelChecker? isCancelled,
  }) async {
    _validateConfig(config);
    _throwIfDatasetExportCancelled(isCancelled);
    final logs = <String>[];
    final projectDir = Directory(config.projectDir);
    final outputDir = Directory(config.outputDir);
    final imagesDir = Directory(p.join(projectDir.path, 'images'));
    final labelsDir = Directory(p.join(projectDir.path, 'labels'));
    final dataYamlFile = File(p.join(projectDir.path, 'data.yaml'));

    if (!await imagesDir.exists()) {
      throw FileSystemException('项目 images 目录不存在', imagesDir.path);
    }
    if (!await labelsDir.exists()) {
      throw FileSystemException('项目 labels 目录不存在', labelsDir.path);
    }
    if (!await dataYamlFile.exists()) {
      throw FileSystemException('项目 data.yaml 不存在', dataYamlFile.path);
    }

    final classes = await _readClasses(dataYamlFile.path);
    _throwIfDatasetExportCancelled(isCancelled);
    final scan = await _collectItems(
      imagesDir: imagesDir,
      labelsDir: labelsDir,
      includeEmptyLabels: config.includeEmptyLabels,
      logs: logs,
      isCancelled: isCancelled,
    );
    _throwIfDatasetExportCancelled(isCancelled);
    final items = scan.items;
    if (items.isEmpty) {
      throw const FormatException('没有可导出的图片，请检查标签和空标签选项');
    }

    final split = _splitItems(
      items,
      trainRatio: config.trainRatio,
      valRatio: config.valRatio,
      testRatio: config.testRatio,
      shuffle: config.shuffle,
    );

    String? zipPath;
    if (config.createZip) {
      zipPath = '${outputDir.path}.zip';
    }

    final workingDir = Directory(
      _temporarySiblingPath(outputDir.path, purpose: 'working'),
    );
    final tempZipFile = File('${workingDir.path}.zip');
    try {
      if (await workingDir.exists()) {
        await workingDir.delete(recursive: true);
      }
      await workingDir.create(recursive: true);
      await _copySplit(workingDir, split.train, 'train', logs, isCancelled);
      await _copySplit(workingDir, split.val, 'val', logs, isCancelled);
      await _copySplit(workingDir, split.test, 'test', logs, isCancelled);
      _throwIfDatasetExportCancelled(isCancelled);
      await _writeDataYaml(workingDir, classes);

      if (config.createZip) {
        _throwIfDatasetExportCancelled(isCancelled);
        await _StoredZipWriter().writeDirectory(
          sourceDir: workingDir,
          outputFile: tempZipFile,
          isCancelled: isCancelled,
        );
      }

      _throwIfDatasetExportCancelled(isCancelled);
      await _replaceDirectory(sourceDir: workingDir, targetDir: outputDir);
      if (config.createZip) {
        await _replaceFile(sourceFile: tempZipFile, targetFile: File(zipPath!));
        logs.add('已生成 ZIP：$zipPath');
      }
    } finally {
      if (await workingDir.exists()) {
        await workingDir.delete(recursive: true);
      }
      if (await tempZipFile.exists()) {
        await tempZipFile.delete();
      }
    }

    logs.add(
      '导出完成：train ${split.train.length}，val ${split.val.length}，test ${split.test.length}。',
    );
    return DatasetExportResult(
      trainCount: split.train.length,
      valCount: split.val.length,
      testCount: split.test.length,
      skippedCount: scan.skippedCount,
      emptyLabelCount: scan.emptyLabelCount,
      duplicateCount: scan.duplicateCount,
      logs: logs,
      zipPath: zipPath,
    );
  }

  Future<_CollectResult> _collectItems({
    required Directory imagesDir,
    required Directory labelsDir,
    required bool includeEmptyLabels,
    required List<String> logs,
    required DatasetExportCancelChecker? isCancelled,
  }) async {
    final files = await imagesDir
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where(
          (file) =>
              imageExtensions.contains(p.extension(file.path).toLowerCase()),
        )
        .toList();
    files.sort((left, right) => left.path.compareTo(right.path));

    final items = <_ExportItem>[];
    final seenHashes = <String, String>{};
    var skipped = 0;
    var emptyLabels = 0;
    var duplicates = 0;
    for (final imageFile in files) {
      await _yieldForDatasetExportCancellation(isCancelled);
      final relativeImagePath = p.relative(
        imageFile.path,
        from: imagesDir.path,
      );
      final labelFile = File(
        p.join(labelsDir.path, p.setExtension(relativeImagePath, '.txt')),
      );
      try {
        await ImageUtils.readImageSize(imageFile);
      } catch (error) {
        skipped++;
        logs.add('损坏图片已跳过：${imageFile.path}，原因：$error');
        continue;
      }

      final hash = await _fingerprint(imageFile, isCancelled);
      _throwIfDatasetExportCancelled(isCancelled);
      final existing = seenHashes[hash];
      if (existing != null) {
        duplicates++;
        skipped++;
        logs.add('重复图片已跳过：${imageFile.path}，首个文件：$existing');
        continue;
      }
      seenHashes[hash] = imageFile.path;

      final hasLabel = await labelFile.exists();
      final isEmptyLabel =
          !hasLabel || (await labelFile.readAsString()).trim().isEmpty;
      if (isEmptyLabel) {
        emptyLabels++;
      }
      if (isEmptyLabel && !includeEmptyLabels) {
        skipped++;
        logs.add('空标签图片已跳过：${imageFile.path}');
        continue;
      }

      items.add(
        _ExportItem(
          imageFile: imageFile,
          labelFile: labelFile,
          relativeImagePath: relativeImagePath,
          isEmptyLabel: isEmptyLabel,
        ),
      );
    }
    return _CollectResult(
      items: items,
      skippedCount: skipped,
      emptyLabelCount: emptyLabels,
      duplicateCount: duplicates,
    );
  }

  _SplitItems _splitItems(
    List<_ExportItem> items, {
    required double trainRatio,
    required double valRatio,
    required double testRatio,
    required bool shuffle,
  }) {
    final working = [...items];
    if (shuffle) {
      working.shuffle(Random(_shuffleSeed));
    }
    final total = working.length;
    final counts = _splitCounts(
      total: total,
      ratios: [trainRatio, valRatio, testRatio],
    );
    final safeTrainCount = counts[0];
    final safeValCount = counts[1];
    return _SplitItems(
      train: working.sublist(0, safeTrainCount),
      val: working.sublist(safeTrainCount, safeTrainCount + safeValCount),
      test: working.sublist(safeTrainCount + safeValCount),
    );
  }

  List<int> _splitCounts({required int total, required List<double> ratios}) {
    final desiredCounts = [for (final ratio in ratios) total * ratio];
    final counts = [for (final desired in desiredCounts) desired.floor()];
    var remaining = total - counts.fold<int>(0, (sum, count) => sum + count);
    final eligibleIndexes =
        [
          for (var index = 0; index < ratios.length; index++)
            if (ratios[index] > 0) index,
        ]..sort((left, right) {
          final fractionCompare = (desiredCounts[right] - counts[right])
              .compareTo(desiredCounts[left] - counts[left]);
          if (fractionCompare != 0) {
            return fractionCompare;
          }
          final ratioCompare = ratios[right].compareTo(ratios[left]);
          return ratioCompare != 0 ? ratioCompare : left.compareTo(right);
        });

    var cursor = 0;
    while (remaining > 0 && eligibleIndexes.isNotEmpty) {
      counts[eligibleIndexes[cursor % eligibleIndexes.length]]++;
      remaining--;
      cursor++;
    }
    return counts;
  }

  Future<void> _copySplit(
    Directory outputDir,
    List<_ExportItem> items,
    String split,
    List<String> logs,
    DatasetExportCancelChecker? isCancelled,
  ) async {
    for (final item in items) {
      await _yieldForDatasetExportCancellation(isCancelled);
      final imageOutput = File(
        p.join(outputDir.path, 'images', split, item.relativeImagePath),
      );
      final labelOutput = File(
        p.join(
          outputDir.path,
          'labels',
          split,
          p.setExtension(item.relativeImagePath, '.txt'),
        ),
      );
      await imageOutput.parent.create(recursive: true);
      await labelOutput.parent.create(recursive: true);
      await item.imageFile.copy(imageOutput.path);
      if (await item.labelFile.exists()) {
        await item.labelFile.copy(labelOutput.path);
      } else {
        await labelOutput.writeAsString('');
      }
      if (item.isEmptyLabel) {
        logs.add('已导出空标签：${item.relativeImagePath}');
      }
    }
  }

  Future<void> _writeDataYaml(Directory outputDir, List<String> classes) async {
    await _dataYamlService.writeClasses(
      dataYamlPath: p.join(outputDir.path, 'data.yaml'),
      classNames: classes,
    );
  }

  Future<List<String>> _readClasses(String dataYamlPath) async {
    final classes = await _dataYamlService.readClassNames(dataYamlPath);
    if (classes.isEmpty) {
      throw const FormatException('data.yaml 的 names 不能为空');
    }
    return classes;
  }

  Future<String> _fingerprint(
    File file,
    DatasetExportCancelChecker? isCancelled,
  ) async {
    var hash = 0xcbf29ce484222325;
    var length = 0;
    await for (final chunk in file.openRead()) {
      _throwIfDatasetExportCancelled(isCancelled);
      length += chunk.length;
      for (final byte in chunk) {
        hash ^= byte;
        hash = (hash * 0x100000001b3) & 0x7fffffffffffffff;
      }
      await _yieldForDatasetExportCancellation(isCancelled);
    }
    return '$length:$hash';
  }

  void _validateConfig(DatasetExportConfig config) {
    if (config.projectDir.trim().isEmpty ||
        !Directory(config.projectDir).existsSync()) {
      throw FileSystemException('项目目录不存在', config.projectDir);
    }
    if (config.outputDir.trim().isEmpty) {
      throw const FormatException('输出目录不能为空');
    }
    if (File(config.outputDir).existsSync()) {
      throw const FormatException('输出路径不能是文件');
    }
    if (_isSameOrNestedPath(config.projectDir, config.outputDir)) {
      throw const FormatException('输出目录不能与项目目录互相包含');
    }
    final ratios = [config.trainRatio, config.valRatio, config.testRatio];
    if (ratios.any((ratio) => ratio.isNaN || ratio < 0 || ratio > 1)) {
      throw const FormatException('划分比例必须在 0 到 1 之间');
    }
    final sum = config.trainRatio + config.valRatio + config.testRatio;
    if ((sum - 1).abs() > 0.000001) {
      throw const FormatException('train/val/test 比例总和必须等于 100%');
    }
  }

  bool _isSameOrNestedPath(String left, String right) {
    final normalizedLeft = p.normalize(p.absolute(left));
    final normalizedRight = p.normalize(p.absolute(right));
    return p.equals(normalizedLeft, normalizedRight) ||
        p.isWithin(normalizedLeft, normalizedRight) ||
        p.isWithin(normalizedRight, normalizedLeft);
  }

  String _temporarySiblingPath(String targetPath, {required String purpose}) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    return p.join(
      p.dirname(targetPath),
      '.${p.basename(targetPath)}.$purpose.$timestamp',
    );
  }

  Future<void> _replaceDirectory({
    required Directory sourceDir,
    required Directory targetDir,
  }) async {
    final backupDir = Directory(
      _temporarySiblingPath(targetDir.path, purpose: 'backup'),
    );
    if (await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }
    var hasBackup = false;
    if (await targetDir.exists()) {
      await targetDir.rename(backupDir.path);
      hasBackup = true;
    }

    try {
      await sourceDir.rename(targetDir.path);
    } catch (_) {
      if (hasBackup && !await targetDir.exists() && await backupDir.exists()) {
        await backupDir.rename(targetDir.path);
      }
      rethrow;
    }

    if (hasBackup && await backupDir.exists()) {
      await backupDir.delete(recursive: true);
    }
  }

  Future<void> _replaceFile({
    required File sourceFile,
    required File targetFile,
  }) async {
    await targetFile.parent.create(recursive: true);
    final backupFile = File(
      _temporarySiblingPath(targetFile.path, purpose: 'backup'),
    );
    if (await backupFile.exists()) {
      await backupFile.delete();
    }
    var hasBackup = false;
    if (await targetFile.exists()) {
      await targetFile.rename(backupFile.path);
      hasBackup = true;
    }

    try {
      await sourceFile.rename(targetFile.path);
    } catch (_) {
      if (hasBackup &&
          !await targetFile.exists() &&
          await backupFile.exists()) {
        await backupFile.rename(targetFile.path);
      }
      rethrow;
    }

    if (hasBackup && await backupFile.exists()) {
      await backupFile.delete();
    }
  }
}

class _CollectResult {
  const _CollectResult({
    required this.items,
    required this.skippedCount,
    required this.emptyLabelCount,
    required this.duplicateCount,
  });

  final List<_ExportItem> items;
  final int skippedCount;
  final int emptyLabelCount;
  final int duplicateCount;
}

class _ZipEntry {
  const _ZipEntry({
    required this.name,
    required this.crc32,
    required this.size,
    required this.localHeaderOffset,
  });

  final String name;
  final int crc32;
  final int size;
  final int localHeaderOffset;
}

class _ZipFileScan {
  const _ZipFileScan({required this.crc32, required this.size});

  final int crc32;
  final int size;
}

/// 写入 ZIP 的 store 模式，避免为一个打包功能引入额外依赖。
class _StoredZipWriter {
  static const _zipMaxEntryCount = 0xffff;
  static const _zipMax32Value = 0xffffffff;
  static const _zipUtf8Flag = 0x0800;

  static final List<int> _crcTable = List<int>.generate(256, (index) {
    var crc = index;
    for (var bit = 0; bit < 8; bit++) {
      crc = (crc & 1) == 1 ? 0xedb88320 ^ (crc >> 1) : crc >> 1;
    }
    return crc;
  });

  Future<void> writeDirectory({
    required Directory sourceDir,
    required File outputFile,
    DatasetExportCancelChecker? isCancelled,
  }) async {
    final files = await sourceDir
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => !p.equals(file.path, outputFile.path))
        .toList();
    files.sort((left, right) => left.path.compareTo(right.path));
    if (files.length > _zipMaxEntryCount) {
      throw const FormatException('ZIP 文件数量超过 65535，内置 ZIP 写入器不支持 ZIP64');
    }

    if (await outputFile.exists()) {
      await outputFile.delete();
    }
    await outputFile.parent.create(recursive: true);
    final sink = outputFile.openWrite();
    var offset = 0;
    final entries = <_ZipEntry>[];
    try {
      for (final file in files) {
        await _yieldForDatasetExportCancellation(isCancelled);
        final relativeName = p
            .relative(file.path, from: sourceDir.path)
            .replaceAll(Platform.pathSeparator, '/');
        final scan = await _scanFile(file, isCancelled);
        _checkZip32(scan.size, 'ZIP 文件过大：$relativeName');
        final nameBytes = utf8.encode(relativeName);
        _checkZipName(nameBytes, relativeName);
        _checkZip32(offset, 'ZIP 中央目录偏移超过传统格式上限');
        final localHeader = _localHeader(nameBytes, scan.crc32, scan.size);
        _checkZip32(offset + localHeader.length + scan.size, 'ZIP 内容超过传统格式上限');
        sink.add(localHeader);
        await _writeFileBytes(sink, file, isCancelled);
        entries.add(
          _ZipEntry(
            name: relativeName,
            crc32: scan.crc32,
            size: scan.size,
            localHeaderOffset: offset,
          ),
        );
        offset += localHeader.length + scan.size;
      }

      final centralStart = offset;
      _checkZip32(centralStart, 'ZIP 中央目录偏移超过传统格式上限');
      var centralSize = 0;
      for (final entry in entries) {
        _throwIfDatasetExportCancelled(isCancelled);
        final header = _centralHeader(entry);
        sink.add(header);
        centralSize += header.length;
        _checkZip32(centralSize, 'ZIP 中央目录大小超过传统格式上限');
      }
      _checkZip32(centralStart + centralSize, 'ZIP 文件大小超过传统格式上限');
      sink.add(
        _endOfCentralDirectory(entries.length, centralSize, centralStart),
      );
    } finally {
      await sink.close();
    }
  }

  Future<_ZipFileScan> _scanFile(
    File file,
    DatasetExportCancelChecker? isCancelled,
  ) async {
    var crc = 0xffffffff;
    var size = 0;
    await for (final chunk in file.openRead()) {
      _throwIfDatasetExportCancelled(isCancelled);
      size += chunk.length;
      crc = _updateCrc32(crc, chunk);
      await _yieldForDatasetExportCancellation(isCancelled);
    }
    return _ZipFileScan(crc32: (crc ^ 0xffffffff) & 0xffffffff, size: size);
  }

  Future<void> _writeFileBytes(
    IOSink sink,
    File file,
    DatasetExportCancelChecker? isCancelled,
  ) async {
    await for (final chunk in file.openRead()) {
      _throwIfDatasetExportCancelled(isCancelled);
      sink.add(chunk);
      await _yieldForDatasetExportCancellation(isCancelled);
    }
  }

  int _updateCrc32(int crc, List<int> bytes) {
    var next = crc;
    for (final byte in bytes) {
      next = _crcTable[(next ^ byte) & 0xff] ^ (next >> 8);
    }
    return next;
  }

  Uint8List _localHeader(List<int> nameBytes, int crc32, int size) {
    final data = BytesBuilder();
    data.add(_u32(0x04034b50));
    data.add(_u16(20));
    data.add(_u16(_zipUtf8Flag));
    data.add(_u16(0));
    data.add(_u16(0));
    data.add(_u16(0));
    data.add(_u32(crc32));
    data.add(_u32(size));
    data.add(_u32(size));
    data.add(_u16(nameBytes.length));
    data.add(_u16(0));
    data.add(nameBytes);
    return data.toBytes();
  }

  Uint8List _centralHeader(_ZipEntry entry) {
    final nameBytes = utf8.encode(entry.name);
    final data = BytesBuilder();
    data.add(_u32(0x02014b50));
    data.add(_u16(20));
    data.add(_u16(20));
    data.add(_u16(_zipUtf8Flag));
    data.add(_u16(0));
    data.add(_u16(0));
    data.add(_u16(0));
    data.add(_u32(entry.crc32));
    data.add(_u32(entry.size));
    data.add(_u32(entry.size));
    data.add(_u16(nameBytes.length));
    data.add(_u16(0));
    data.add(_u16(0));
    data.add(_u16(0));
    data.add(_u16(0));
    data.add(_u32(0));
    data.add(_u32(entry.localHeaderOffset));
    data.add(nameBytes);
    return data.toBytes();
  }

  Uint8List _endOfCentralDirectory(
    int count,
    int centralSize,
    int centralStart,
  ) {
    final data = BytesBuilder();
    data.add(_u32(0x06054b50));
    data.add(_u16(0));
    data.add(_u16(0));
    data.add(_u16(count));
    data.add(_u16(count));
    data.add(_u32(centralSize));
    data.add(_u32(centralStart));
    data.add(_u16(0));
    return data.toBytes();
  }

  Uint8List _u16(int value) {
    final data = ByteData(2)..setUint16(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  Uint8List _u32(int value) {
    final data = ByteData(4)..setUint32(0, value, Endian.little);
    return data.buffer.asUint8List();
  }

  void _checkZipName(List<int> nameBytes, String relativeName) {
    if (nameBytes.isEmpty || nameBytes.length > _zipMaxEntryCount) {
      throw FormatException('ZIP 路径长度非法：$relativeName');
    }
  }

  void _checkZip32(int value, String message) {
    if (value < 0 || value > _zipMax32Value) {
      throw FormatException('$message，内置 ZIP 写入器不支持 ZIP64');
    }
  }
}
