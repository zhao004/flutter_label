import 'dart:io';

import 'package:flutter_label/app/models/video_extract_config.dart';
import 'package:flutter_label/app/services/video_extract_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

void main() {
  group('VideoExtractService', () {
    late Directory tempDir;
    late VideoExtractService service;

    setUp(() async {
      tempDir = await Directory.systemTemp.createTemp(
        'video_extract_service_test_',
      );
      service = const VideoExtractService();
    });

    tearDown(() async {
      if (await tempDir.exists()) {
        await tempDir.delete(recursive: true);
      }
    });

    test('不存在的视频文件会被拒绝', () async {
      expect(
        () => service.extract(
          VideoExtractConfig(
            videoPath: '${tempDir.path}/missing.mp4',
            outputDir: '${tempDir.path}/frames',
            mode: VideoExtractMode.fps,
            fps: 3,
            frameInterval: 30,
            conflictStrategy: VideoExtractConflictStrategy.skipExisting,
          ),
        ),
        throwsA(isA<FileSystemException>()),
      );
    });

    test('不支持的视频扩展名会被拒绝', () async {
      final file = File('${tempDir.path}/video.txt');
      await file.writeAsString('not video');

      expect(
        () => service.extract(
          VideoExtractConfig(
            videoPath: file.path,
            outputDir: '${tempDir.path}/frames',
            mode: VideoExtractMode.fps,
            fps: 3,
            frameInterval: 30,
            conflictStrategy: VideoExtractConflictStrategy.skipExisting,
          ),
        ),
        throwsFormatException,
      );
    });

    test('fps 和帧间隔必须在有效范围内', () async {
      final file = File('${tempDir.path}/video.mp4');
      await file.writeAsBytes(const []);

      expect(
        () => service.extract(
          VideoExtractConfig(
            videoPath: file.path,
            outputDir: '${tempDir.path}/frames',
            mode: VideoExtractMode.fps,
            fps: 0,
            frameInterval: 30,
            conflictStrategy: VideoExtractConflictStrategy.skipExisting,
          ),
        ),
        throwsFormatException,
      );

      expect(
        () => service.extract(
          VideoExtractConfig(
            videoPath: file.path,
            outputDir: '${tempDir.path}/frames',
            mode: VideoExtractMode.interval,
            fps: 3,
            frameInterval: 0,
            conflictStrategy: VideoExtractConflictStrategy.skipExisting,
          ),
        ),
        throwsFormatException,
      );
    });

    test('抽帧会直接输出到用户目录并按视频时间戳命名', () async {
      final videoFile = File('${tempDir.path}/boss fight:01.mp4');
      final outputDir = Directory('${tempDir.path}/frames');
      await videoFile.writeAsBytes(const [0]);
      await outputDir.create(recursive: true);
      final manualImage = File('${outputDir.path}/manual.jpg');
      await manualImage.writeAsBytes(const [8]);

      final service = VideoExtractService(
        nativeRunner: (config, logs) async {
          expect(config.outputDir, outputDir.path);
          final outputFile = File(
            p.join(config.outputDir, 'boss_fight_01_0000000333ms.jpg'),
          );
          await outputFile.parent.create(recursive: true);
          await outputFile.writeAsBytes(const [1]);
          logs.add('测试 native 抽帧成功。');
          return 0;
        },
      );

      final result = await service.extract(
        VideoExtractConfig(
          videoPath: videoFile.path,
          outputDir: outputDir.path,
          mode: VideoExtractMode.fps,
          fps: 1,
          frameInterval: 30,
          conflictStrategy: VideoExtractConflictStrategy.skipExisting,
        ),
      );

      expect(result.generatedImages, [
        p.normalize(p.join(outputDir.path, 'boss_fight_01_0000000333ms.jpg')),
      ]);
      expect(result.outputDir, outputDir.path);
      expect(result.skippedImages, isEmpty);
      expect(manualImage.existsSync(), isTrue);
      expect(
        Directory(p.join(outputDir.path, 'boss_fight_01')).existsSync(),
        isFalse,
      );
    });

    test('冲突策略为跳过时不会覆盖已有时间戳图片', () async {
      final videoFile = File('${tempDir.path}/video.mp4');
      final outputDir = Directory('${tempDir.path}/frames_skip');
      await videoFile.writeAsBytes(const [0]);
      await outputDir.create(recursive: true);
      final existing = File(p.join(outputDir.path, 'video_0000000000ms.jpg'));
      await existing.writeAsBytes(const [9]);

      final service = VideoExtractService(
        nativeRunner: (config, logs) async {
          final outputFile = File(
            p.join(config.outputDir, 'video_0000000333ms.jpg'),
          );
          await outputFile.parent.create(recursive: true);
          await outputFile.writeAsBytes(const [1]);
          return 0;
        },
      );

      final result = await service.extract(
        VideoExtractConfig(
          videoPath: videoFile.path,
          outputDir: outputDir.path,
          mode: VideoExtractMode.fps,
          fps: 1,
          frameInterval: 30,
          conflictStrategy: VideoExtractConflictStrategy.skipExisting,
        ),
      );

      expect(result.generatedImages, [
        p.normalize(existing.path),
        p.normalize(p.join(outputDir.path, 'video_0000000333ms.jpg')),
      ]);
      expect(result.skippedImages, [p.normalize(existing.path)]);
      expect(await existing.readAsBytes(), const [9]);
    });

    test('冲突策略为覆盖时会替换已有时间戳图片', () async {
      final videoFile = File('${tempDir.path}/video.mp4');
      final outputDir = Directory('${tempDir.path}/frames_overwrite');
      await videoFile.writeAsBytes(const [0]);
      await outputDir.create(recursive: true);
      final existing = File(p.join(outputDir.path, 'video_0000000000ms.jpg'));
      await existing.writeAsBytes(const [9]);

      final service = VideoExtractService(
        nativeRunner: (config, logs) async {
          final outputFile = File(
            p.join(config.outputDir, 'video_0000000000ms.jpg'),
          );
          await outputFile.parent.create(recursive: true);
          await outputFile.writeAsBytes(const [1]);
          return 0;
        },
      );

      final result = await service.extract(
        VideoExtractConfig(
          videoPath: videoFile.path,
          outputDir: outputDir.path,
          mode: VideoExtractMode.fps,
          fps: 1,
          frameInterval: 30,
          conflictStrategy: VideoExtractConflictStrategy.overwriteExisting,
        ),
      );

      expect(result.generatedImages, [p.normalize(existing.path)]);
      expect(result.skippedImages, isEmpty);
      expect(await existing.readAsBytes(), const [1]);
    });

    test('native 不可用时会提示必须通过 C++ DLL 和 FFmpeg 执行', () async {
      final videoFile = File('${tempDir.path}/video.mp4');
      final outputDir = Directory('${tempDir.path}/frames_native_missing');
      await videoFile.writeAsBytes(const [0]);

      final service = VideoExtractService(nativeRunner: (config, logs) => null);

      expect(
        () => service.extract(
          VideoExtractConfig(
            videoPath: videoFile.path,
            outputDir: outputDir.path,
            mode: VideoExtractMode.interval,
            fps: 1,
            frameInterval: 30,
            conflictStrategy: VideoExtractConflictStrategy.skipExisting,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              contains('C++ DLL + FFmpeg'),
              contains('FFmpeg DLL'),
              isNot(contains('ffmpeg.exe')),
            ),
          ),
        ),
      );
    });

    test('native 返回取消码时会提示用户已停止抽帧', () async {
      final videoFile = File('${tempDir.path}/video.mp4');
      final outputDir = Directory('${tempDir.path}/frames_canceled');
      await videoFile.writeAsBytes(const [0]);

      final service = VideoExtractService(nativeRunner: (config, logs) => -6);

      expect(
        () => service.extract(
          VideoExtractConfig(
            videoPath: videoFile.path,
            outputDir: outputDir.path,
            mode: VideoExtractMode.interval,
            fps: 1,
            frameInterval: 30,
            conflictStrategy: VideoExtractConflictStrategy.skipExisting,
          ),
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            contains('用户已停止抽帧'),
          ),
        ),
      );
    });
  });
}
