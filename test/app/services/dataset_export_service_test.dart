import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_label/app/models/dataset_export_config.dart';
import 'package:flutter_label/app/services/dataset_export_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('DatasetExportService', () {
    late Directory tempDir;
    late DatasetExportService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'dataset_export_service_test_',
      );
      service = const DatasetExportService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('可以按比例导出 YOLO 数据集并生成 zip', () async {
      final projectDir = await _createProject(tempDir);
      final outputDir = Directory('${tempDir.path}/export_out');

      final result = await service.export(
        DatasetExportConfig(
          projectDir: projectDir.path,
          outputDir: outputDir.path,
          trainRatio: 0.5,
          valRatio: 0.5,
          testRatio: 0,
          shuffle: false,
          includeEmptyLabels: true,
          createZip: true,
        ),
      );

      final dataYaml = await File('${outputDir.path}/data.yaml').readAsString();
      final zipBytes = await File('${outputDir.path}.zip').readAsBytes();

      expect(result.trainCount, 1);
      expect(result.valCount, 1);
      expect(result.testCount, 0);
      expect(result.emptyLabelCount, 1);
      expect(File('${outputDir.path}/images/train/a.png').existsSync(), isTrue);
      expect(File('${outputDir.path}/labels/train/a.txt').existsSync(), isTrue);
      expect(File('${outputDir.path}/images/val/b.png').existsSync(), isTrue);
      expect(
        await File('${outputDir.path}/labels/val/b.txt').readAsString(),
        isEmpty,
      );
      expect(dataYaml, contains('train: images/train'));
      expect(dataYaml, contains("0: 'enemy'"));
      expect(zipBytes.take(4), [0x50, 0x4b, 0x03, 0x04]);
    });

    test('关闭空标签时会跳过空标签和重复图片', () async {
      final projectDir = await _createProject(tempDir);
      final imagesDir = Directory('${projectDir.path}/images');
      final labelsDir = Directory('${projectDir.path}/labels');
      await File('${imagesDir.path}/a.png').copy('${imagesDir.path}/c.png');
      await File('${labelsDir.path}/a.txt').copy('${labelsDir.path}/c.txt');
      final outputDir = Directory('${tempDir.path}/export_no_empty');

      final result = await service.export(
        DatasetExportConfig(
          projectDir: projectDir.path,
          outputDir: outputDir.path,
          trainRatio: 1,
          valRatio: 0,
          testRatio: 0,
          shuffle: false,
          includeEmptyLabels: false,
          createZip: false,
        ),
      );

      expect(result.exportedCount, 1);
      expect(result.skippedCount, 2);
      expect(result.duplicateCount, 1);
      expect(File('${outputDir.path}/images/train/a.png').existsSync(), isTrue);
      expect(
        File('${outputDir.path}/images/train/b.png').existsSync(),
        isFalse,
      );
      expect(
        File('${outputDir.path}/images/train/c.png').existsSync(),
        isFalse,
      );
    });

    test('输出目录位于项目目录内时会被拒绝且不删除原始数据', () async {
      final projectDir = await _createProject(tempDir);
      final outputDir = Directory('${projectDir.path}/export_out');

      expect(
        () => service.export(
          DatasetExportConfig(
            projectDir: projectDir.path,
            outputDir: outputDir.path,
            trainRatio: 0.8,
            valRatio: 0.2,
            testRatio: 0,
            shuffle: false,
            includeEmptyLabels: true,
            createZip: false,
          ),
        ),
        throwsFormatException,
      );

      expect(File('${projectDir.path}/images/a.png').existsSync(), isTrue);
      expect(File('${projectDir.path}/labels/a.txt').existsSync(), isTrue);
    });

    test('没有可导出图片时不会删除已存在的输出目录', () async {
      final projectDir = await _createOnlyEmptyLabelProject(tempDir);
      final outputDir = Directory('${tempDir.path}/existing_export_out');
      final oldFile = File('${outputDir.path}/keep.txt');
      await outputDir.create(recursive: true);
      await oldFile.writeAsString('old data');

      await expectLater(
        service.export(
          DatasetExportConfig(
            projectDir: projectDir.path,
            outputDir: outputDir.path,
            trainRatio: 1,
            valRatio: 0,
            testRatio: 0,
            shuffle: false,
            includeEmptyLabels: false,
            createZip: false,
          ),
        ),
        throwsFormatException,
      );

      expect(oldFile.existsSync(), isTrue);
      expect(await oldFile.readAsString(), 'old data');
    });

    test('零比例拆分不会接收余数样本', () async {
      final projectDir = await _createThreeImageProject(tempDir);
      final outputDir = Directory('${tempDir.path}/export_split');

      final result = await service.export(
        DatasetExportConfig(
          projectDir: projectDir.path,
          outputDir: outputDir.path,
          trainRatio: 0.8,
          valRatio: 0.2,
          testRatio: 0,
          shuffle: false,
          includeEmptyLabels: true,
          createZip: false,
        ),
      );

      expect(result.trainCount, 2);
      expect(result.valCount, 1);
      expect(result.testCount, 0);
      expect(File('${outputDir.path}/images/test').existsSync(), isFalse);
    });
  });
}

Future<Directory> _createProject(Directory root) async {
  final projectDir = Directory('${root.path}/project');
  final imagesDir = Directory('${projectDir.path}/images');
  final labelsDir = Directory('${projectDir.path}/labels');
  await imagesDir.create(recursive: true);
  await labelsDir.create(recursive: true);
  await _writePng(File('${imagesDir.path}/a.png'), const ui.Color(0xFFFFFFFF));
  await _writePng(File('${imagesDir.path}/b.png'), const ui.Color(0xFFFF0000));
  await File(
    '${labelsDir.path}/a.txt',
  ).writeAsString('0 0.500000 0.500000 0.200000 0.400000');
  await File('${labelsDir.path}/b.txt').writeAsString('');
  await _writeDataYaml(projectDir, const ['enemy']);
  return projectDir;
}

Future<Directory> _createThreeImageProject(Directory root) async {
  final projectDir = Directory('${root.path}/project_three');
  final imagesDir = Directory('${projectDir.path}/images');
  final labelsDir = Directory('${projectDir.path}/labels');
  await imagesDir.create(recursive: true);
  await labelsDir.create(recursive: true);
  await _writePng(File('${imagesDir.path}/a.png'), const ui.Color(0xFFFFFFFF));
  await _writePng(File('${imagesDir.path}/b.png'), const ui.Color(0xFF0000FF));
  await _writePng(File('${imagesDir.path}/c.png'), const ui.Color(0xFF00FF00));
  for (final name in ['a', 'b', 'c']) {
    await File(
      '${labelsDir.path}/$name.txt',
    ).writeAsString('0 0.500000 0.500000 0.200000 0.400000');
  }
  await _writeDataYaml(projectDir, const ['enemy']);
  return projectDir;
}

Future<Directory> _createOnlyEmptyLabelProject(Directory root) async {
  final projectDir = Directory('${root.path}/project_empty_only');
  final imagesDir = Directory('${projectDir.path}/images');
  final labelsDir = Directory('${projectDir.path}/labels');
  await imagesDir.create(recursive: true);
  await labelsDir.create(recursive: true);
  await _writePng(
    File('${imagesDir.path}/empty.png'),
    const ui.Color(0xFFFFFFFF),
  );
  await File('${labelsDir.path}/empty.txt').writeAsString('');
  await _writeDataYaml(projectDir, const ['enemy']);
  return projectDir;
}

Future<void> _writeDataYaml(
  Directory projectDir,
  List<String> classNames,
) async {
  final buffer = StringBuffer()
    ..writeln('path: .')
    ..writeln('names:');
  for (var index = 0; index < classNames.length; index++) {
    final escapedName = classNames[index].replaceAll("'", "''");
    buffer.writeln("  $index: '$escapedName'");
  }
  await File('${projectDir.path}/data.yaml').writeAsString(buffer.toString());
}

Future<void> _writePng(File file, ui.Color color) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(recorder);
  canvas.drawRect(
    const ui.Rect.fromLTWH(0, 0, 10, 10),
    ui.Paint()..color = color,
  );
  final image = await recorder.endRecording().toImage(10, 10);
  final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
  image.dispose();
  if (byteData == null) {
    throw StateError('测试图片编码失败');
  }
  await file.writeAsBytes(Uint8List.view(byteData.buffer));
}
