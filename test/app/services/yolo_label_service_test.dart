import 'dart:io';
import 'dart:ui';

import 'package:flutter_label/app/models/annotation_box.dart';
import 'package:flutter_label/app/models/image_annotation_status.dart';
import 'package:flutter_label/app/services/yolo_label_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('YoloLabelService', () {
    late Directory tempDir;
    late YoloLabelService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'yolo_label_service_test_',
      );
      service = const YoloLabelService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('保存标签会创建目录并写入 6 位小数', () async {
      final labelPath = '${tempDir.path}/labels/a.txt';

      await service.saveLabels(
        labelPath: labelPath,
        boxes: [
          const AnnotationBox(
            id: 'box-1',
            classId: 0,
            rect: Rect.fromLTWH(10, 20, 30, 40),
          ),
        ],
        imageWidth: 100,
        imageHeight: 200,
        classCount: 2,
      );

      final content = await File(labelPath).readAsString();
      expect(content, '0 0.250000 0.200000 0.300000 0.200000');
    });

    test('读取标签会跳过异常行并保留警告', () async {
      final labelFile = File('${tempDir.path}/labels/a.txt');
      await labelFile.parent.create(recursive: true);
      await labelFile.writeAsString(
        [
          '0 0.5 0.5 0.2 0.4',
          '9 0.5 0.5 0.2 0.4',
          'bad line',
          '1 0.5 0.5 0.001 0.001',
        ].join('\n'),
      );

      final result = await service.loadLabels(
        labelPath: labelFile.path,
        imageWidth: 100,
        imageHeight: 100,
        classCount: 2,
      );

      expect(result.boxes, hasLength(1));
      expect(result.boxes.first.classId, 0);
      expect(result.warnings, hasLength(3));
    });

    test('空标注会保存为空文件', () async {
      final labelPath = '${tempDir.path}/labels/empty.txt';

      await service.saveLabels(
        labelPath: labelPath,
        boxes: const [],
        imageWidth: 100,
        imageHeight: 100,
        classCount: 1,
      );

      expect(await File(labelPath).readAsString(), isEmpty);
    });

    test('可以识别标签状态', () async {
      final labelFile = File('${tempDir.path}/labels/status.txt');
      await labelFile.parent.create(recursive: true);

      expect(
        await service.inspectLabelStatus(
          labelPath: labelFile.path,
          classCount: 2,
          isCompleted: false,
        ),
        ImageAnnotationStatus.unlabeled,
      );

      await labelFile.writeAsString('');
      expect(
        await service.inspectLabelStatus(
          labelPath: labelFile.path,
          classCount: 2,
          isCompleted: false,
        ),
        ImageAnnotationStatus.emptyLabel,
      );

      await labelFile.writeAsString('9 0.5 0.5 0.2 0.2');
      expect(
        await service.inspectLabelStatus(
          labelPath: labelFile.path,
          classCount: 2,
          isCompleted: false,
        ),
        ImageAnnotationStatus.labelError,
      );

      await labelFile.writeAsString('1 0.5 0.5 0.2 0.2');
      expect(
        await service.inspectLabelStatus(
          labelPath: labelFile.path,
          classCount: 2,
          isCompleted: false,
        ),
        ImageAnnotationStatus.labeled,
      );
    });
  });
}
