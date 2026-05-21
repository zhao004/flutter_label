import 'dart:async';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../models/video_extract_config.dart';
import 'native_library_loader.dart';

typedef _ExtractFramesByFpsWithOptionsNative =
    Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32, Double);
typedef _ExtractFramesByFpsWithOptionsDart =
    int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int, double);

typedef _ExtractFramesByIntervalWithOptionsNative =
    Int32 Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, Int32, Int32);
typedef _ExtractFramesByIntervalWithOptionsDart =
    int Function(Pointer<Utf8>, Pointer<Utf8>, Pointer<Utf8>, int, int);
typedef _CancelVideoExtractNative = Void Function();
typedef _CancelVideoExtractDart = void Function();
typedef VideoExtractNativeRunner =
    FutureOr<int?> Function(VideoExtractConfig config, List<String> logs);

class VideoExtractResult {
  const VideoExtractResult({
    required this.outputDir,
    required this.generatedImages,
    required this.skippedImages,
    required this.usedNative,
    required this.logs,
  });

  final String outputDir;
  final List<String> generatedImages;
  final List<String> skippedImages;
  final bool usedNative;
  final List<String> logs;
}

class VideoExtractService {
  const VideoExtractService({VideoExtractNativeRunner? nativeRunner})
    : _nativeRunner = nativeRunner;

  final VideoExtractNativeRunner? _nativeRunner;

  static const supportedVideoExtensions = {
    '.mp4',
    '.avi',
    '.mov',
    '.mkv',
    '.flv',
    '.webm',
  };

  Future<VideoExtractResult> extract(VideoExtractConfig config) async {
    _validateConfig(config);
    if (_nativeRunner != null) {
      return _extractInWorker(config, nativeRunner: _nativeRunner);
    }
    return Isolate.run(() => _extractInWorker(config));
  }

  bool cancelRunningExtraction() {
    DynamicLibrary library;
    try {
      library = DynamicLibrary.open(_nativeLibraryPath());
    } catch (_) {
      return false;
    }
    final cancel = library
        .lookupFunction<_CancelVideoExtractNative, _CancelVideoExtractDart>(
          'cancel_video_extract',
        );
    cancel();
    return true;
  }

  static Future<VideoExtractResult> _extractInWorker(
    VideoExtractConfig config, {
    VideoExtractNativeRunner? nativeRunner,
  }) async {
    final logs = <String>[];
    final outputDirectory = Directory(config.outputDir);
    await outputDirectory.create(recursive: true);
    final outputPrefix = _videoOutputPrefix(config.videoPath);
    final skippedImages = await _prepareExistingOutputImages(
      outputDir: config.outputDir,
      outputPrefix: outputPrefix,
      strategy: config.conflictStrategy,
    );

    final nativeResult = await (nativeRunner == null
        ? _tryExtractWithNative(config, outputPrefix, logs)
        : nativeRunner(config, logs));
    if (nativeResult != 0) {
      throw StateError(_nativeFailureMessage(nativeResult, logs));
    }

    final generatedImages = await _scanGeneratedImages(
      config.outputDir,
      outputPrefix: outputPrefix,
    );
    if (generatedImages.isEmpty) {
      throw StateError('抽帧完成但未生成图片，请检查视频内容和 native_core/FFmpeg 输出。');
    }
    logs.add('图片整理完成：保留 ${generatedImages.length}，跳过 ${skippedImages.length}。');

    return VideoExtractResult(
      outputDir: config.outputDir,
      generatedImages: generatedImages,
      skippedImages: skippedImages,
      usedNative: true,
      logs: logs,
    );
  }

  static int? _tryExtractWithNative(
    VideoExtractConfig config,
    String outputPrefix,
    List<String> logs,
  ) {
    DynamicLibrary? library;
    try {
      library = DynamicLibrary.open(_nativeLibraryPath());
    } catch (error) {
      logs.add('加载 native_core 失败：$error');
      return null;
    }

    final videoPath = config.videoPath.toNativeUtf8();
    final outputDir = config.outputDir.toNativeUtf8();
    final outputPrefixPointer = outputPrefix.toNativeUtf8();
    final overwriteExisting =
        config.conflictStrategy ==
        VideoExtractConflictStrategy.overwriteExisting;
    try {
      final result = switch (config.mode) {
        VideoExtractMode.fps =>
          library
              .lookupFunction<
                _ExtractFramesByFpsWithOptionsNative,
                _ExtractFramesByFpsWithOptionsDart
              >('extract_frames_by_fps_with_options')
              .call(
                videoPath,
                outputDir,
                outputPrefixPointer,
                overwriteExisting ? 1 : 0,
                config.fps,
              ),
        VideoExtractMode.interval =>
          library
              .lookupFunction<
                _ExtractFramesByIntervalWithOptionsNative,
                _ExtractFramesByIntervalWithOptionsDart
              >('extract_frames_by_interval_with_options')
              .call(
                videoPath,
                outputDir,
                outputPrefixPointer,
                overwriteExisting ? 1 : 0,
                config.frameInterval,
              ),
      };
      logs.add(
        result == 0 ? 'native_core 抽帧成功。' : 'native_core 抽帧失败，错误码：$result',
      );
      return result;
    } finally {
      malloc.free(videoPath);
      malloc.free(outputDir);
      malloc.free(outputPrefixPointer);
    }
  }

  static String _nativeFailureMessage(int? nativeResult, List<String> logs) {
    final reason = nativeResult == null
        ? 'native_core 动态库不可用'
        : 'native_core 抽帧失败，错误码：$nativeResult（${_nativeErrorDescription(nativeResult)}）';
    final details = logs.isEmpty ? '' : '\n${logs.join('\n')}';
    return '$reason。视频抽帧必须通过 C++ DLL + FFmpeg 执行，请确认 native_core.dll 已安装到应用 lib 目录，'
        '并且 avcodec/avformat/avutil/swscale 等 FFmpeg DLL 与 native_core.dll 位于应用 lib 目录。$details';
  }

  static String _nativeErrorDescription(int nativeResult) {
    return switch (nativeResult) {
      -1 => '参数无效',
      -2 => '视频文件不存在',
      -3 => '输出目录创建失败',
      -4 => 'FFmpeg 解码或编码失败',
      -5 => 'native_core 未链接 FFmpeg 开发库',
      -6 => '用户已停止抽帧',
      _ => '未知错误',
    };
  }

  static Future<List<String>> _scanGeneratedImages(
    String outputDir, {
    String? outputPrefix,
  }) async {
    final directory = Directory(outputDir);
    if (!await directory.exists()) {
      return [];
    }

    final images = await directory
        .list(recursive: false, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where(
          (file) => _isGeneratedFrameFile(file, outputPrefix: outputPrefix),
        )
        .map((file) => p.normalize(file.path))
        .toList();
    images.sort();
    return images;
  }

  static bool _isGeneratedFrameFile(File file, {String? outputPrefix}) {
    final baseName = p.basename(file.path).toLowerCase();
    final extension = p.extension(file.path).toLowerCase();
    if (!{'.jpg', '.jpeg', '.png'}.contains(extension)) {
      return false;
    }
    final prefix = outputPrefix == null
        ? null
        : RegExp.escape(outputPrefix.toLowerCase());
    final pattern = prefix == null
        ? r'^.*_\d{10}ms(?:_\d{2,})?\.jpe?g$'
        : '^${prefix}_\\d{10}ms(?:_\\d{2,})?\\.jpe?g\$';
    return RegExp(pattern).hasMatch(baseName);
  }

  static Future<List<String>> _prepareExistingOutputImages({
    required String outputDir,
    required String outputPrefix,
    required VideoExtractConflictStrategy strategy,
  }) async {
    final existingImages = await _scanGeneratedImages(
      outputDir,
      outputPrefix: outputPrefix,
    );
    if (strategy == VideoExtractConflictStrategy.skipExisting) {
      return existingImages;
    }
    for (final image in existingImages) {
      await File(image).delete();
    }
    return [];
  }

  static String _videoOutputPrefix(String videoPath) {
    return _sanitizePathSegment(
      p.basenameWithoutExtension(videoPath).trim().isEmpty
          ? 'video'
          : p.basenameWithoutExtension(videoPath),
    );
  }

  static String _sanitizePathSegment(String value) {
    final sanitized = value
        .replaceAll(RegExp(r'[<>:"/\\|?*\x00-\x1F]'), '_')
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .replaceAll(RegExp(r'^_+|_+$'), '');
    return sanitized.isEmpty ? 'video' : sanitized;
  }

  static String _nativeLibraryPath() {
    return nativeCoreLibraryPath();
  }

  void _validateConfig(VideoExtractConfig config) {
    final videoFile = File(config.videoPath);
    if (config.videoPath.trim().isEmpty || !videoFile.existsSync()) {
      throw FileSystemException('视频文件不存在', config.videoPath);
    }
    final extension = p.extension(config.videoPath).toLowerCase();
    if (!supportedVideoExtensions.contains(extension)) {
      throw FormatException('不支持的视频格式：$extension');
    }
    if (config.outputDir.trim().isEmpty) {
      throw const FormatException('输出目录不能为空');
    }
    switch (config.mode) {
      case VideoExtractMode.fps:
        if (config.fps <= 0 || config.fps > 60) {
          throw const FormatException('fps 必须在 0 到 60 之间');
        }
      case VideoExtractMode.interval:
        if (config.frameInterval <= 0 || config.frameInterval > 100000) {
          throw const FormatException('帧间隔必须在 1 到 100000 之间');
        }
    }
  }
}
