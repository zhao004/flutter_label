import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../models/detection_result.dart';
import '../models/model_verify_config.dart';
import 'native_library_loader.dart';
import 'native_model_lock.dart';

typedef ModelVerifyImageNativeRunner =
    FutureOr<String?> Function(ModelVerifyConfig config, List<String> logs);

typedef _InitModelNative = Int32 Function(Pointer<Utf8>, Int32);
typedef _InitModelDart = int Function(Pointer<Utf8>, int);

typedef _DetectImageWithClassCountNative =
    Pointer<Utf8> Function(Pointer<Utf8>, Float, Float, Int32);
typedef _DetectImageWithClassCountDart =
    Pointer<Utf8> Function(Pointer<Utf8>, double, double, int);

typedef _DetectBgraFrameWithClassCountNative =
    Pointer<Utf8> Function(
      Pointer<Uint8>,
      Int32,
      Int32,
      Int32,
      Float,
      Float,
      Int32,
    );
typedef _DetectBgraFrameWithClassCountDart =
    Pointer<Utf8> Function(Pointer<Uint8>, int, int, int, double, double, int);

typedef _ReleaseModelNative = Void Function();
typedef _ReleaseModelDart = void Function();

typedef _FreeStringNative = Void Function(Pointer<Utf8>);
typedef _FreeStringDart = void Function(Pointer<Utf8>);

typedef _GetLastErrorCodeNative = Int32 Function();
typedef _GetLastErrorCodeDart = int Function();

typedef _GetModelInputSizeNative = Int32 Function();
typedef _GetModelInputSizeDart = int Function();

typedef _GetModelProviderNative = Pointer<Utf8> Function();
typedef _GetModelProviderDart = Pointer<Utf8> Function();

typedef _GetWindowUnderCursorNative = Pointer<Utf8> Function();
typedef _GetWindowUnderCursorDart = Pointer<Utf8> Function();

typedef _WindowBorderActionNative = Int32 Function(Uint64);
typedef _WindowBorderActionDart = int Function(int);

typedef _CaptureWindowFrameNative =
    Pointer<_CapturedWindowFrameNative> Function(Uint64);
typedef _CaptureWindowFrameDart =
    Pointer<_CapturedWindowFrameNative> Function(int);

typedef _FreeWindowFrameNative =
    Void Function(Pointer<_CapturedWindowFrameNative>);
typedef _FreeWindowFrameDart =
    void Function(Pointer<_CapturedWindowFrameNative>);

final class _CapturedWindowFrameNative extends Struct {
  @Int32()
  external int width;

  @Int32()
  external int height;

  @Int32()
  external int stride;

  @Double()
  external double captureMs;

  external Pointer<Uint8> bgra;
}

const String _workerEventType = 'type';
const String _workerFrameEvent = 'frame';
const String _workerLogEvent = 'log';
const String _workerProgressEvent = 'progress';
const String _workerErrorEvent = 'error';
const String _windowWorkerFrameEvent = 'windowFrame';

typedef ModelVerifyProgressCallback =
    void Function(ModelVerifyProgressEvent event);

enum ModelVerifyProgressStage {
  preparing,
  loadingModel,
  inferencing,
  completed,
  stopped,
}

extension ModelVerifyProgressStageText on ModelVerifyProgressStage {
  String get label {
    return switch (this) {
      ModelVerifyProgressStage.preparing => '准备验证',
      ModelVerifyProgressStage.loadingModel => '正在加载模型',
      ModelVerifyProgressStage.inferencing => '正在推理',
      ModelVerifyProgressStage.completed => '验证完成',
      ModelVerifyProgressStage.stopped => '已停止验证',
    };
  }
}

/// 模型验证进度事件，用于 UI 显示后台 isolate 的阶段和帧进度。
class ModelVerifyProgressEvent {
  const ModelVerifyProgressEvent({
    required this.stage,
    required this.message,
    this.processedFrames = 0,
    this.totalFrames = 0,
    this.currentFramePath = '',
  });

  final ModelVerifyProgressStage stage;
  final String message;
  final int processedFrames;
  final int totalFrames;
  final String currentFramePath;

  double? get progress {
    if (totalFrames <= 0) {
      return null;
    }
    return (processedFrames / totalFrames).clamp(0, 1).toDouble();
  }
}

class ModelVerifyResult {
  const ModelVerifyResult({
    required this.imagePath,
    required this.detections,
    required this.inferMs,
    required this.captureMs,
    required this.fps,
    required this.usedNative,
    required this.logs,
  });

  final String imagePath;
  final List<DetectionResult> detections;
  final double inferMs;
  final double captureMs;
  final double fps;
  final bool usedNative;
  final List<String> logs;
}

class ModelVerifyService {
  const ModelVerifyService({ModelVerifyImageNativeRunner? imageNativeRunner})
    : _imageNativeRunner = imageNativeRunner;

  final ModelVerifyImageNativeRunner? _imageNativeRunner;

  Future<ModelVerifyResult> verifyImage(ModelVerifyConfig config) async {
    _validateConfig(config, onlyImage: true);
    final logs = <String>[];
    final result = await _runImagePredict(config, logs);
    return result;
  }

  Stream<RealtimeDetectionResult> _verifyWindowWithNativeWorker(
    ModelVerifyConfig config, {
    ModelVerifyProgressCallback? onProgress,
  }) {
    final controller = StreamController<RealtimeDetectionResult>();
    ReceivePort? receivePort;
    Isolate? worker;
    var cancelled = false;

    controller.onListen = () {
      unawaited(
        NativeModelLock.run(() async {
          receivePort = ReceivePort();
          try {
            worker = await Isolate.spawn(_runNativeWindowVerifyWorker, {
              'sendPort': receivePort!.sendPort,
              'nativeLibraryPath': _nativeLibraryPath(),
              'modelPath': config.modelPath,
              'windowHandle': config.windowHandle,
              'windowTitle': config.windowTitle,
              'imgsz': config.imgsz,
              'conf': config.conf,
              'iou': config.iou,
              'classCount': config.classCount,
              'fps': 5.0,
            });
            await for (final rawMessage in receivePort!) {
              if (cancelled) {
                break;
              }
              if (rawMessage is! Map) {
                continue;
              }
              final type = rawMessage[_workerEventType]?.toString();
              if (type == _workerProgressEvent) {
                onProgress?.call(_progressEventFromWorkerMessage(rawMessage));
                continue;
              }
              if (type == _workerErrorEvent) {
                throw StateError(rawMessage['message']?.toString() ?? '窗口验证失败');
              }
              if (type == _windowWorkerFrameEvent) {
                final transfer = rawMessage['frameBytes'];
                final bytes = transfer is TransferableTypedData
                    ? transfer.materialize().asUint8List()
                    : Uint8List(0);
                if (!controller.isClosed) {
                  controller.add(
                    RealtimeDetectionResult(
                      fps: (rawMessage['fps'] as num?)?.toDouble() ?? 0,
                      inferMs: (rawMessage['inferMs'] as num?)?.toDouble() ?? 0,
                      captureMs:
                          (rawMessage['captureMs'] as num?)?.toDouble() ?? 0,
                      detections: _parseDetectionJson(
                        rawMessage['json']?.toString() ?? '[]',
                      ),
                      frameBytes: bytes,
                      frameWidth: _workerIntValue(rawMessage, 'frameWidth'),
                      frameHeight: _workerIntValue(rawMessage, 'frameHeight'),
                      frameStride: _workerIntValue(rawMessage, 'frameStride'),
                      sourceTitle: rawMessage['windowTitle']?.toString() ?? '',
                    ),
                  );
                }
                continue;
              }
            }
          } catch (error, stackTrace) {
            if (!cancelled && !controller.isClosed) {
              controller.addError(error, stackTrace);
            }
          } finally {
            receivePort?.close();
            worker?.kill(priority: Isolate.immediate);
            if (!controller.isClosed) {
              await controller.close();
            }
          }
        }),
      );
    };
    controller.onCancel = () {
      cancelled = true;
      receivePort?.close();
      worker?.kill(priority: Isolate.immediate);
    };
    return controller.stream;
  }

  Future<WindowSelectionInfo?> getWindowUnderCursor() async {
    if (!Platform.isWindows) {
      return null;
    }
    DynamicLibrary library;
    try {
      library = DynamicLibrary.open(_nativeLibraryPath());
    } catch (_) {
      return null;
    }
    final getWindowUnderCursor = library
        .lookupFunction<_GetWindowUnderCursorNative, _GetWindowUnderCursorDart>(
          'get_window_under_cursor',
        );
    final freeString = library
        .lookupFunction<_FreeStringNative, _FreeStringDart>('free_string');
    final pointer = getWindowUnderCursor();
    if (pointer == nullptr) {
      return null;
    }
    late final String json;
    try {
      json = pointer.toDartString();
    } finally {
      freeString(pointer);
    }
    return _parseWindowSelectionJson(json);
  }

  /// 闪烁并保持目标窗口边框为红色；失败时返回 false，避免影响窗口选择主流程。
  Future<bool> flashSelectedWindowBorder(int windowHandle) async {
    return _runWindowBorderAction(windowHandle, 'flash_window_border');
  }

  /// 恢复目标窗口边框颜色；恢复失败不抛异常，避免页面退出流程被阻断。
  Future<bool> restoreSelectedWindowBorder(int windowHandle) async {
    return _runWindowBorderAction(windowHandle, 'restore_window_border');
  }

  Future<bool> _runWindowBorderAction(
    int windowHandle,
    String symbolName,
  ) async {
    if (!Platform.isWindows || windowHandle <= 0) {
      return false;
    }
    final nativeLibraryPath = _nativeLibraryPath();
    try {
      return await Isolate.run(
        () => _runWindowBorderActionWithLibrary(
          nativeLibraryPath,
          symbolName,
          windowHandle,
        ),
      );
    } catch (_) {
      return false;
    }
  }

  Future<RealtimeDetectionResult> verifyWindow(ModelVerifyConfig config) async {
    return verifyWindowStream(config).first;
  }

  Stream<RealtimeDetectionResult> verifyWindowStream(
    ModelVerifyConfig config, {
    ModelVerifyProgressCallback? onProgress,
  }) {
    _validateConfig(config, onlyImage: false);
    if (config.mode != ModelVerifyMode.window) {
      throw const FormatException('当前验证模式不是窗口');
    }
    if (!Platform.isWindows) {
      throw UnsupportedError('窗口实时验证仅支持 Windows 桌面端');
    }
    if (config.windowHandle <= 0) {
      throw const FormatException('请先拖动选择一个要验证的窗口');
    }
    return _verifyWindowWithNativeWorker(config, onProgress: onProgress);
  }

  Future<ModelVerifyResult> _runImagePredict(
    ModelVerifyConfig config,
    List<String> logs,
  ) async {
    if (_imageNativeRunner == null) {
      return _runImagePredictWithNativeWorker(config);
    }

    final nativeResult = await _imageNativeRunner(config, logs);
    if (nativeResult == null || nativeResult.isEmpty) {
      throw StateError(_nativeFailureMessage(null, logs));
    }
    final detections = _parseDetectionJson(nativeResult);
    final inferMs = detections.isEmpty ? 0.0 : 0.0;
    return ModelVerifyResult(
      imagePath: config.sourcePath,
      detections: detections,
      inferMs: inferMs,
      captureMs: 0,
      fps: 0,
      usedNative: true,
      logs: logs,
    );
  }

  Future<ModelVerifyResult> _runImagePredictWithNativeWorker(
    ModelVerifyConfig config,
  ) async {
    final nativeLibraryPath = _nativeLibraryPath();
    final workerMessage = <String, Object?>{
      'nativeLibraryPath': nativeLibraryPath,
      'modelPath': config.modelPath,
      'imagePath': config.sourcePath,
      'imgsz': config.imgsz,
      'conf': config.conf,
      'iou': config.iou,
      'classCount': config.classCount,
    };
    final rawResult = await NativeModelLock.run(
      () => Isolate.run(() => _runNativeImageVerifyWorker(workerMessage)),
    );
    final logs = _workerStringListValue(rawResult, 'logs');
    if (rawResult[_workerEventType] == _workerErrorEvent) {
      throw StateError(
        rawResult['message']?.toString() ?? _nativeFailureMessage(null, logs),
      );
    }
    final json = rawResult['json']?.toString() ?? '[]';
    return ModelVerifyResult(
      imagePath: rawResult['imagePath']?.toString() ?? config.sourcePath,
      detections: _parseDetectionJson(json),
      inferMs: (rawResult['inferMs'] as num?)?.toDouble() ?? 0.0,
      captureMs: 0,
      fps: 0,
      usedNative: true,
      logs: logs,
    );
  }

  String _nativeFailureMessage(int? nativeResult, List<String> logs) {
    final reason = nativeResult == null
        ? 'native_core 动态库不可用或检测未返回结果'
        : 'native_core 单图检测失败，错误码：$nativeResult（${_nativeErrorDescription(nativeResult)}）';
    final details = logs.isEmpty ? '' : '\n${logs.join('\n')}';
    return '$reason。模型验证必须通过 Dart FFI + native_core + ONNX Runtime 执行，'
        '请确认 native_core.dll 与 onnxruntime.dll 已安装到应用 lib 目录，'
        '模型为受支持的 YOLO ONNX 格式。$details';
  }

  String _nativeErrorDescription(int result, {int? modelInputSize}) =>
      _describeNativeDetectionError(result, modelInputSize: modelInputSize);

  List<DetectionResult> _parseDetectionJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! List) {
      return const [];
    }
    return [
      for (final item in decoded)
        if (item is Map<String, dynamic>)
          DetectionResult(
            classId: (item['class_id'] as num?)?.toInt() ?? 0,
            className:
                item['class_name']?.toString() ?? '${item['class_id'] ?? 0}',
            confidence: (item['confidence'] as num?)?.toDouble() ?? 0,
            left: (item['x'] as num?)?.toDouble() ?? 0,
            top: (item['y'] as num?)?.toDouble() ?? 0,
            width: (item['w'] as num?)?.toDouble() ?? 0,
            height: (item['h'] as num?)?.toDouble() ?? 0,
            sourceWidth: (item['image_width'] as num?)?.toInt(),
            sourceHeight: (item['image_height'] as num?)?.toInt(),
          ),
    ];
  }

  WindowSelectionInfo? _parseWindowSelectionJson(String json) {
    final decoded = jsonDecode(json);
    if (decoded is! Map) {
      return null;
    }
    final handle = (decoded['handle'] as num?)?.toInt() ?? 0;
    final title = decoded['title']?.toString() ?? '';
    final width = (decoded['width'] as num?)?.toInt() ?? 0;
    final height = (decoded['height'] as num?)?.toInt() ?? 0;
    if (handle <= 0 || title.trim().isEmpty || width <= 0 || height <= 0) {
      return null;
    }
    return WindowSelectionInfo(
      handle: handle,
      title: title,
      left: (decoded['left'] as num?)?.toInt() ?? 0,
      top: (decoded['top'] as num?)?.toInt() ?? 0,
      width: width,
      height: height,
    );
  }

  String _nativeLibraryPath() {
    return nativeCoreLibraryPath();
  }

  void _validateConfig(ModelVerifyConfig config, {required bool onlyImage}) {
    if (!File(config.modelPath).existsSync()) {
      throw FileSystemException('模型文件不存在', config.modelPath);
    }
    if (p.extension(config.modelPath).toLowerCase() != '.onnx') {
      throw const FormatException('当前阶段仅支持 ONNX 模型文件');
    }
    if (config.mode != ModelVerifyMode.window &&
        !File(config.sourcePath).existsSync() &&
        !Directory(config.sourcePath).existsSync()) {
      throw FileSystemException('验证源不存在', config.sourcePath);
    }
    if (config.imgsz < 32 || config.imgsz > 4096) {
      throw const FormatException('imgsz 必须在 32 到 4096 之间');
    }
    if (config.conf < 0 || config.conf > 1) {
      throw const FormatException('conf 必须在 0 到 1 之间');
    }
    if (config.iou < 0 || config.iou > 1) {
      throw const FormatException('iou 必须在 0 到 1 之间');
    }
    if (config.classCount < 0) {
      throw const FormatException('类别数量不能小于 0');
    }
    if (onlyImage && p.extension(config.sourcePath).toLowerCase() == '') {
      throw const FormatException('图片验证请传入单张图片文件');
    }
  }
}

Map<String, Object?> _runNativeImageVerifyWorker(Map<String, Object?> message) {
  DynamicLibrary? library;
  var initialized = false;
  final logs = <String>[];
  try {
    final nativeLibraryPath = _requiredWorkerString(
      message,
      'nativeLibraryPath',
    );
    final modelPath = _requiredWorkerString(message, 'modelPath');
    final imagePath = _requiredWorkerString(message, 'imagePath');
    final imgsz = _requiredWorkerInt(message, 'imgsz');
    final conf = _requiredWorkerDouble(message, 'conf');
    final iou = _requiredWorkerDouble(message, 'iou');
    final classCount = _requiredWorkerInt(message, 'classCount');

    library = DynamicLibrary.open(nativeLibraryPath);
    logs.add('native_core 单图验证后台任务已启动。');
    if (classCount <= 0) {
      logs.add('未提供类别数量，部分 YOLO 输出结构的解析可能不准确。');
    }

    final initModel = library.lookupFunction<_InitModelNative, _InitModelDart>(
      'init_model',
    );
    final detectImage = library
        .lookupFunction<
          _DetectImageWithClassCountNative,
          _DetectImageWithClassCountDart
        >('detect_image_with_class_count');
    final freeString = library
        .lookupFunction<_FreeStringNative, _FreeStringDart>('free_string');
    final getLastErrorCode = library
        .lookupFunction<_GetLastErrorCodeNative, _GetLastErrorCodeDart>(
          'get_last_error_code',
        );
    final getModelInputSize = library
        .lookupFunction<_GetModelInputSizeNative, _GetModelInputSizeDart>(
          'get_model_input_size',
        );
    final getModelProvider = library
        .lookupFunction<_GetModelProviderNative, _GetModelProviderDart>(
          'get_model_provider',
        );

    final nativeModelPath = modelPath.toNativeUtf8();
    try {
      final initResult = initModel(nativeModelPath, imgsz);
      if (initResult != 0) {
        final modelInputSize = getModelInputSize();
        return _workerErrorResult(
          'native_core 初始化模型失败，错误码：$initResult（${_describeNativeDetectionError(initResult, modelInputSize: modelInputSize)}）',
          logs,
        );
      }
      initialized = true;
    } finally {
      malloc.free(nativeModelPath);
    }

    final modelInputSize = getModelInputSize();
    if (modelInputSize > 0) {
      logs.add('native_core 模型输入尺寸：${modelInputSize}x$modelInputSize。');
    }
    logs.add(
      'native_core 推理 Provider：${_readNativeModelProvider(getModelProvider: getModelProvider, freeString: freeString)}。',
    );

    final nativeImagePath = imagePath.toNativeUtf8();
    final stopwatch = Stopwatch()..start();
    Pointer<Utf8> jsonPointer = nullptr;
    try {
      jsonPointer = detectImage(nativeImagePath, conf, iou, classCount);
      if (jsonPointer == nullptr) {
        final errorCode = getLastErrorCode();
        return _workerErrorResult(
          'native_core 单图检测失败，错误码：$errorCode（${_describeNativeDetectionError(errorCode)}）',
          logs,
        );
      }
      late final String json;
      try {
        json = jsonPointer.toDartString();
      } finally {
        freeString(jsonPointer);
      }
      stopwatch.stop();
      logs.add('native_core 单图检测成功。');
      return {
        _workerEventType: _workerFrameEvent,
        'imagePath': imagePath,
        'json': json,
        'inferMs': stopwatch.elapsedMicroseconds / 1000.0,
        'logs': logs,
      };
    } finally {
      malloc.free(nativeImagePath);
    }
  } catch (error) {
    return _workerErrorResult('单图验证后台任务失败：$error', logs);
  } finally {
    if (initialized && library != null) {
      final releaseModel = library
          .lookupFunction<_ReleaseModelNative, _ReleaseModelDart>(
            'release_model',
          );
      releaseModel();
    }
  }
}

void _runNativeWindowVerifyWorker(Map<String, Object?> message) async {
  final sendPort = message['sendPort'];
  if (sendPort is! SendPort) {
    return;
  }

  DynamicLibrary? library;
  var initialized = false;
  try {
    final nativeLibraryPath = _requiredWorkerString(
      message,
      'nativeLibraryPath',
    );
    final modelPath = _requiredWorkerString(message, 'modelPath');
    final windowHandle = _requiredWorkerInt(message, 'windowHandle');
    final windowTitle = _workerOptionalString(message['windowTitle']);
    final imgsz = _requiredWorkerInt(message, 'imgsz');
    final conf = _requiredWorkerDouble(message, 'conf');
    final iou = _requiredWorkerDouble(message, 'iou');
    final classCount = _requiredWorkerInt(message, 'classCount');
    final fps = _requiredWorkerDouble(message, 'fps');
    final frameInterval = Duration(
      milliseconds: fps <= 0 ? 200 : (1000 / fps).round(),
    );

    library = DynamicLibrary.open(nativeLibraryPath);
    _sendWorkerProgress(
      sendPort,
      stage: ModelVerifyProgressStage.loadingModel,
      message: '正在加载窗口验证模型...',
    );
    if (classCount <= 0) {
      _sendWorkerLog(sendPort, '未提供类别数量，部分 YOLO 输出结构的解析可能不准确。');
    }

    final initModel = library.lookupFunction<_InitModelNative, _InitModelDart>(
      'init_model',
    );
    final captureWindowFrame = library
        .lookupFunction<_CaptureWindowFrameNative, _CaptureWindowFrameDart>(
          'capture_window_frame',
        );
    final freeWindowFrame = library
        .lookupFunction<_FreeWindowFrameNative, _FreeWindowFrameDart>(
          'free_window_frame',
        );
    final detectFrame = library
        .lookupFunction<
          _DetectBgraFrameWithClassCountNative,
          _DetectBgraFrameWithClassCountDart
        >('detect_bgra_frame_with_class_count');
    final freeString = library
        .lookupFunction<_FreeStringNative, _FreeStringDart>('free_string');
    final getLastErrorCode = library
        .lookupFunction<_GetLastErrorCodeNative, _GetLastErrorCodeDart>(
          'get_last_error_code',
        );
    final getModelInputSize = library
        .lookupFunction<_GetModelInputSizeNative, _GetModelInputSizeDart>(
          'get_model_input_size',
        );
    final getModelProvider = library
        .lookupFunction<_GetModelProviderNative, _GetModelProviderDart>(
          'get_model_provider',
        );

    final nativeModelPath = modelPath.toNativeUtf8();
    try {
      final initResult = initModel(nativeModelPath, imgsz);
      if (initResult != 0) {
        final modelInputSize = getModelInputSize();
        _sendWorkerError(
          sendPort,
          'native_core 初始化模型失败，错误码：$initResult（${_describeNativeDetectionError(initResult, modelInputSize: modelInputSize)}）',
        );
        return;
      }
      initialized = true;
    } finally {
      malloc.free(nativeModelPath);
    }

    final modelInputSize = getModelInputSize();
    if (modelInputSize > 0) {
      _sendWorkerProgress(
        sendPort,
        stage: ModelVerifyProgressStage.inferencing,
        message: '窗口验证运行中，模型输入尺寸 ${modelInputSize}x$modelInputSize。',
      );
    }
    _sendWorkerLog(
      sendPort,
      'native_core 推理 Provider：${_readNativeModelProvider(getModelProvider: getModelProvider, freeString: freeString)}。',
    );

    while (true) {
      final loopWatch = Stopwatch()..start();
      final framePointer = captureWindowFrame(windowHandle);
      if (framePointer == nullptr) {
        _sendWorkerError(sendPort, '窗口捕获失败，请确认目标窗口仍然存在且未最小化。');
        return;
      }
      Pointer<Utf8> jsonPointer = nullptr;
      try {
        final frame = framePointer.ref;
        jsonPointer = detectFrame(
          frame.bgra,
          frame.width,
          frame.height,
          frame.stride,
          conf,
          iou,
          classCount,
        );
        if (jsonPointer == nullptr) {
          final errorCode = getLastErrorCode();
          _sendWorkerError(
            sendPort,
            'native_core 窗口帧检测失败，错误码：$errorCode（${_describeNativeDetectionError(errorCode)}）',
          );
          return;
        }
        late final String json;
        try {
          json = jsonPointer.toDartString();
        } finally {
          freeString(jsonPointer);
          jsonPointer = nullptr;
        }
        final byteCount = frame.stride * frame.height;
        final bytes = Uint8List.fromList(frame.bgra.asTypedList(byteCount));
        loopWatch.stop();
        final elapsedMs = loopWatch.elapsedMicroseconds / 1000.0;
        final currentFps = elapsedMs <= 0 ? fps : 1000.0 / elapsedMs;
        sendPort.send({
          _workerEventType: _windowWorkerFrameEvent,
          'windowTitle': windowTitle,
          'frameBytes': TransferableTypedData.fromList([bytes]),
          'frameWidth': frame.width,
          'frameHeight': frame.height,
          'frameStride': frame.stride,
          'captureMs': frame.captureMs,
          'inferMs': elapsedMs - frame.captureMs,
          'fps': currentFps > fps ? fps : currentFps,
          'json': json,
        });
      } finally {
        if (jsonPointer != nullptr) {
          freeString(jsonPointer);
        }
        freeWindowFrame(framePointer);
      }
      final remaining = frameInterval - loopWatch.elapsed;
      if (remaining > Duration.zero) {
        await Future<void>.delayed(remaining);
      } else {
        await Future<void>.delayed(Duration.zero);
      }
    }
  } catch (error) {
    _sendWorkerError(sendPort, '窗口验证后台任务失败：$error');
  } finally {
    if (initialized && library != null) {
      final releaseModel = library
          .lookupFunction<_ReleaseModelNative, _ReleaseModelDart>(
            'release_model',
          );
      releaseModel();
    }
  }
}

bool _runWindowBorderActionWithLibrary(
  String nativeLibraryPath,
  String symbolName,
  int windowHandle,
) {
  if (windowHandle <= 0) {
    return false;
  }
  try {
    final library = DynamicLibrary.open(nativeLibraryPath);
    final action = library
        .lookupFunction<_WindowBorderActionNative, _WindowBorderActionDart>(
          symbolName,
        );
    return action(windowHandle) == 1;
  } catch (_) {
    return false;
  }
}

String _readNativeModelProvider({
  required _GetModelProviderDart getModelProvider,
  required _FreeStringDart freeString,
}) {
  final providerPointer = getModelProvider();
  if (providerPointer == nullptr) {
    return 'unknown';
  }
  try {
    final provider = providerPointer.toDartString().trim();
    return provider.isEmpty ? 'unknown' : provider;
  } finally {
    freeString(providerPointer);
  }
}

Map<String, Object?> _workerErrorResult(String message, List<String> logs) {
  return {
    _workerEventType: _workerErrorEvent,
    'message': message,
    'logs': logs,
  };
}

int _workerIntValue(Map rawMessage, String key) {
  return (rawMessage[key] as num?)?.toInt() ?? 0;
}

List<String> _workerStringListValue(Map rawMessage, String key) {
  final value = rawMessage[key];
  if (value is! List) {
    return const [];
  }
  return [for (final item in value) item.toString()];
}

ModelVerifyProgressEvent _progressEventFromWorkerMessage(Map rawMessage) {
  final rawStage = rawMessage['stage']?.toString();
  final stage = ModelVerifyProgressStage.values.firstWhere(
    (item) => item.name == rawStage,
    orElse: () => ModelVerifyProgressStage.preparing,
  );
  return ModelVerifyProgressEvent(
    stage: stage,
    message: rawMessage['message']?.toString() ?? stage.label,
    processedFrames: _workerIntValue(rawMessage, 'processedFrames'),
    totalFrames: _workerIntValue(rawMessage, 'totalFrames'),
    currentFramePath: rawMessage['currentFramePath']?.toString() ?? '',
  );
}

String _describeNativeDetectionError(int result, {int? modelInputSize}) {
  return switch (result) {
    -1 => '参数无效',
    -2 => '模型、图片目录或图片文件不存在',
    -3 => '标签输出目录创建或写入失败',
    -11 => 'native_core 未启用 ONNX Runtime',
    -12 => 'ONNX 模型加载失败，可能是模型不兼容或 GPU/CPU Provider 初始化失败',
    -13 => 'ONNX 推理执行失败',
    -14 => '模型输出结构暂不支持',
    -15 => '图片解码失败，通常是图片损坏、格式不受支持或图片解码依赖不可用',
    -16 => 'ONNX 输入结构不支持，请使用 NCHW 格式、3 通道、方形输入的 YOLO ONNX 模型',
    -17 =>
      modelInputSize != null && modelInputSize > 0
          ? 'imgsz 与模型固定输入尺寸不一致，请改为 $modelInputSize'
          : 'imgsz 与模型固定输入尺寸不一致',
    -18 => '无法读取 ONNX 模型输入信息',
    _ => '未知错误',
  };
}

String _requiredWorkerString(Map<String, Object?> message, String key) {
  final value = message[key];
  if (value is String && value.trim().isNotEmpty) {
    return value;
  }
  throw FormatException('模型验证后台任务缺少参数：$key');
}

String _workerOptionalString(Object? value) {
  return value is String ? value.trim() : '';
}

int _requiredWorkerInt(Map<String, Object?> message, String key) {
  final value = message[key];
  if (value is int) {
    return value;
  }
  throw FormatException('模型验证后台任务参数不是整数：$key');
}

double _requiredWorkerDouble(Map<String, Object?> message, String key) {
  final value = message[key];
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('模型验证后台任务参数不是数字：$key');
}

void _sendWorkerLog(SendPort sendPort, String message) {
  sendPort.send({_workerEventType: _workerLogEvent, 'message': message});
}

void _sendWorkerProgress(
  SendPort sendPort, {
  required ModelVerifyProgressStage stage,
  required String message,
  int processedFrames = 0,
  int totalFrames = 0,
  String currentFramePath = '',
}) {
  sendPort.send({
    _workerEventType: _workerProgressEvent,
    'stage': stage.name,
    'message': message,
    'processedFrames': processedFrames,
    'totalFrames': totalFrames,
    'currentFramePath': currentFramePath,
  });
}

void _sendWorkerError(SendPort sendPort, String message) {
  sendPort.send({_workerEventType: _workerErrorEvent, 'message': message});
}
