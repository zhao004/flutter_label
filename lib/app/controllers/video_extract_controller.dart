import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../models/project_config.dart';
import '../models/video_extract_config.dart';
import '../routes/app_pages.dart';
import '../services/app_toast_service.dart';
import '../services/video_extract_service.dart';

class VideoExtractController extends GetxController {
  VideoExtractController({
    VideoExtractService videoExtractService = const VideoExtractService(),
  }) : _videoExtractService = videoExtractService;

  final VideoExtractService _videoExtractService;
  Timer? _previewTimer;

  final videoPath = ''.obs;
  final outputDir = ''.obs;
  final activeOutputDir = ''.obs;
  final mode = VideoExtractMode.fps.obs;
  final conflictStrategy = VideoExtractConflictStrategy.skipExisting.obs;
  final fps = 3.0.obs;
  final frameInterval = 30.obs;
  final isRunning = false.obs;
  final isCancelRequested = false.obs;
  final generatedImages = <String>[].obs;
  final logs = <String>[].obs;
  final latestPreviewImage = RxnString();
  final errorMessage = RxnString();
  final usedNative = false.obs;

  Future<void> pickVideo() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '请选择视频文件',
      type: FileType.custom,
      allowedExtensions: ['mp4', 'avi', 'mov', 'mkv', 'flv', 'webm'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.trim().isEmpty) {
      return;
    }
    videoPath.value = path;
    if (outputDir.value.isEmpty) {
      outputDir.value = p.dirname(path);
    }
  }

  Future<void> pickOutputDir() async {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '请选择抽帧输出目录',
    );
    if (directory == null || directory.trim().isEmpty) {
      return;
    }
    outputDir.value = directory;
  }

  void setMode(VideoExtractMode nextMode) {
    mode.value = nextMode;
  }

  void setConflictStrategy(VideoExtractConflictStrategy nextStrategy) {
    conflictStrategy.value = nextStrategy;
  }

  void setFps(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null) {
      fps.value = parsed;
    }
  }

  void setFrameInterval(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      frameInterval.value = parsed;
    }
  }

  Future<void> startExtract() async {
    if (isRunning.value) {
      return;
    }
    if (videoPath.value.trim().isEmpty) {
      errorMessage.value = '请选择视频文件';
      AppToast.error(errorMessage.value, source: '视频抽帧');
      return;
    }
    if (outputDir.value.trim().isEmpty) {
      errorMessage.value = '请选择输出目录';
      AppToast.error(errorMessage.value, source: '视频抽帧');
      return;
    }

    final targetOutputDir = outputDir.value;

    isRunning.value = true;
    isCancelRequested.value = false;
    errorMessage.value = null;
    activeOutputDir.value = targetOutputDir;
    latestPreviewImage.value = null;
    generatedImages.clear();
    logs
      ..clear()
      ..add('开始抽帧...');
    _startPreviewPolling(targetOutputDir);

    try {
      final result = await _videoExtractService.extract(
        VideoExtractConfig(
          videoPath: videoPath.value,
          outputDir: targetOutputDir,
          mode: mode.value,
          fps: fps.value,
          frameInterval: frameInterval.value,
          conflictStrategy: conflictStrategy.value,
        ),
      );
      usedNative.value = result.usedNative;
      generatedImages.assignAll(result.generatedImages);
      activeOutputDir.value = result.outputDir;
      _updateLatestPreview(result.generatedImages);
      logs.addAll(result.logs);
      final skippedText = result.skippedImages.isEmpty
          ? ''
          : '，跳过 ${result.skippedImages.length} 张';
      logs.add('抽帧完成，共保留 ${result.generatedImages.length} 张图片$skippedText。');
      AppToast.success('抽帧完成，共保留 ${result.generatedImages.length} 张图片');
    } catch (error) {
      if (isCancelRequested.value || error.toString().contains('-6')) {
        await _refreshPreview(targetOutputDir);
      } else {
        errorMessage.value = error.toString();
        logs.add('抽帧失败：$error');
        AppToast.error(error, source: '视频抽帧');
      }
    } finally {
      _stopPreviewPolling();
      await _refreshPreview(targetOutputDir);
      isRunning.value = false;
    }
  }

  void stopExtract() {
    if (!isRunning.value || isCancelRequested.value) {
      return;
    }
    isCancelRequested.value = true;
    final requested = _videoExtractService.cancelRunningExtraction();
    if (!requested) {
      logs.add('停止请求发送失败：native_core 尚未加载或不可用。');
    }
  }

  Future<void> openOutputInAnnotation() async {
    if (generatedImages.isEmpty || activeOutputDir.value.isEmpty) {
      errorMessage.value = '请先完成抽帧';
      AppToast.error(errorMessage.value, source: '视频抽帧');
      return;
    }
    await Get.toNamed(
      Routes.annotation,
      arguments: AnnotationOpenRequest(imageDir: activeOutputDir.value),
    );
  }

  void _startPreviewPolling(String directory) {
    _stopPreviewPolling();
    _previewTimer = Timer.periodic(
      const Duration(milliseconds: 500),
      (_) => unawaited(_refreshPreview(directory)),
    );
    unawaited(_refreshPreview(directory));
  }

  void _stopPreviewPolling() {
    _previewTimer?.cancel();
    _previewTimer = null;
  }

  Future<void> _refreshPreview(String directory) async {
    final outputDirectory = Directory(directory);
    if (!await outputDirectory.exists()) {
      return;
    }
    final images = await outputDirectory
        .list(recursive: false, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where(_isGeneratedFrameFile)
        .map((file) => file.path)
        .toList();
    images.sort();
    generatedImages.assignAll(images);
    _updateLatestPreview(images);
  }

  void _updateLatestPreview(List<String> images) {
    latestPreviewImage.value = images.isEmpty ? null : images.last;
  }

  static bool _isGeneratedFrameFile(File file) {
    final baseName = p.basename(file.path).toLowerCase();
    final extension = p.extension(file.path).toLowerCase();
    return RegExp(r'.*_\d{10}ms(?:_\d{2,})?\.jpe?g$').hasMatch(baseName) &&
        {'.jpg', '.jpeg', '.png'}.contains(extension);
  }

  @override
  void onClose() {
    _stopPreviewPolling();
    super.onClose();
  }
}
