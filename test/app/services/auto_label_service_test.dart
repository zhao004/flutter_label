import 'dart:io';

import 'package:flutter_label/app/models/auto_label_config.dart';
import 'package:flutter_label/app/models/dataset_split.dart';
import 'package:flutter_label/app/models/detection_result.dart';
import 'package:flutter_label/app/services/auto_label_service.dart';
import 'package:flutter_label/app/widgets/detection_overlay.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AutoLabelService', () {
    late Directory tempDir;
    late AutoLabelService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'auto_label_service_test_',
      );
      service = const AutoLabelService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('跳过已有标签时不会覆盖人工标签', () async {
      final predictionDir = Directory('${tempDir.path}/prediction');
      final targetDir = Directory('${tempDir.path}/target');
      await predictionDir.create(recursive: true);
      await targetDir.create(recursive: true);
      await File(
        '${predictionDir.path}/a.txt',
      ).writeAsString('1 0.5 0.5 0.2 0.2');
      await File('${targetDir.path}/a.txt').writeAsString('0 0.1 0.1 0.1 0.1');

      final result = await service.applyPredictedLabels(
        predictionLabelDir: predictionDir.path,
        targetLabelDir: targetDir.path,
        classCount: 2,
        strategy: AutoLabelOverwriteStrategy.skipExisting,
      );

      expect(result.skippedCount, 1);
      expect(
        await File('${targetDir.path}/a.txt').readAsString(),
        '0 0.1 0.1 0.1 0.1',
      );
    });

    test('覆盖策略会写入归一化后的预测标签', () async {
      final predictionDir = Directory('${tempDir.path}/prediction');
      final targetDir = Directory('${tempDir.path}/target');
      await predictionDir.create(recursive: true);
      await targetDir.create(recursive: true);
      await File('${predictionDir.path}/a.txt').writeAsString(
        ['1 0.5 0.5 0.2 0.2 0.91', '8 0.5 0.5 0.2 0.2', 'bad line'].join('\n'),
      );

      final result = await service.applyPredictedLabels(
        predictionLabelDir: predictionDir.path,
        targetLabelDir: targetDir.path,
        classCount: 2,
        strategy: AutoLabelOverwriteStrategy.overwriteExisting,
      );

      expect(result.writtenCount, 1);
      expect(
        await File('${targetDir.path}/a.txt').readAsString(),
        '1 0.500000 0.500000 0.200000 0.200000\n8 0.500000 0.500000 0.200000 0.200000',
      );
    });

    test('单类数据集会保留模型分类并补齐 data.yaml', () async {
      final predictionDir = Directory('${tempDir.path}/prediction');
      final targetDir = Directory('${tempDir.path}/dataset/labels');
      final dataYamlFile = File('${tempDir.path}/dataset/data.yaml');
      await predictionDir.create(recursive: true);
      await targetDir.create(recursive: true);
      await dataYamlFile.writeAsString('''
path: .
names:
  0: existing
''');
      await File(
        '${predictionDir.path}/a.txt',
      ).writeAsString('2 0.5 0.5 0.2 0.2');

      final result = await service.applyPredictedLabels(
        predictionLabelDir: predictionDir.path,
        targetLabelDir: targetDir.path,
        classCount: 1,
        strategy: AutoLabelOverwriteStrategy.overwriteExisting,
        dataYamlPath: dataYamlFile.path,
      );

      expect(result.writtenCount, 1);
      expect(result.classCount, 3);
      expect(
        await File('${targetDir.path}/a.txt').readAsString(),
        '2 0.500000 0.500000 0.200000 0.200000',
      );
      final dataYaml = await dataYamlFile.readAsString();
      expect(dataYaml, contains("0: 'existing'"));
      expect(dataYaml, contains("1: 'class_1'"));
      expect(dataYaml, contains("2: 'class_2'"));
    });

    test('未知类别数量时会根据预测标签动态补齐 data.yaml', () async {
      final predictionDir = Directory('${tempDir.path}/prediction');
      final targetDir = Directory('${tempDir.path}/dataset/labels');
      final dataYamlFile = File('${tempDir.path}/dataset/data.yaml');
      await predictionDir.create(recursive: true);
      await targetDir.create(recursive: true);
      await File(
        '${predictionDir.path}/a.txt',
      ).writeAsString('2 0.5 0.5 0.2 0.2');

      final result = await service.applyPredictedLabels(
        predictionLabelDir: predictionDir.path,
        targetLabelDir: targetDir.path,
        classCount: 0,
        strategy: AutoLabelOverwriteStrategy.overwriteExisting,
        dataYamlPath: dataYamlFile.path,
      );

      expect(result.writtenCount, 1);
      expect(result.classCount, 3);
      expect(
        await File('${targetDir.path}/a.txt').readAsString(),
        '2 0.500000 0.500000 0.200000 0.200000',
      );
      final dataYaml = await dataYamlFile.readAsString();
      expect(dataYaml, contains("0: 'class_0'"));
      expect(dataYaml, contains("1: 'class_1'"));
      expect(dataYaml, contains("2: 'class_2'"));
    });

    test('应用预测标签后会同步模型类别到 data.yaml', () async {
      final predictionDir = Directory('${tempDir.path}/prediction');
      final targetDir = Directory('${tempDir.path}/dataset/labels');
      final dataYamlFile = File('${tempDir.path}/dataset/data.yaml');
      await predictionDir.create(recursive: true);
      await targetDir.create(recursive: true);
      await File(
        '${predictionDir.path}/a.txt',
      ).writeAsString('1 0.5 0.5 0.2 0.2');

      final result = await service.applyPredictedLabels(
        predictionLabelDir: predictionDir.path,
        targetLabelDir: targetDir.path,
        classCount: 0,
        strategy: AutoLabelOverwriteStrategy.overwriteExisting,
        dataYamlPath: dataYamlFile.path,
        detectedClassNames: const {0: 'buffalo', 1: 'elephant'},
      );

      expect(result.classCount, 2);
      expect(await dataYamlFile.readAsString(), '''
path: .
train: images/train
val: images/val
test: images/test

names:
  0: 'buffalo'
  1: 'elephant'
''');
    });

    test('模型实际类别名会覆盖旧类别并在 data.yaml 中正确转义', () async {
      final predictionDir = Directory('${tempDir.path}/prediction');
      final targetDir = Directory('${tempDir.path}/dataset/labels');
      final dataYamlFile = File('${tempDir.path}/dataset/data.yaml');
      await predictionDir.create(recursive: true);
      await targetDir.create(recursive: true);
      await dataYamlFile.writeAsString('''
path: .
names:
  0: class_0
  1: old_elephant
''');
      await File(
        '${predictionDir.path}/a.txt',
      ).writeAsString('1 0.5 0.5 0.2 0.2');

      final result = await service.applyPredictedLabels(
        predictionLabelDir: predictionDir.path,
        targetLabelDir: targetDir.path,
        classCount: 2,
        strategy: AutoLabelOverwriteStrategy.overwriteExisting,
        dataYamlPath: dataYamlFile.path,
        detectedClassNames: const {0: 'buffalo', 1: "keeper's elephant"},
      );

      expect(result.classCount, 2);
      final dataYaml = await dataYamlFile.readAsString();
      expect(dataYaml, contains("0: 'buffalo'"));
      expect(dataYaml, contains("1: 'keeper''s elephant'"));
    });

    test('合并策略会去重保留已有标签', () async {
      final predictionDir = Directory('${tempDir.path}/prediction');
      final targetDir = Directory('${tempDir.path}/target');
      await predictionDir.create(recursive: true);
      await targetDir.create(recursive: true);
      await File(
        '${predictionDir.path}/a.txt',
      ).writeAsString('1 0.5 0.5 0.2 0.2');
      await File(
        '${targetDir.path}/a.txt',
      ).writeAsString('0 0.1 0.1 0.1 0.1\n1 0.5 0.5 0.2 0.2');

      final result = await service.applyPredictedLabels(
        predictionLabelDir: predictionDir.path,
        targetLabelDir: targetDir.path,
        classCount: 2,
        strategy: AutoLabelOverwriteStrategy.mergeExisting,
      );

      expect(result.mergedCount, 1);
      expect(
        await File('${targetDir.path}/a.txt').readAsString(),
        '0 0.100000 0.100000 0.100000 0.100000\n1 0.500000 0.500000 0.200000 0.200000',
      );
    });

    test('应用预测标签时会按文件夹筛选', () async {
      final predictionDir = Directory('${tempDir.path}/prediction');
      final targetDir = Directory('${tempDir.path}/target');
      await predictionDir.create(recursive: true);
      await targetDir.create(recursive: true);
      await Directory('${predictionDir.path}/train').create(recursive: true);
      await Directory('${predictionDir.path}/val').create(recursive: true);
      await File(
        '${predictionDir.path}/train/a.txt',
      ).writeAsString('0 0.5 0.5 0.2 0.2');
      await File(
        '${predictionDir.path}/val/b.txt',
      ).writeAsString('0 0.5 0.5 0.2 0.2');

      final result = await service.applyPredictedLabels(
        predictionLabelDir: predictionDir.path,
        targetLabelDir: targetDir.path,
        classCount: 1,
        strategy: AutoLabelOverwriteStrategy.overwriteExisting,
        folderFilter: DatasetFolderFilter.val,
      );

      expect(result.writtenCount, 1);
      expect(File('${targetDir.path}/train/a.txt').existsSync(), isFalse);
      expect(File('${targetDir.path}/val/b.txt').existsSync(), isTrue);
    });

    test('模型不存在时会在执行前拒绝', () async {
      final imageDir = Directory('${tempDir.path}/images');
      await imageDir.create();

      expect(
        () => service.autoLabel(
          AutoLabelConfig(
            modelPath: '${tempDir.path}/missing.onnx',
            imageDir: imageDir.path,
            labelDir: '${tempDir.path}/labels',
            imgsz: 640,
            conf: 0.35,
            iou: 0.45,
            classCount: 2,
            strategy: AutoLabelOverwriteStrategy.skipExisting,
          ),
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('native 预标注成功时会应用预测标签', () async {
      final modelFile = File('${tempDir.path}/model.onnx');
      final imageDir = Directory('${tempDir.path}/images');
      final labelDir = Directory('${tempDir.path}/labels');
      final dataYamlFile = File('${tempDir.path}/data.yaml');
      await modelFile.writeAsBytes(const [1]);
      await imageDir.create();
      await dataYamlFile.writeAsString('''
path: .
names:
  0: existing
''');
      await File('${imageDir.path}/a.jpg').writeAsBytes(const [1]);
      final service = AutoLabelService(
        nativeRunner: (config, predictionLabelDir, logs) async {
          final predictionDir = Directory(predictionLabelDir);
          await predictionDir.create(recursive: true);
          await File(
            '${predictionDir.path}/a.txt',
          ).writeAsString('2 0.5 0.5 0.2 0.2');
          logs.add('native_core 测试预标注成功。');
          return 0;
        },
      );

      final result = await service.autoLabel(
        AutoLabelConfig(
          modelPath: modelFile.path,
          imageDir: imageDir.path,
          labelDir: labelDir.path,
          imgsz: 640,
          conf: 0.35,
          iou: 0.45,
          classCount: 1,
          strategy: AutoLabelOverwriteStrategy.overwriteExisting,
          dataYamlPath: dataYamlFile.path,
        ),
      );

      expect(result.usedNative, isTrue);
      expect(result.writtenCount, 1);
      expect(result.classCount, 3);
      expect(
        await File('${labelDir.path}/a.txt').readAsString(),
        '2 0.500000 0.500000 0.200000 0.200000',
      );
      final dataYaml = await dataYamlFile.readAsString();
      expect(dataYaml, contains("0: 'existing'"));
      expect(dataYaml, contains("1: 'class_1'"));
      expect(dataYaml, contains("2: 'class_2'"));
    });

    test('native 预标注允许类别数量未知并动态扩展', () async {
      final modelFile = File('${tempDir.path}/model.onnx');
      final imageDir = Directory('${tempDir.path}/images');
      final labelDir = Directory('${tempDir.path}/labels');
      final dataYamlFile = File('${tempDir.path}/data.yaml');
      await modelFile.writeAsBytes(const [1]);
      await imageDir.create();
      await File('${imageDir.path}/a.jpg').writeAsBytes(const [1]);
      final service = AutoLabelService(
        nativeRunner: (config, predictionLabelDir, logs) async {
          final predictionDir = Directory(predictionLabelDir);
          await predictionDir.create(recursive: true);
          await File(
            '${predictionDir.path}/a.txt',
          ).writeAsString('3 0.5 0.5 0.2 0.2');
          logs.add('native_core 测试未知类别数预标注成功。');
          return 0;
        },
      );

      final result = await service.autoLabel(
        AutoLabelConfig(
          modelPath: modelFile.path,
          imageDir: imageDir.path,
          labelDir: labelDir.path,
          imgsz: 640,
          conf: 0.35,
          iou: 0.45,
          classCount: 0,
          strategy: AutoLabelOverwriteStrategy.overwriteExisting,
          dataYamlPath: dataYamlFile.path,
        ),
      );

      expect(result.usedNative, isTrue);
      expect(result.writtenCount, 1);
      expect(result.classCount, 4);
      expect(
        await File('${labelDir.path}/a.txt').readAsString(),
        '3 0.500000 0.500000 0.200000 0.200000',
      );
      final dataYaml = await dataYamlFile.readAsString();
      expect(dataYaml, contains("0: 'class_0'"));
      expect(dataYaml, contains("1: 'class_1'"));
      expect(dataYaml, contains("2: 'class_2'"));
      expect(dataYaml, contains("3: 'class_3'"));
    });

    test('native 预标注成功时会流式返回进度和结果', () async {
      final modelFile = File('${tempDir.path}/model.onnx');
      final imageDir = Directory('${tempDir.path}/images');
      final labelDir = Directory('${tempDir.path}/labels');
      await modelFile.writeAsBytes(const [1]);
      await imageDir.create();
      await File('${imageDir.path}/a.jpg').writeAsBytes(const [1]);
      final service = AutoLabelService(
        nativeRunner: (config, predictionLabelDir, logs) async {
          final predictionDir = Directory(predictionLabelDir);
          await predictionDir.create(recursive: true);
          await File(
            '${predictionDir.path}/a.txt',
          ).writeAsString('0 0.5 0.5 0.2 0.2');
          logs.add('native_core 测试流式预标注成功。');
          return 0;
        },
      );

      final events = await service
          .autoLabelStream(
            AutoLabelConfig(
              modelPath: modelFile.path,
              imageDir: imageDir.path,
              labelDir: labelDir.path,
              imgsz: 640,
              conf: 0.35,
              iou: 0.45,
              classCount: 1,
              strategy: AutoLabelOverwriteStrategy.overwriteExisting,
            ),
          )
          .toList();

      expect(
        events.map((event) => event.type),
        containsAll([
          AutoLabelProgressEventType.log,
          AutoLabelProgressEventType.progress,
          AutoLabelProgressEventType.completed,
        ]),
      );
      final progress = events.firstWhere(
        (event) => event.type == AutoLabelProgressEventType.progress,
      );
      expect(progress.processedCount, 1);
      expect(progress.totalCount, 1);
      final completed = events.last;
      expect(completed.processedCount, 1);
      expect(completed.totalCount, 1);
      expect(completed.result?.writtenCount, 1);
      expect(
        await File('${labelDir.path}/a.txt').readAsString(),
        '0 0.500000 0.500000 0.200000 0.200000',
      );
    });

    test('进度事件会携带当前图片检测框', () {
      final detection = DetectionResult(
        classId: 0,
        className: 'person',
        confidence: 0.91,
        left: 10,
        top: 12,
        width: 40,
        height: 50,
      );

      final event = AutoLabelProgressEvent.progress(
        processedCount: 1,
        totalCount: 2,
        writtenCount: 1,
        mergedCount: 0,
        skippedCount: 0,
        currentImagePath: '${tempDir.path}/images/a.jpg',
        currentDetections: [detection],
      );

      expect(event.currentImagePath, endsWith('images/a.jpg'));
      expect(event.currentDetections, hasLength(1));
      expect(event.currentDetections.single.className, 'person');
      expect(event.currentDetections.single.confidence, 0.91);
    });

    test('检测标签会同时包含类别名称和类别 ID', () {
      const detection = DetectionResult(
        classId: 7,
        className: 'warning light',
        confidence: 0.876,
        left: 10,
        top: 12,
        width: 40,
        height: 50,
      );

      expect(detectionLabelText(detection), 'warning light (#7) 87.6%');
    });

    test('native 预标注失败时不再回退外部命令', () async {
      final modelFile = File('${tempDir.path}/model.onnx');
      final imageDir = Directory('${tempDir.path}/images');
      final labelDir = Directory('${tempDir.path}/labels');
      await modelFile.writeAsBytes(const [1]);
      await imageDir.create();
      await File('${imageDir.path}/a.jpg').writeAsBytes(const [1]);
      final service = AutoLabelService(
        nativeRunner: (config, predictionLabelDir, logs) async {
          logs.add('native_core 测试推理失败。');
          return -13;
        },
      );

      await expectLater(
        service.autoLabel(
          AutoLabelConfig(
            modelPath: modelFile.path,
            imageDir: imageDir.path,
            labelDir: labelDir.path,
            imgsz: 640,
            conf: 0.35,
            iou: 0.45,
            classCount: 1,
            strategy: AutoLabelOverwriteStrategy.overwriteExisting,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('native_core 批量预标注失败'),
          ),
        ),
      );
      expect(File('${labelDir.path}/a.txt').existsSync(), isFalse);
    });
  });
}
