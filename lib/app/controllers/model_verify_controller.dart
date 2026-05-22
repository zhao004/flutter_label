import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as p;

import '../models/detection_result.dart';
import '../models/model_verify_config.dart';
import '../services/app_toast_service.dart';
import '../services/data_yaml_service.dart';
import '../services/model_verify_service.dart';

class ModelVerifyController extends GetxController {
  ModelVerifyController({
    ModelVerifyService modelVerifyService = const ModelVerifyService(),
    DataYamlService dataYamlService = const DataYamlService(),
  }) : _modelVerifyService = modelVerifyService,
       _dataYamlService = dataYamlService;

  final ModelVerifyService _modelVerifyService;
  final DataYamlService _dataYamlService;

  final modelPath = ''.obs;
  final sourcePath = ''.obs;
  final mode = ModelVerifyMode.image.obs;
  final imgsz = 640.obs;
  final conf = 0.35.obs;
  final iou = 0.45.obs;
  final classCount = 0.obs;
  final isRunning = false.obs;
  final isStopping = false.obs;
  final logs = <String>[].obs;
  final errorMessage = RxnString();
  final imageResult = Rxn<ModelVerifyResult>();
  final windowResult = Rxn<RealtimeDetectionResult>();
  final hoveredWindow = Rxn<WindowSelectionInfo>();
  final selectedWindow = Rxn<WindowSelectionInfo>();
  final verifyStage = ''.obs;
  final processedFrames = 0.obs;
  final totalFrames = 0.obs;
  final currentFramePath = ''.obs;

  StreamSubscription<RealtimeDetectionResult>? _windowSubscription;
  Completer<void>? _windowCompletion;
  WindowSelectionInfo? _highlightedWindow;
  bool _stopRequested = false;

  @override
  void onClose() {
    unawaited(_restoreHighlightedWindowBorder(logFailure: false));
    unawaited(_windowSubscription?.cancel());
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

  Future<void> pickSource() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: '请选择图片文件',
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'bmp', 'webp'],
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path != null && path.trim().isNotEmpty) {
      sourcePath.value = path;
      await _loadClassCountForSource(path);
    }
  }

  void setMode(ModelVerifyMode nextMode) {
    if (mode.value == ModelVerifyMode.window &&
        nextMode != ModelVerifyMode.window) {
      unawaited(_restoreHighlightedWindowBorder(logFailure: false));
    }
    mode.value = nextMode;
    sourcePath.value = '';
    imageResult.value = null;
    windowResult.value = null;
    if (nextMode != ModelVerifyMode.window) {
      hoveredWindow.value = null;
      selectedWindow.value = null;
    }
    _resetProgress();
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

  void setClassCount(String value) {
    final parsed = int.tryParse(value);
    if (parsed != null && parsed >= 0) {
      classCount.value = parsed;
    }
  }

  Future<void> runVerify() async {
    if (isRunning.value) {
      return;
    }

    isRunning.value = true;
    isStopping.value = false;
    _stopRequested = false;
    errorMessage.value = null;
    imageResult.value = null;
    windowResult.value = null;
    _resetProgress();
    logs
      ..clear()
      ..add('开始模型验证...');
    try {
      switch (mode.value) {
        case ModelVerifyMode.image:
          verifyStage.value = '正在验证图片...';
          final result = await _modelVerifyService.verifyImage(_config());
          if (_stopRequested) {
            _markVerifyStopped();
            return;
          }
          imageResult.value = result;
          logs.addAll(result.logs);
          logs.add('图片验证完成，检测到 ${result.detections.length} 个目标。');
          verifyStage.value = '图片验证完成';
          AppToast.success('图片验证完成，检测到 ${result.detections.length} 个目标');
        case ModelVerifyMode.window:
          await _runWindowVerify();
      }
    } catch (error) {
      if (_stopRequested) {
        _markVerifyStopped();
        return;
      }
      errorMessage.value = error.toString();
      logs.add('模型验证失败：$error');
      AppToast.error(error, source: '模型验证');
    } finally {
      isRunning.value = false;
      isStopping.value = false;
      _windowSubscription = null;
      _windowCompletion = null;
      _stopRequested = false;
    }
  }

  Future<void> stopVerify() async {
    if (!isRunning.value || isStopping.value) {
      return;
    }
    _stopRequested = true;
    isStopping.value = true;
    verifyStage.value = '正在停止验证...';
    if (mode.value != ModelVerifyMode.window) {
      return;
    }
    await _windowSubscription?.cancel();
    final windowCompletion = _windowCompletion;
    if (windowCompletion != null && !windowCompletion.isCompleted) {
      windowCompletion.complete();
    }
  }

  Future<void> previewWindowUnderCursor() async {
    if (isRunning.value) {
      return;
    }
    hoveredWindow.value = await _modelVerifyService.getWindowUnderCursor();
  }

  Future<void> selectWindowUnderCursor() async {
    if (isRunning.value) {
      return;
    }
    final window = await _modelVerifyService.getWindowUnderCursor();
    hoveredWindow.value = window;
    if (window == null || !window.isValid) {
      errorMessage.value = '未选择到可验证窗口';
      AppToast.error(errorMessage.value, source: '模型验证');
      return;
    }
    await _restoreHighlightedWindowBorder(logFailure: false);
    errorMessage.value = null;
    selectedWindow.value = window;
    sourcePath.value = window.title;
    logs.add('已选择窗口：${window.title}（${window.width}x${window.height}）');
    final highlighted = await _modelVerifyService.flashSelectedWindowBorder(
      window.handle,
    );
    if (!highlighted) {
      logs.add('窗口边框视觉反馈未触发，可能是系统或目标窗口不支持。');
      return;
    }
    _highlightedWindow = window;
  }

  Future<void> _restoreHighlightedWindowBorder({
    required bool logFailure,
  }) async {
    final window = _highlightedWindow;
    if (window == null) {
      return;
    }
    _highlightedWindow = null;
    final restored = await _modelVerifyService.restoreSelectedWindowBorder(
      window.handle,
    );
    if (!restored && logFailure) {
      logs.add('窗口边框颜色恢复失败，可能是目标窗口已关闭或系统不支持。');
    }
  }

  ModelVerifyConfig _config() {
    return ModelVerifyConfig(
      modelPath: modelPath.value,
      sourcePath: sourcePath.value,
      mode: mode.value,
      imgsz: imgsz.value,
      conf: conf.value,
      iou: iou.value,
      classCount: classCount.value,
      windowHandle: selectedWindow.value?.handle ?? 0,
      windowTitle: selectedWindow.value?.title ?? '',
    );
  }

  Future<void> _runWindowVerify() async {
    final window = selectedWindow.value;
    if (window == null || !window.isValid) {
      throw const FormatException('请先拖动选择一个要验证的窗口');
    }
    var count = 0;
    final completion = Completer<void>();
    _windowCompletion = completion;
    _windowSubscription = _modelVerifyService
        .verifyWindowStream(_config(), onProgress: _handleVerifyProgress)
        .listen(
          (result) {
            count++;
            windowResult.value = result;
            verifyStage.value =
                '窗口验证中：${result.fps.toStringAsFixed(1)} FPS，推理 ${result.inferMs.toStringAsFixed(1)} ms';
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
        );
    await completion.future;
    if (_stopRequested) {
      _markVerifyStopped();
      return;
    }
    logs.add('窗口验证结束，共处理 $count 帧。');
  }

  void _handleVerifyProgress(ModelVerifyProgressEvent event) {
    verifyStage.value = event.message.isEmpty
        ? event.stage.label
        : event.message;
    processedFrames.value = event.processedFrames;
    totalFrames.value = event.totalFrames;
    currentFramePath.value = event.currentFramePath;
    if (event.stage != ModelVerifyProgressStage.inferencing &&
        event.message.isNotEmpty) {
      logs.add(event.message);
    }
  }

  void _resetProgress() {
    verifyStage.value = '';
    processedFrames.value = 0;
    totalFrames.value = 0;
    currentFramePath.value = '';
  }

  void _markVerifyStopped() {
    verifyStage.value = ModelVerifyProgressStage.stopped.label;
    if (!logs.contains('模型验证已停止。')) {
      logs.add('模型验证已停止。');
    }
    AppToast.success('已停止模型验证');
  }

  Future<void> _loadClassCountForSource(String path) async {
    final dataYamlPath = _findNearestDataYamlPath(path);
    if (dataYamlPath == null) {
      logs.add('未自动找到 data.yaml，可手动填写类别数量。');
      return;
    }
    try {
      final classes = await _dataYamlService.readClasses(dataYamlPath);
      classCount.value = classes.length;
      logs.add('已读取 ${classes.length} 个类别。');
    } catch (error) {
      logs.add('无法自动读取 data.yaml：$error，可手动填写类别数量。');
    }
  }

  String? _findNearestDataYamlPath(String source) {
    var current = FileSystemEntity.isDirectorySync(source)
        ? p.normalize(source)
        : p.dirname(p.normalize(source));
    for (var depth = 0; depth < 8; depth++) {
      final candidate = p.join(current, 'data.yaml');
      if (File(candidate).existsSync()) {
        return candidate;
      }
      final parent = p.dirname(current);
      if (parent == current) {
        break;
      }
      current = parent;
    }
    return null;
  }
}
