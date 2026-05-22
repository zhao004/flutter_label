import 'dart:async';
import 'dart:io';

import 'package:flutter_label/app/controllers/video_extract_controller.dart';
import 'package:flutter_label/app/models/video_extract_config.dart';
import 'package:flutter_label/app/services/video_extract_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('VideoExtractController', () {
    late Directory tempDir;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'video_extract_controller_test_',
      );
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('开始抽帧时直接使用用户输出目录并更新最新预览图', () async {
      final videoFile = File(p.join(tempDir.path, 'video1.mp4'));
      await videoFile.writeAsBytes(const [0]);
      final service = _SuccessVideoExtractService();
      final controller = VideoExtractController(videoExtractService: service)
        ..videoPath.value = videoFile.path
        ..outputDir.value = tempDir.path;

      await controller.startExtract();

      expect(service.lastConfig!.outputDir, tempDir.path);
      expect(
        service.lastConfig!.conflictStrategy,
        VideoExtractConflictStrategy.skipExisting,
      );
      expect(controller.generatedImages.length, 1);
      expect(
        controller.latestPreviewImage.value,
        p.join(tempDir.path, 'video1_0000000000ms.jpg'),
      );
      controller.onClose();
    });

    test('停止抽帧会请求 native 取消并进入停止状态', () async {
      final videoFile = File(p.join(tempDir.path, 'video2.mp4'));
      await videoFile.writeAsBytes(const [0]);
      final service = _CancelableVideoExtractService();
      final controller = VideoExtractController(videoExtractService: service)
        ..videoPath.value = videoFile.path
        ..outputDir.value = tempDir.path;

      final task = controller.startExtract();
      await Future<void>.delayed(Duration.zero);

      controller.stopExtract();
      service.completeCanceled();
      await task;

      expect(service.cancelCalled, isTrue);
      expect(controller.isRunning.value, isFalse);
      controller.onClose();
    });
  });
}

class _SuccessVideoExtractService extends VideoExtractService {
  VideoExtractConfig? lastConfig;

  @override
  Future<VideoExtractResult> extract(VideoExtractConfig config) async {
    lastConfig = config;
    final outputDir = Directory(config.outputDir);
    await outputDir.create(recursive: true);
    final imagePath = p.join(outputDir.path, 'video1_0000000000ms.jpg');
    await File(imagePath).writeAsBytes(const [1]);
    return VideoExtractResult(
      outputDir: outputDir.path,
      generatedImages: [imagePath],
      skippedImages: const [],
      usedNative: true,
      logs: const [],
    );
  }
}

class _CancelableVideoExtractService extends VideoExtractService {
  final Completer<void> _cancelCompleter = Completer<void>();
  bool cancelCalled = false;

  @override
  Future<VideoExtractResult> extract(VideoExtractConfig config) async {
    await _cancelCompleter.future;
    throw StateError('native_core 抽帧失败，错误码：-6（用户已停止抽帧）');
  }

  @override
  bool cancelRunningExtraction() {
    cancelCalled = true;
    return true;
  }

  void completeCanceled() {
    if (!_cancelCompleter.isCompleted) {
      _cancelCompleter.complete();
    }
  }
}
