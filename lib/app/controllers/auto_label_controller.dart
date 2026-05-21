import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../models/auto_label_config.dart';
import '../models/dataset_split.dart';
import '../models/detection_result.dart';
import '../models/image_item.dart';
import '../models/project_config.dart';
import '../routes/app_pages.dart';
import '../services/app_toast_service.dart';
import '../services/auto_label_service.dart';
import '../services/data_yaml_service.dart';
import '../services/image_scan_service.dart';

const Duration _defaultPreviewFrameMinDuration = Duration(milliseconds: 800);

/// 自动预标注右侧预览正在展示的一帧。
///
/// 将图片路径、图片尺寸来源和检测框绑定到同一个快照中，避免多次 Rx 更新之间
/// 出现“新图片 + 旧尺寸/旧检测框”的瞬时组合。
class AutoLabelPreviewFrame {
  AutoLabelPreviewFrame({
    required this.imagePath,
    required List<DetectionResult> detections,
    this.imageItem,
  }) : detections = List.unmodifiable(detections);

  final String imagePath;
  final ImageItem? imageItem;
  final List<DetectionResult> detections;

  String get label => imageItem?.relativePath ?? imagePath;
}

class AutoLabelController extends GetxController {
  AutoLabelController({
    AutoLabelService autoLabelService = const AutoLabelService(),
    ImageScanService imageScanService = const ImageScanService(),
    DataYamlService dataYamlService = const DataYamlService(),
    Duration previewFrameMinDuration = _defaultPreviewFrameMinDuration,
  }) : _autoLabelService = autoLabelService,
       _imageScanService = imageScanService,
       _dataYamlService = dataYamlService,
       _previewFrameMinDuration = previewFrameMinDuration.isNegative
           ? Duration.zero
           : previewFrameMinDuration;

  final AutoLabelService _autoLabelService;
  final ImageScanService _imageScanService;
  final DataYamlService _dataYamlService;
  final Duration _previewFrameMinDuration;

  final modelPath = ''.obs;
  final imageDir = ''.obs;
  final labelDir = ''.obs;
  final imgsz = 640.obs;
  final conf = 0.35.obs;
  final iou = 0.45.obs;
  final classCount = 0.obs;
  final strategy = AutoLabelOverwriteStrategy.skipExisting.obs;
  final isRunning = false.obs;
  final isStopping = false.obs;
  final wasStopped = false.obs;
  final logs = <String>[].obs;
  final errorMessage = RxnString();
  final result = Rxn<AutoLabelResult>();
  final processedCount = 0.obs;
  final totalCount = 0.obs;
  final currentImagePath = ''.obs;
  final currentPreviewDetections = <DetectionResult>[].obs;
  final currentPreviewFrame = Rxn<AutoLabelPreviewFrame>();
  final previewImages = <ImageItem>[].obs;
  final selectedPreviewIndex = 0.obs;
  final folderFilter = DatasetFolderFilter.all.obs;
  StreamSubscription<AutoLabelProgressEvent>? _autoLabelSubscription;
  Completer<void>? _autoLabelCompletion;
  Timer? _previewFrameTimer;
  AutoLabelProgressEvent? _pendingPreviewEvent;
  DateTime? _lastPreviewFrameShownAt;
  bool _stopRequested = false;
  String _currentPreviewDetectionsPath = '';
  String _dataYamlPath = '';

  List<ImageItem> get filteredPreviewImages {
    final filter = folderFilter.value;
    return previewImages
        .where((image) => filter.matchesRelativePath(image.relativePath))
        .toList(growable: false);
  }

  ImageItem? get currentPreviewImage {
    final images = filteredPreviewImages;
    if (images.isEmpty ||
        selectedPreviewIndex.value < 0 ||
        selectedPreviewIndex.value >= images.length) {
      return null;
    }
    return images[selectedPreviewIndex.value];
  }

  String get activePreviewImagePath {
    final frame = currentPreviewFrame.value;
    if (frame != null &&
        (isRunning.value ||
            _previewFrameTimer != null ||
            _pendingPreviewEvent != null)) {
      return frame.imagePath;
    }
    final runningImagePath = currentImagePath.value;
    if (isRunning.value && runningImagePath.isNotEmpty) {
      return runningImagePath;
    }
    return currentPreviewImage?.path ?? '';
  }

  ImageItem? get activePreviewImage {
    final path = activePreviewImagePath;
    if (path.isEmpty) {
      return null;
    }
    return _previewImageByPath(path) ?? currentPreviewImage;
  }

  List<DetectionResult> get activePreviewDetections {
    final previewPath = activePreviewImagePath;
    if (previewPath.isEmpty) {
      return const [];
    }
    final frame = currentPreviewFrame.value;
    if (frame != null && _isSamePreviewPath(frame.imagePath, previewPath)) {
      return frame.detections;
    }
    final currentPath = currentImagePath.value;
    if (currentPath.isEmpty || currentPreviewDetections.isEmpty) {
      return const [];
    }
    if (_isSamePreviewPath(currentPath, previewPath) &&
        (_currentPreviewDetectionsPath.isEmpty ||
            _isSamePreviewPath(_currentPreviewDetectionsPath, previewPath))) {
      return currentPreviewDetections.toList(growable: false);
    }
    return const [];
  }

  String get activePreviewLabel {
    final path = activePreviewImagePath;
    if (path.isEmpty) {
      return '未选择预览图片';
    }
    return activePreviewImage?.relativePath ?? path;
  }

  String get previewStatus {
    final filteredImages = filteredPreviewImages;
    if (isRunning.value) {
      if (isStopping.value) {
        return '正在停止自动预标注...';
      }
      if (totalCount.value > 0) {
        return '自动预标注运行中：${processedCount.value}/${totalCount.value}';
      }
      return '自动预标注运行中...';
    }
    final output = result.value;
    if (output != null) {
      return '写入 ${output.writtenCount}，合并 ${output.mergedCount}，跳过 ${output.skippedCount}';
    }
    if (errorMessage.value != null) {
      return errorMessage.value!;
    }
    if (wasStopped.value) {
      return '已停止自动预标注';
    }
    if (filteredImages.isEmpty) {
      return imageDir.value.isEmpty ? '请选择图片目录' : '未找到可预览图片';
    }
    return folderFilter.value == DatasetFolderFilter.all
        ? '已加载 ${previewImages.length} 张预览图片'
        : '已筛选 ${filteredImages.length}/${previewImages.length} 张预览图片';
  }

  @override
  void onClose() {
    _cancelScheduledPreviewFrame();
    unawaited(_autoLabelSubscription?.cancel());
    super.onClose();
  }

  Future<void> pickModel() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: '请选择 YOLO ONNX 模型',
      type: FileType.custom,
      allowedExtensions: ['onnx'],
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path != null && path.trim().isNotEmpty) {
      modelPath.value = path;
    }
  }

  Future<void> pickImageDir() async {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '请选择数据集根目录或 images 图片目录',
    );
    if (directory == null || directory.trim().isEmpty) {
      return;
    }
    await _inferDatasetPaths(directory);
  }

  Future<void> pickLabelDir() async {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '请选择标签输出目录',
    );
    if (directory != null && directory.trim().isNotEmpty) {
      labelDir.value = directory;
    }
  }

  void setImgsz(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null) {
      imgsz.value = parsed;
    }
  }

  void setConf(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null) {
      conf.value = parsed;
    }
  }

  void setIou(String value) {
    final parsed = double.tryParse(value);
    if (parsed != null) {
      iou.value = parsed;
    }
  }

  void setStrategy(AutoLabelOverwriteStrategy nextStrategy) {
    strategy.value = nextStrategy;
  }

  void setFolderFilter(DatasetFolderFilter filter) {
    folderFilter.value = filter;
    _clampSelectedPreviewIndex();
  }

  Future<void> startAutoLabel() async {
    if (isRunning.value) {
      return;
    }

    isRunning.value = true;
    isStopping.value = false;
    wasStopped.value = false;
    _stopRequested = false;
    errorMessage.value = null;
    result.value = null;
    processedCount.value = 0;
    totalCount.value = 0;
    _resetDisplayedPreviewFrame();
    logs
      ..clear()
      ..add('开始自动预标注...');
    if (previewImages.isEmpty && imageDir.value.trim().isNotEmpty) {
      await _loadPreviewImages(imageDir.value);
    }
    try {
      AutoLabelResult? output;
      Future<void>? classCountRefresh;
      if (_stopRequested) {
        _markAutoLabelStopped();
        return;
      }
      final completion = Completer<void>();
      _autoLabelCompletion = completion;
      _autoLabelSubscription = _autoLabelService
          .autoLabelStream(_config())
          .listen(
            (event) {
              switch (event.type) {
                case AutoLabelProgressEventType.log:
                  final message = event.message;
                  if (message != null && message.isNotEmpty) {
                    logs.add(message);
                  }
                case AutoLabelProgressEventType.progress:
                  _handleProgressEvent(event);
                case AutoLabelProgressEventType.completed:
                  final eventResult = event.result;
                  output = eventResult;
                  if (eventResult != null) {
                    result.value = eventResult;
                    processedCount.value = event.processedCount;
                    totalCount.value = event.totalCount;
                    if (eventResult.classCount > 0) {
                      classCount.value = eventResult.classCount;
                    }
                    classCountRefresh = _refreshClassCountAfterAutoLabel();
                  }
              }
            },
            onError: (Object error, StackTrace stackTrace) {
              if (!completion.isCompleted) {
                completion.completeError(error, stackTrace);
              }
            },
            onDone: () {
              if (!completion.isCompleted) {
                completion.complete();
              }
            },
            cancelOnError: true,
          );

      await completion.future;
      if (_stopRequested) {
        _markAutoLabelStopped();
        return;
      }
      final completedOutput = output;
      if (completedOutput == null) {
        throw StateError('自动预标注未返回执行结果');
      }
      await classCountRefresh;
      logs.add('自动预标注完成。');
      AppToast.success(
        '自动预标注完成：写入 ${completedOutput.writtenCount}，合并 ${completedOutput.mergedCount}，跳过 ${completedOutput.skippedCount}',
      );
    } catch (error) {
      if (_stopRequested) {
        _markAutoLabelStopped();
        return;
      }
      _cancelScheduledPreviewFrame();
      errorMessage.value = error.toString();
      logs.add('自动预标注失败：$error');
      AppToast.error(error, source: '自动预标注');
    } finally {
      _autoLabelSubscription = null;
      _autoLabelCompletion = null;
      isRunning.value = false;
      isStopping.value = false;
      _stopRequested = false;
    }
  }

  Future<void> stopAutoLabel() async {
    if (!isRunning.value || isStopping.value) {
      return;
    }
    _stopRequested = true;
    isStopping.value = true;
    logs.add('正在停止自动预标注...');
    try {
      await _autoLabelSubscription?.cancel();
    } catch (error) {
      logs.add('停止自动预标注时清理任务失败：$error');
    } finally {
      final completion = _autoLabelCompletion;
      if (completion != null && !completion.isCompleted) {
        completion.complete();
      }
    }
  }

  void _markAutoLabelStopped() {
    _cancelScheduledPreviewFrame();
    wasStopped.value = true;
    if (!logs.contains('自动预标注已停止。')) {
      logs.add('自动预标注已停止。');
    }
    AppToast.success('已停止自动预标注');
  }

  AutoLabelConfig _config() {
    return AutoLabelConfig(
      modelPath: modelPath.value,
      imageDir: imageDir.value,
      labelDir: labelDir.value,
      imgsz: imgsz.value,
      conf: conf.value,
      iou: iou.value,
      classCount: classCount.value,
      strategy: strategy.value,
      folderFilter: folderFilter.value,
      dataYamlPath: _dataYamlPath,
    );
  }

  void selectPreviousPreview() {
    if (selectedPreviewIndex.value > 0) {
      selectedPreviewIndex.value--;
    }
  }

  void selectNextPreview() {
    if (selectedPreviewIndex.value < filteredPreviewImages.length - 1) {
      selectedPreviewIndex.value++;
    }
  }

  Future<void> openInAnnotation() async {
    if (imageDir.value.trim().isEmpty) {
      errorMessage.value = '请先选择图片目录';
      AppToast.error(errorMessage.value, source: '自动预标注');
      return;
    }
    await Get.toNamed(
      Routes.annotation,
      arguments: AnnotationOpenRequest(imageDir: imageDir.value),
    );
  }

  Future<void> _inferDatasetPaths(String selectedImageDir) async {
    late final DatasetPaths paths;
    try {
      paths = _imageScanService.validateDatasetImagesDir(selectedImageDir);
    } catch (error) {
      logs.add('无法识别数据集目录：$error');
      AppToast.error(error, source: '自动预标注');
      return;
    }

    imageDir.value = paths.imageDir;
    labelDir.value = paths.labelDir;
    _dataYamlPath = paths.dataYamlPath;
    await _loadPreviewImages(paths.imageDir);
    try {
      final classes = await _dataYamlService.readClasses(paths.dataYamlPath);
      classCount.value = classes.length;
      logs.add('已读取 ${classes.length} 个类别。');
    } catch (error) {
      logs.add('无法自动读取 data.yaml：$error');
    }
  }

  Future<void> _loadPreviewImages(String imagesDirectory) async {
    try {
      final scanResult = await _imageScanService.scanImagesDirectory(
        imagesDirectory,
      );
      previewImages.assignAll(scanResult.images);
      selectedPreviewIndex.value = 0;
      logs.add('已加载 ${scanResult.images.length} 张预览图片。');
      logs.addAll(scanResult.warnings);
    } catch (error) {
      previewImages.clear();
      selectedPreviewIndex.value = 0;
      logs.add('预览图片加载失败：$error');
      AppToast.error(error, source: '自动预标注');
    }
  }

  void _clampSelectedPreviewIndex() {
    final images = filteredPreviewImages;
    selectedPreviewIndex.value = images.isEmpty
        ? 0
        : selectedPreviewIndex.value.clamp(0, images.length - 1).toInt();
  }

  void _handleProgressEvent(AutoLabelProgressEvent event) {
    processedCount.value = event.processedCount;
    totalCount.value = event.totalCount;
    currentImagePath.value = event.currentImagePath;
    _currentPreviewDetectionsPath = event.currentImagePath;
    currentPreviewDetections.assignAll(event.currentDetections);
    if (event.currentImagePath.trim().isEmpty) {
      return;
    }
    final lastShownAt = _lastPreviewFrameShownAt;
    if (_previewFrameMinDuration == Duration.zero || lastShownAt == null) {
      _showPreviewFrame(event);
      return;
    }
    final elapsed = DateTime.now().difference(lastShownAt);
    if (elapsed >= _previewFrameMinDuration) {
      _showPreviewFrame(event);
      return;
    }
    _pendingPreviewEvent = event;
    _previewFrameTimer ??= Timer(
      _previewFrameMinDuration - elapsed,
      _showPendingPreviewFrame,
    );
  }

  void _showPendingPreviewFrame() {
    _previewFrameTimer = null;
    final event = _pendingPreviewEvent;
    _pendingPreviewEvent = null;
    if (event != null) {
      _showPreviewFrame(event);
    }
  }

  void _showPreviewFrame(AutoLabelProgressEvent event) {
    _cancelScheduledPreviewFrame();
    final imagePath = event.currentImagePath;
    currentPreviewFrame.value = AutoLabelPreviewFrame(
      imagePath: imagePath,
      imageItem: _previewImageByPath(imagePath),
      detections: event.currentDetections,
    );
    _selectPreviewByPath(imagePath);
    _lastPreviewFrameShownAt = DateTime.now();
  }

  void _resetDisplayedPreviewFrame() {
    _cancelScheduledPreviewFrame();
    _lastPreviewFrameShownAt = null;
    _currentPreviewDetectionsPath = '';
    currentImagePath.value = '';
    currentPreviewDetections.clear();
    currentPreviewFrame.value = null;
  }

  void _cancelScheduledPreviewFrame() {
    _previewFrameTimer?.cancel();
    _previewFrameTimer = null;
    _pendingPreviewEvent = null;
  }

  void _selectPreviewByPath(String imagePath) {
    if (imagePath.trim().isEmpty) {
      return;
    }
    final images = filteredPreviewImages;
    final normalizedPath = _normalizedPreviewPath(imagePath);
    final index = images.indexWhere(
      (image) => _normalizedPreviewPath(image.path) == normalizedPath,
    );
    if (index >= 0) {
      selectedPreviewIndex.value = index;
    } else {
      _clampSelectedPreviewIndex();
    }
  }

  ImageItem? _previewImageByPath(String imagePath) {
    if (imagePath.trim().isEmpty) {
      return null;
    }
    final normalizedPath = _normalizedPreviewPath(imagePath);
    for (final image in filteredPreviewImages) {
      if (_normalizedPreviewPath(image.path) == normalizedPath) {
        return image;
      }
    }
    for (final image in previewImages) {
      if (_normalizedPreviewPath(image.path) == normalizedPath) {
        return image;
      }
    }
    return null;
  }

  bool _isSamePreviewPath(String left, String right) {
    if (left.trim().isEmpty || right.trim().isEmpty) {
      return false;
    }
    return _normalizedPreviewPath(left) == _normalizedPreviewPath(right);
  }

  String _normalizedPreviewPath(String path) {
    return p.normalize(path).replaceAll('\\', '/').toLowerCase();
  }

  Future<void> _refreshClassCountAfterAutoLabel() async {
    if (_dataYamlPath.isEmpty) {
      return;
    }
    try {
      final classes = await _dataYamlService.readClasses(_dataYamlPath);
      classCount.value = classes.length;
    } catch (error) {
      logs.add('自动预标注后刷新类别数量失败：$error');
    }
  }
}
