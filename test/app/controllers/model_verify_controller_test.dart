import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_label/app/controllers/model_verify_controller.dart';
import 'package:flutter_label/app/models/detection_result.dart';
import 'package:flutter_label/app/models/model_verify_config.dart';
import 'package:flutter_label/app/services/model_verify_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  test('拖动选择窗口后会保存窗口信息', () async {
    final service = _WindowPickModelVerifyService();
    final controller = ModelVerifyController(modelVerifyService: service)
      ..setMode(ModelVerifyMode.window);

    await controller.selectWindowUnderCursor();

    expect(controller.selectedWindow.value?.handle, 42);
    expect(controller.selectedWindow.value?.title, '目标窗口');
    expect(controller.sourcePath.value, '目标窗口');
    expect(service.highlightedWindowHandle, 42);
  });

  test('窗口边框高亮失败不会影响窗口选择', () async {
    final service = _WindowPickModelVerifyService(flashResult: false);
    final controller = ModelVerifyController(modelVerifyService: service)
      ..setMode(ModelVerifyMode.window);

    await controller.selectWindowUnderCursor();

    expect(controller.selectedWindow.value?.handle, 42);
    expect(controller.sourcePath.value, '目标窗口');
    expect(service.highlightedWindowHandle, 42);
    expect(controller.logs, contains('窗口边框视觉反馈未触发，可能是系统或目标窗口不支持。'));
  });

  test('关闭模型验证控制器时会恢复已高亮窗口边框', () async {
    final service = _WindowPickModelVerifyService();
    final controller = ModelVerifyController(modelVerifyService: service)
      ..setMode(ModelVerifyMode.window);

    await controller.selectWindowUnderCursor();
    controller.onClose();
    await Future<void>.delayed(Duration.zero);

    expect(service.restoredWindowHandle, 42);
  });

  test('切换出窗口模式时会恢复已高亮窗口边框并清空窗口选择', () async {
    final service = _WindowPickModelVerifyService();
    final controller = ModelVerifyController(modelVerifyService: service)
      ..setMode(ModelVerifyMode.window);

    await controller.selectWindowUnderCursor();
    controller.setMode(ModelVerifyMode.image);
    await Future<void>.delayed(Duration.zero);

    expect(service.restoredWindowHandle, 42);
    expect(controller.selectedWindow.value, isNull);
    expect(controller.hoveredWindow.value, isNull);
  });

  test('窗口验证会更新实时画面和检测结果', () async {
    final service = _WindowProgressModelVerifyService();
    final controller = ModelVerifyController(modelVerifyService: service)
      ..setMode(ModelVerifyMode.window);
    controller.modelPath.value = 'model.onnx';
    controller.setClassCount('2');
    controller.selectedWindow.value = const WindowSelectionInfo(
      handle: 7,
      title: '窗口 A',
      left: 0,
      top: 0,
      width: 320,
      height: 240,
    );

    final running = controller.runVerify();
    await Future<void>.delayed(Duration.zero);
    await controller.stopVerify();
    await running;

    expect(service.capturedConfig?.windowHandle, 7);
    expect(service.capturedConfig?.classCount, 2);
    expect(controller.windowResult.value?.detections, hasLength(1));
    expect(controller.windowResult.value?.frameWidth, 1);
    expect(controller.verifyStage.value, '已停止验证');
  });

  test('图片验证停止后会忽略迟到结果并恢复运行状态', () async {
    final service = _ImageStopModelVerifyService();
    final controller = ModelVerifyController(modelVerifyService: service);
    controller.modelPath.value = 'model.onnx';
    controller.sourcePath.value = 'image.jpg';

    final running = controller.runVerify();
    await service.started.future;
    await controller.stopVerify();

    expect(controller.isStopping.value, isTrue);
    service.complete();
    await running;

    expect(controller.isRunning.value, isFalse);
    expect(controller.isStopping.value, isFalse);
    expect(controller.imageResult.value, isNull);
    expect(controller.errorMessage.value, isNull);
    expect(controller.verifyStage.value, '已停止验证');
    expect(controller.logs, contains('模型验证已停止。'));
  });
}

class _WindowPickModelVerifyService extends ModelVerifyService {
  _WindowPickModelVerifyService({this.flashResult = true});

  final bool flashResult;
  int? highlightedWindowHandle;
  int? restoredWindowHandle;

  @override
  Future<WindowSelectionInfo?> getWindowUnderCursor() async {
    return const WindowSelectionInfo(
      handle: 42,
      title: '目标窗口',
      left: 10,
      top: 20,
      width: 800,
      height: 600,
    );
  }

  @override
  Future<bool> flashSelectedWindowBorder(int windowHandle) async {
    highlightedWindowHandle = windowHandle;
    return flashResult;
  }

  @override
  Future<bool> restoreSelectedWindowBorder(int windowHandle) async {
    restoredWindowHandle = windowHandle;
    return true;
  }
}

class _WindowProgressModelVerifyService extends ModelVerifyService {
  ModelVerifyConfig? capturedConfig;

  @override
  Stream<RealtimeDetectionResult> verifyWindowStream(
    ModelVerifyConfig config, {
    ModelVerifyProgressCallback? onProgress,
  }) {
    capturedConfig = config;
    late final StreamController<RealtimeDetectionResult> controller;
    controller = StreamController<RealtimeDetectionResult>(
      onListen: () {
        onProgress?.call(
          const ModelVerifyProgressEvent(
            stage: ModelVerifyProgressStage.inferencing,
            message: '窗口验证运行中',
          ),
        );
        controller.add(
          RealtimeDetectionResult(
            fps: 5,
            inferMs: 2,
            captureMs: 1,
            detections: const [
              DetectionResult(
                classId: 0,
                className: 'target',
                confidence: 0.8,
                left: 0,
                top: 0,
                width: 1,
                height: 1,
              ),
            ],
            frameBytes: Uint8List.fromList([0, 0, 0, 255]),
            frameWidth: 1,
            frameHeight: 1,
            frameStride: 4,
            sourceTitle: config.windowTitle,
          ),
        );
      },
    );
    return controller.stream;
  }
}

class _ImageStopModelVerifyService extends ModelVerifyService {
  final started = Completer<void>();
  final _resultCompleter = Completer<ModelVerifyResult>();

  @override
  Future<ModelVerifyResult> verifyImage(ModelVerifyConfig config) async {
    if (!started.isCompleted) {
      started.complete();
    }
    return _resultCompleter.future;
  }

  void complete() {
    if (_resultCompleter.isCompleted) {
      return;
    }
    _resultCompleter.complete(
      const ModelVerifyResult(
        imagePath: 'image.jpg',
        detections: [
          DetectionResult(
            classId: 0,
            className: 'target',
            confidence: 0.9,
            left: 0,
            top: 0,
            width: 1,
            height: 1,
          ),
        ],
        inferMs: 1,
        captureMs: 0,
        fps: 0,
        usedNative: true,
        logs: ['图片验证完成'],
      ),
    );
  }
}
