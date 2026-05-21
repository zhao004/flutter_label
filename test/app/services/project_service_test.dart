import 'dart:io';

import 'package:flutter_label/app/models/project_config.dart';
import 'package:flutter_label/app/services/project_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('ProjectService', () {
    late Directory tempDir;
    late ProjectService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp('project_service_test_');
      service = const ProjectService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('写入后可以完整读取 project.json', () async {
      final config = ProjectConfig(
        projectName: 'game',
        datasetDir: tempDir.path,
        imageDir: '${tempDir.path}/images',
        labelDir: '${tempDir.path}/labels',
        classes: const ['enemy', 'npc'],
        completedImages: const ['a.jpg'],
      );

      final saved = await service.writeProject(config);
      final loaded = await service.readProject(saved.projectFilePath!);

      expect(loaded.projectName, 'game');
      expect(loaded.classes, ['enemy', 'npc']);
      expect(loaded.completedImages, ['a.jpg']);
      expect(loaded.projectFilePath, saved.projectFilePath);
      expect(
        await File('${tempDir.path}/data.yaml').readAsString(),
        contains("0: 'enemy'"),
      );
    });

    test('可以新建空 YOLO Detection 数据集项目', () async {
      final datasetDir = p.join(tempDir.path, 'empty_dataset');

      final config = await service.createDatasetProject(datasetDir);

      expect(config.datasetDir, datasetDir);
      expect(config.classes, isEmpty);
      expect(File('$datasetDir/data.yaml').existsSync(), isTrue);
      expect(File('$datasetDir/project.json').existsSync(), isTrue);
      expect(
        _rootEntityNames(datasetDir),
        containsAll(['data.yaml', 'project.json']),
      );
      for (final split in ['train', 'val', 'test']) {
        expect(Directory('$datasetDir/images/$split').existsSync(), isTrue);
        expect(Directory('$datasetDir/labels/$split').existsSync(), isTrue);
      }
      expect(
        await File('$datasetDir/data.yaml').readAsString(),
        contains('names: []'),
      );
    });

    test('可以从 data.yaml 读取类别', () async {
      final datasetDir = '${tempDir.path}/dataset';
      await Directory(datasetDir).create(recursive: true);
      await File('$datasetDir/data.yaml').writeAsString('''
path: .
train: images/train
val: images/val
test: images/test
names:
  0: 'enemy'
  1: teammate
''');

      final config = await service.readDatasetProject(datasetDir);

      expect(config.classes, ['enemy', 'teammate']);
    });

    test('非法 JSON 会抛出格式异常', () async {
      final file = File('${tempDir.path}/project.json');
      await file.writeAsString('[]');

      expect(() => service.readProject(file.path), throwsFormatException);
    });
  });
}

Set<String> _rootEntityNames(String datasetDir) {
  return Directory(
    datasetDir,
  ).listSync().map((entity) => p.basename(entity.path)).toSet();
}
