import 'dart:io';

import 'package:flutter_label/app/models/model_verify_config.dart';
import 'package:flutter_label/app/services/model_verify_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ModelVerifyService', () {
    late Directory tempDir;
    late ModelVerifyService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'model_verify_service_test_',
      );
      service = const ModelVerifyService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('模型不存在时会在执行前拒绝', () async {
      final image = File('${tempDir.path}/image.jpg');
      await image.writeAsBytes(const [1, 2, 3]);

      expect(
        () => service.verifyImage(
          ModelVerifyConfig(
            modelPath: '${tempDir.path}/missing.onnx',
            sourcePath: image.path,
            mode: ModelVerifyMode.image,
            imgsz: 640,
            conf: 0.35,
            iou: 0.45,
          ),
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('参数越界时会抛出格式异常', () async {
      final model = File('${tempDir.path}/model.onnx');
      final image = File('${tempDir.path}/image.jpg');
      await model.writeAsBytes(const [1, 2, 3]);
      await image.writeAsBytes(const [1, 2, 3]);

      expect(
        () => service.verifyImage(
          ModelVerifyConfig(
            modelPath: model.path,
            sourcePath: image.path,
            mode: ModelVerifyMode.image,
            imgsz: 8,
            conf: 0.35,
            iou: 0.45,
          ),
        ),
        throwsFormatException,
      );

      expect(
        () => service.verifyImage(
          ModelVerifyConfig(
            modelPath: model.path,
            sourcePath: image.path,
            mode: ModelVerifyMode.image,
            imgsz: 640,
            conf: 1.2,
            iou: 0.45,
          ),
        ),
        throwsFormatException,
      );
    });

    test('native 单图验证成功时解析检测 JSON', () async {
      final model = File('${tempDir.path}/model.onnx');
      final image = File('${tempDir.path}/image.png');
      await model.writeAsBytes(const [1, 2, 3]);
      await image.writeAsBytes(const [1, 2, 3]);
      final service = ModelVerifyService(
        imageNativeRunner: (config, logs) {
          expect(config.classCount, 2);
          logs.add('native_core 测试单图检测成功。');
          return '[{"class_id":0,"class_name":"0","confidence":0.9,"x":4,"y":3,"w":2,"h":4}]';
        },
      );

      final result = await service.verifyImage(
        ModelVerifyConfig(
          modelPath: model.path,
          sourcePath: image.path,
          mode: ModelVerifyMode.image,
          imgsz: 640,
          conf: 0.35,
          iou: 0.45,
          classCount: 2,
        ),
      );

      expect(result.usedNative, isTrue);
      expect(result.detections, hasLength(1));
      expect(result.detections.single.left, 4);
      expect(result.detections.single.top, 3);
      expect(result.detections.single.width, 2);
      expect(result.detections.single.height, 4);
    });

    test('native 单图验证失败时直接抛出错误', () async {
      final model = File('${tempDir.path}/model.onnx');
      final image = File('${tempDir.path}/image.png');
      await model.writeAsBytes(const [1, 2, 3]);
      await image.writeAsBytes(const [1, 2, 3]);
      final service = ModelVerifyService(
        imageNativeRunner: (config, logs) {
          logs.add('native_core 测试单图检测失败。');
          return null;
        },
      );

      await expectLater(
        service.verifyImage(
          ModelVerifyConfig(
            modelPath: model.path,
            sourcePath: image.path,
            mode: ModelVerifyMode.image,
            imgsz: 640,
            conf: 0.35,
            iou: 0.45,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('native_core 动态库不可用或检测未返回结果'),
          ),
        ),
      );
    });
  });
}
