import 'dart:async';

import 'package:flutter_label/app/controllers/auto_label_controller.dart';
import 'package:flutter_label/app/models/auto_label_config.dart';
import 'package:flutter_label/app/models/detection_result.dart';
import 'package:flutter_label/app/models/image_item.dart';
import 'package:flutter_label/app/services/auto_label_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  test('自动预标注运行中可以停止并取消底层流', () async {
    final service = _NeverEndingAutoLabelService();
    final controller = AutoLabelController(autoLabelService: service);
    controller.modelPath.value = 'model.onnx';
    controller.imageDir.value = 'images';
    controller.labelDir.value = 'labels';
    controller.previewImages.assignAll(const [
      ImageItem(
        path: 'images/a.jpg',
        labelPath: 'labels/a.txt',
        fileName: 'a.jpg',
        relativePath: 'a.jpg',
        width: 100,
        height: 80,
      ),
    ]);

    final running = controller.startAutoLabel();
    await service.started.future;
    await controller.stopAutoLabel();
    await running;

    expect(service.cancelled, isTrue);
    expect(controller.isRunning.value, isFalse);
    expect(controller.isStopping.value, isFalse);
    expect(controller.wasStopped.value, isTrue);
    expect(controller.errorMessage.value, isNull);
    expect(controller.logs, contains('自动预标注已停止。'));
  });

  test('自动预标注预览快照保持图片和检测框同步', () async {
    final service = _SequenceAutoLabelService([
      AutoLabelProgressEvent.progress(
        processedCount: 1,
        totalCount: 2,
        writtenCount: 1,
        mergedCount: 0,
        skippedCount: 0,
        currentImagePath: 'images/a.jpg',
        currentDetections: const [
          DetectionResult(
            classId: 0,
            className: 'person',
            confidence: 0.91,
            left: 10,
            top: 12,
            width: 20,
            height: 24,
          ),
        ],
      ),
      AutoLabelProgressEvent.completed(
        const AutoLabelResult(
          writtenCount: 1,
          skippedCount: 0,
          mergedCount: 0,
          logs: [],
          usedNative: true,
          classCount: 1,
        ),
        processedCount: 1,
        totalCount: 2,
      ),
    ]);
    final controller = AutoLabelController(
      autoLabelService: service,
      previewFrameMinDuration: Duration.zero,
    );
    controller.modelPath.value = 'model.onnx';
    controller.imageDir.value = 'images';
    controller.labelDir.value = 'labels';
    controller.previewImages.assignAll(const [
      ImageItem(
        path: 'images/a.jpg',
        labelPath: 'labels/a.txt',
        fileName: 'a.jpg',
        relativePath: 'a.jpg',
        width: 100,
        height: 80,
      ),
    ]);

    await controller.startAutoLabel();

    expect(controller.activePreviewImagePath, 'images/a.jpg');
    expect(controller.activePreviewImage?.width, 100);
    expect(controller.activePreviewDetections, hasLength(1));
    expect(controller.activePreviewDetections.single.className, 'person');
    expect(
      controller.currentPreviewFrame.value?.imageItem?.relativePath,
      'a.jpg',
    );
  });

  test('自动预标注高速进度事件会保留当前预览帧直到最小展示时间', () async {
    final service = _SequenceAutoLabelService([
      AutoLabelProgressEvent.progress(
        processedCount: 1,
        totalCount: 2,
        writtenCount: 1,
        mergedCount: 0,
        skippedCount: 0,
        currentImagePath: 'images/a.jpg',
        currentDetections: const [
          DetectionResult(
            classId: 0,
            className: 'person',
            confidence: 0.91,
            left: 10,
            top: 12,
            width: 20,
            height: 24,
          ),
        ],
      ),
      AutoLabelProgressEvent.progress(
        processedCount: 2,
        totalCount: 2,
        writtenCount: 2,
        mergedCount: 0,
        skippedCount: 0,
        currentImagePath: 'images/b.jpg',
        currentDetections: const [
          DetectionResult(
            classId: 1,
            className: 'car',
            confidence: 0.88,
            left: 30,
            top: 32,
            width: 40,
            height: 44,
          ),
        ],
      ),
      AutoLabelProgressEvent.completed(
        const AutoLabelResult(
          writtenCount: 2,
          skippedCount: 0,
          mergedCount: 0,
          logs: [],
          usedNative: true,
          classCount: 2,
        ),
        processedCount: 2,
        totalCount: 2,
      ),
    ]);
    final controller = AutoLabelController(
      autoLabelService: service,
      previewFrameMinDuration: const Duration(milliseconds: 50),
    );
    controller.modelPath.value = 'model.onnx';
    controller.imageDir.value = 'images';
    controller.labelDir.value = 'labels';
    controller.previewImages.assignAll(const [
      ImageItem(
        path: 'images/a.jpg',
        labelPath: 'labels/a.txt',
        fileName: 'a.jpg',
        relativePath: 'a.jpg',
        width: 100,
        height: 80,
      ),
      ImageItem(
        path: 'images/b.jpg',
        labelPath: 'labels/b.txt',
        fileName: 'b.jpg',
        relativePath: 'b.jpg',
        width: 120,
        height: 90,
      ),
    ]);

    await controller.startAutoLabel();

    expect(controller.currentImagePath.value, 'images/b.jpg');
    expect(controller.activePreviewImagePath, 'images/a.jpg');
    expect(controller.activePreviewDetections.single.className, 'person');
    await Future<void>.delayed(const Duration(milliseconds: 70));
    expect(controller.activePreviewImagePath, 'images/b.jpg');
    expect(controller.activePreviewDetections.single.className, 'car');
  });
}

class _NeverEndingAutoLabelService extends AutoLabelService {
  final started = Completer<void>();
  bool cancelled = false;

  @override
  Stream<AutoLabelProgressEvent> autoLabelStream(AutoLabelConfig config) {
    late final StreamController<AutoLabelProgressEvent> controller;
    controller = StreamController<AutoLabelProgressEvent>(
      onListen: () {
        if (!started.isCompleted) {
          started.complete();
        }
        controller.add(AutoLabelProgressEvent.log('测试自动预标注已启动。'));
        controller.add(
          AutoLabelProgressEvent.progress(
            processedCount: 1,
            totalCount: 3,
            writtenCount: 1,
            mergedCount: 0,
            skippedCount: 0,
            currentImagePath: 'images/a.jpg',
          ),
        );
      },
      onCancel: () {
        cancelled = true;
      },
    );
    return controller.stream;
  }
}

class _SequenceAutoLabelService extends AutoLabelService {
  const _SequenceAutoLabelService(this.events);

  final List<AutoLabelProgressEvent> events;

  @override
  Stream<AutoLabelProgressEvent> autoLabelStream(
    AutoLabelConfig config,
  ) async* {
    for (final event in events) {
      yield event;
    }
  }
}
