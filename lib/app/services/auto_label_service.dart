import 'dart:async';
import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:isolate';

import 'package:ffi/ffi.dart';
import 'package:path/path.dart' as p;

import '../models/auto_label_config.dart';
import '../models/dataset_split.dart';
import '../models/detection_result.dart';
import 'data_yaml_service.dart';
import 'native_library_loader.dart';
import 'native_model_lock.dart';

typedef AutoLabelNativeRunner =
    Future<int?> Function(
      AutoLabelConfig config,
      String predictionLabelDir,
      List<String> logs,
    );

typedef _InitModelNative = Int32 Function(Pointer<Utf8>, Int32);
typedef _InitModelDart = int Function(Pointer<Utf8>, int);

typedef _DetectImageNative =
    Pointer<Utf8> Function(Pointer<Utf8>, Float, Float);
typedef _DetectImageDart =
    Pointer<Utf8> Function(Pointer<Utf8>, double, double);

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

const String _workerEventType = 'type';
const String _workerLogEvent = 'log';
const String _workerProgressEvent = 'progress';
const String _workerErrorEvent = 'error';
const String _workerCompletedEvent = 'completed';
const DataYamlService _dataYamlService = DataYamlService();

enum AutoLabelProgressEventType { log, progress, completed }

class AutoLabelProgressEvent {
  const AutoLabelProgressEvent._({
    required this.type,
    this.message,
    this.processedCount = 0,
    this.totalCount = 0,
    this.writtenCount = 0,
    this.mergedCount = 0,
    this.skippedCount = 0,
    this.currentImagePath = '',
    this.currentDetections = const [],
    this.result,
  });

  factory AutoLabelProgressEvent.log(String message) {
    return AutoLabelProgressEvent._(
      type: AutoLabelProgressEventType.log,
      message: message,
    );
  }

  factory AutoLabelProgressEvent.progress({
    required int processedCount,
    required int totalCount,
    required int writtenCount,
    required int mergedCount,
    required int skippedCount,
    required String currentImagePath,
    List<DetectionResult> currentDetections = const [],
  }) {
    return AutoLabelProgressEvent._(
      type: AutoLabelProgressEventType.progress,
      processedCount: processedCount,
      totalCount: totalCount,
      writtenCount: writtenCount,
      mergedCount: mergedCount,
      skippedCount: skippedCount,
      currentImagePath: currentImagePath,
      currentDetections: currentDetections,
    );
  }

  factory AutoLabelProgressEvent.completed(
    AutoLabelResult result, {
    int? processedCount,
    int? totalCount,
  }) {
    final fallbackCount =
        result.writtenCount + result.mergedCount + result.skippedCount;
    return AutoLabelProgressEvent._(
      type: AutoLabelProgressEventType.completed,
      processedCount: processedCount ?? fallbackCount,
      totalCount: totalCount ?? fallbackCount,
      writtenCount: result.writtenCount,
      mergedCount: result.mergedCount,
      skippedCount: result.skippedCount,
      result: result,
    );
  }

  final AutoLabelProgressEventType type;
  final String? message;
  final int processedCount;
  final int totalCount;
  final int writtenCount;
  final int mergedCount;
  final int skippedCount;
  final String currentImagePath;
  final List<DetectionResult> currentDetections;
  final AutoLabelResult? result;

  double get progress {
    if (totalCount <= 0) {
      return 0;
    }
    return (processedCount / totalCount).clamp(0, 1).toDouble();
  }
}

class AutoLabelService {
  const AutoLabelService({AutoLabelNativeRunner? nativeRunner})
    : _nativeRunner = nativeRunner;

  final AutoLabelNativeRunner? _nativeRunner;

  Future<AutoLabelResult> autoLabel(AutoLabelConfig config) async {
    AutoLabelResult? finalResult;
    await for (final event in autoLabelStream(config)) {
      if (event.type == AutoLabelProgressEventType.completed) {
        finalResult = event.result;
      }
    }
    if (finalResult == null) {
      throw StateError('自动预标注未返回执行结果');
    }
    return finalResult;
  }

  /// 根据预测标签和模型类别信息写入目标标签，并同步数据集类别元信息。
  ///
  /// `detectedClassNames` 用于测试或外部 runner 传入模型实际返回的类别名；
  /// native worker 路径会在 isolate 内直接从检测 JSON 汇总同样的信息。

  Stream<AutoLabelProgressEvent> autoLabelStream(AutoLabelConfig config) {
    _validateConfig(config);
    if (_nativeRunner != null) {
      return _autoLabelWithInjectedNativeRunner(config);
    }
    return _autoLabelWithNativeWorker(config);
  }

  Future<AutoLabelResult> applyPredictedLabels({
    required String predictionLabelDir,
    required String targetLabelDir,
    required int classCount,
    required AutoLabelOverwriteStrategy strategy,
    DatasetFolderFilter folderFilter = DatasetFolderFilter.all,
    String dataYamlPath = '',
    List<String>? logs,
    bool usedNative = false,
    Map<int, String> detectedClassNames = const {},
  }) async {
    if (classCount < 0) {
      throw const FormatException('类别数量不能小于 0');
    }
    final normalizedDataYamlPath = _resolveDataYamlPath(
      dataYamlPath: dataYamlPath,
      targetLabelDir: targetLabelDir,
    );
    final sourceDirectory = Directory(predictionLabelDir);
    if (!await sourceDirectory.exists()) {
      throw FileSystemException('预测标签目录不存在', predictionLabelDir);
    }
    await Directory(targetLabelDir).create(recursive: true);

    var writtenCount = 0;
    var skippedCount = 0;
    var mergedCount = 0;
    final resultLogs = logs ?? <String>[];
    final detectedClasses = _DetectedClassInfo();
    detectedClasses.addNames(detectedClassNames);
    final files = await sourceDirectory
        .list(recursive: true, followLinks: false)
        .where((entity) => entity is File)
        .cast<File>()
        .where((file) => p.extension(file.path).toLowerCase() == '.txt')
        .toList();
    files.sort((left, right) => left.path.compareTo(right.path));

    for (final sourceFile in files) {
      final relativePath = p.relative(
        sourceFile.path,
        from: predictionLabelDir,
      );
      if (!folderFilter.matchesRelativePath(relativePath)) {
        continue;
      }
      final targetFile = File(p.join(targetLabelDir, relativePath));
      final predictedLines = await _readNormalizedLabelLines(sourceFile);
      if (predictedLines.isEmpty) {
        continue;
      }

      final targetExists = await targetFile.exists();
      if (strategy == AutoLabelOverwriteStrategy.skipExisting && targetExists) {
        skippedCount++;
        continue;
      }

      await targetFile.parent.create(recursive: true);
      if (strategy == AutoLabelOverwriteStrategy.mergeExisting &&
          targetExists) {
        final existingLines = await _readNormalizedLabelLines(targetFile);
        final merged = {...existingLines, ...predictedLines}.toList();
        await targetFile.writeAsString(merged.join('\n'));
        detectedClasses.addYoloLines(merged);
        mergedCount++;
      } else {
        await targetFile.writeAsString(predictedLines.join('\n'));
        detectedClasses.addYoloLines(predictedLines);
        writtenCount++;
      }
    }

    final updatedClassNames = _resolveClassNames(
      existingNames: await _readClassNamesIfAvailable(normalizedDataYamlPath),
      currentClassCount: classCount,
      detectedClasses: detectedClasses,
    );
    final didWriteMetadata = await _writeClassMetadata(
      dataYamlPath: normalizedDataYamlPath,
      classNames: updatedClassNames,
    );
    if (didWriteMetadata) {
      resultLogs.add('已同步类别信息到 data.yaml。');
    }
    resultLogs.add('标签应用完成：写入 $writtenCount，合并 $mergedCount，跳过 $skippedCount。');
    return AutoLabelResult(
      writtenCount: writtenCount,
      skippedCount: skippedCount,
      mergedCount: mergedCount,
      logs: resultLogs,
      usedNative: usedNative,
      classCount: updatedClassNames.length,
    );
  }

  Stream<AutoLabelProgressEvent> _autoLabelWithInjectedNativeRunner(
    AutoLabelConfig config,
  ) async* {
    final logs = <String>[];
    var emittedLogCount = 0;
    final tempRoot = await Directory.systemTemp.createTemp(
      'flutter_label_auto_label_',
    );
    final predictionLabelDir = p.join(tempRoot.path, 'labels');

    try {
      final nativeResult = await _nativeRunner!(
        config,
        predictionLabelDir,
        logs,
      );
      for (final message in logs.skip(emittedLogCount)) {
        yield AutoLabelProgressEvent.log(message);
      }
      emittedLogCount = logs.length;
      if (nativeResult != 0) {
        throw StateError(_nativeFailureMessage(nativeResult, logs));
      }

      final result = await applyPredictedLabels(
        predictionLabelDir: predictionLabelDir,
        targetLabelDir: config.labelDir,
        classCount: config.classCount,
        strategy: config.strategy,
        folderFilter: config.folderFilter,
        dataYamlPath: config.dataYamlPath,
        logs: logs,
        usedNative: true,
      );
      for (final message in logs.skip(emittedLogCount)) {
        yield AutoLabelProgressEvent.log(message);
      }
      yield AutoLabelProgressEvent.progress(
        processedCount:
            result.writtenCount + result.mergedCount + result.skippedCount,
        totalCount:
            result.writtenCount + result.mergedCount + result.skippedCount,
        writtenCount: result.writtenCount,
        mergedCount: result.mergedCount,
        skippedCount: result.skippedCount,
        currentImagePath: '',
      );
      yield AutoLabelProgressEvent.completed(result);
    } finally {
      if (await tempRoot.exists()) {
        await tempRoot.delete(recursive: true);
      }
    }
  }

  Stream<AutoLabelProgressEvent> _autoLabelWithNativeWorker(
    AutoLabelConfig config,
  ) {
    final controller = StreamController<AutoLabelProgressEvent>();
    ReceivePort? receivePort;
    Isolate? worker;
    var cancelled = false;

    controller.onListen = () {
      unawaited(
        NativeModelLock.run(() async {
          receivePort = ReceivePort();
          try {
            worker = await Isolate.spawn(_runNativeAutoLabelWorker, {
              'sendPort': receivePort!.sendPort,
              'nativeLibraryPath': _nativeLibraryPath(),
              'modelPath': config.modelPath,
              'imageDir': config.imageDir,
              'labelDir': config.labelDir,
              'imgsz': config.imgsz,
              'conf': config.conf,
              'iou': config.iou,
              'classCount': config.classCount,
              'strategy': config.strategy.name,
              'folderFilter': config.folderFilter.name,
              'dataYamlPath': config.dataYamlPath,
            });
            await for (final rawMessage in receivePort!) {
              if (cancelled) {
                break;
              }
              if (rawMessage is! Map) {
                continue;
              }
              final type = rawMessage[_workerEventType]?.toString();
              if (type == _workerLogEvent) {
                final message = rawMessage['message']?.toString() ?? '';
                if (message.isNotEmpty && !controller.isClosed) {
                  controller.add(AutoLabelProgressEvent.log(message));
                }
                continue;
              }
              if (type == _workerProgressEvent) {
                if (!controller.isClosed) {
                  controller.add(
                    AutoLabelProgressEvent.progress(
                      processedCount: _workerIntValue(
                        rawMessage,
                        'processedCount',
                      ),
                      totalCount: _workerIntValue(rawMessage, 'totalCount'),
                      writtenCount: _workerIntValue(rawMessage, 'writtenCount'),
                      mergedCount: _workerIntValue(rawMessage, 'mergedCount'),
                      skippedCount: _workerIntValue(rawMessage, 'skippedCount'),
                      currentImagePath:
                          rawMessage['currentImagePath']?.toString() ?? '',
                      currentDetections: _workerDetectionListValue(
                        rawMessage,
                        'currentDetections',
                      ),
                    ),
                  );
                }
                continue;
              }
              if (type == _workerErrorEvent) {
                throw StateError(
                  rawMessage['message']?.toString() ?? '自动预标注失败',
                );
              }
              if (type == _workerCompletedEvent) {
                final result = AutoLabelResult(
                  writtenCount: _workerIntValue(rawMessage, 'writtenCount'),
                  skippedCount: _workerIntValue(rawMessage, 'skippedCount'),
                  mergedCount: _workerIntValue(rawMessage, 'mergedCount'),
                  logs: _workerStringListValue(rawMessage, 'logs'),
                  usedNative: true,
                  classCount: _workerIntValue(rawMessage, 'classCount'),
                );
                if (!controller.isClosed) {
                  controller.add(
                    AutoLabelProgressEvent.completed(
                      result,
                      processedCount: _workerIntValue(
                        rawMessage,
                        'processedCount',
                      ),
                      totalCount: _workerIntValue(rawMessage, 'totalCount'),
                    ),
                  );
                }
                break;
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

  String _nativeFailureMessage(int? nativeResult, List<String> logs) {
    final reason = nativeResult == null
        ? 'native_core 动态库不可用'
        : 'native_core 批量预标注失败，错误码：$nativeResult（${_describeNativeDetectionError(nativeResult)}）';
    final details = logs.isEmpty ? '' : '\n${logs.join('\n')}';
    return '$reason。自动预标注必须通过 Dart FFI + native_core + ONNX Runtime 执行，'
        '请确认 native_core.dll 与 onnxruntime.dll 已安装到应用 lib 目录，'
        '模型为受支持的 YOLO ONNX 格式。$details';
  }

  Future<List<String>> _readNormalizedLabelLines(File file) async {
    final result = <String>[];
    final lines = await file.readAsLines();
    for (final line in lines) {
      final normalized = _normalizeYoloLabelLine(line);
      if (normalized != null) {
        result.add(normalized);
      }
    }
    return result;
  }

  String _nativeLibraryPath() {
    return nativeCoreLibraryPath();
  }

  void _validateConfig(AutoLabelConfig config) {
    if (!File(config.modelPath).existsSync()) {
      throw FileSystemException('模型文件不存在', config.modelPath);
    }
    if (p.extension(config.modelPath).toLowerCase() != '.onnx') {
      throw const FormatException('当前阶段仅支持 ONNX 模型文件');
    }
    if (!Directory(config.imageDir).existsSync()) {
      throw FileSystemException('图片目录不存在', config.imageDir);
    }
    if (config.labelDir.trim().isEmpty) {
      throw const FormatException('标签输出目录不能为空');
    }
    if (config.classCount < 0) {
      throw const FormatException('类别数量不能小于 0');
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
  }
}

void _runNativeAutoLabelWorker(Map<String, Object?> message) {
  final sendPort = message['sendPort'];
  if (sendPort is! SendPort) {
    return;
  }

  DynamicLibrary? library;
  var initialized = false;
  final logs = <String>[];
  try {
    final nativeLibraryPath = _requiredWorkerString(
      message,
      'nativeLibraryPath',
    );
    final modelPath = _requiredWorkerString(message, 'modelPath');
    final imageDir = _requiredWorkerString(message, 'imageDir');
    final labelDir = _requiredWorkerString(message, 'labelDir');
    final dataYamlPath = _resolveDataYamlPath(
      dataYamlPath: _workerOptionalString(message['dataYamlPath']),
      targetLabelDir: labelDir,
    );
    final imgsz = _requiredWorkerInt(message, 'imgsz');
    final conf = _requiredWorkerDouble(message, 'conf');
    final iou = _requiredWorkerDouble(message, 'iou');
    final classCount = _requiredWorkerInt(message, 'classCount');
    final strategy = _requiredWorkerString(message, 'strategy');
    final folderFilter = _workerFolderFilter(message['folderFilter']);

    library = DynamicLibrary.open(nativeLibraryPath);
    _sendWorkerLog(sendPort, logs, 'native_core 自动预标注后台任务已启动。');

    final imagePaths = _listAutoLabelImagePathsSync(imageDir, folderFilter);
    final totalCount = imagePaths.length;
    if (totalCount == 0) {
      _sendWorkerLog(sendPort, logs, '图片目录中没有找到可预标注的图片。');
      _sendWorkerCompleted(
        sendPort,
        logs,
        processed: 0,
        total: 0,
        written: 0,
        merged: 0,
        skipped: 0,
        classCount: classCount,
      );
      return;
    }

    final initModel = library.lookupFunction<_InitModelNative, _InitModelDart>(
      'init_model',
    );
    final detectImage = library
        .lookupFunction<_DetectImageNative, _DetectImageDart>('detect_image');
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
      _sendWorkerLog(
        sendPort,
        logs,
        'native_core 模型输入尺寸：${modelInputSize}x$modelInputSize。',
      );
    }
    _sendWorkerLog(
      sendPort,
      logs,
      'native_core 推理 Provider：${_readNativeModelProvider(getModelProvider: getModelProvider, freeString: freeString)}。',
    );

    var writtenCount = 0;
    var mergedCount = 0;
    var skippedCount = 0;
    var processedCount = 0;
    final detectedClasses = _DetectedClassInfo();
    var currentClassNames = _readClassNamesIfAvailableSync(dataYamlPath);
    var didWriteMetadataDuringRun = false;

    for (final imagePath in imagePaths) {
      final labelPath = _targetLabelPath(
        imagePath: imagePath,
        imageDir: imageDir,
        labelDir: labelDir,
      );
      final targetFile = File(labelPath);
      if (strategy == AutoLabelOverwriteStrategy.skipExisting.name &&
          targetFile.existsSync()) {
        skippedCount++;
        processedCount++;
        _sendWorkerProgress(
          sendPort,
          processed: processedCount,
          total: totalCount,
          written: writtenCount,
          merged: mergedCount,
          skipped: skippedCount,
          currentImagePath: imagePath,
        );
        continue;
      }

      final json = _detectImageJson(
        detectImage: detectImage,
        freeString: freeString,
        getLastErrorCode: getLastErrorCode,
        sendPort: sendPort,
        imagePath: imagePath,
        conf: conf,
        iou: iou,
      );
      if (json == null) {
        return;
      }

      final predictedLines = _detectionJsonToYoloLines(json);
      final currentDetections = _detectionJsonToResults(json);
      if (predictedLines.isNotEmpty) {
        detectedClasses.addDetections(currentDetections);
        targetFile.parent.createSync(recursive: true);
        if (strategy == AutoLabelOverwriteStrategy.mergeExisting.name &&
            targetFile.existsSync()) {
          final existingLines = _readNormalizedLabelLinesSync(targetFile);
          final mergedLines = {...existingLines, ...predictedLines}.toList();
          targetFile.writeAsStringSync(mergedLines.join('\n'));
          detectedClasses.addYoloLines(mergedLines);
          mergedCount++;
        } else {
          targetFile.writeAsStringSync(predictedLines.join('\n'));
          detectedClasses.addYoloLines(predictedLines);
          writtenCount++;
        }
        final syncResult = _syncDetectedClassMetadataSync(
          dataYamlPath: dataYamlPath,
          currentClassNames: currentClassNames,
          currentClassCount: classCount,
          detectedClasses: detectedClasses,
        );
        currentClassNames = syncResult.classNames;
        didWriteMetadataDuringRun =
            didWriteMetadataDuringRun || syncResult.didWrite;
      }

      processedCount++;
      _sendWorkerProgress(
        sendPort,
        processed: processedCount,
        total: totalCount,
        written: writtenCount,
        merged: mergedCount,
        skipped: skippedCount,
        currentImagePath: imagePath,
        currentDetections: currentDetections,
      );
    }

    final finalSyncResult = _syncDetectedClassMetadataSync(
      dataYamlPath: dataYamlPath,
      currentClassNames: currentClassNames,
      currentClassCount: classCount,
      detectedClasses: detectedClasses,
    );
    currentClassNames = finalSyncResult.classNames;
    if (didWriteMetadataDuringRun || finalSyncResult.didWrite) {
      _sendWorkerLog(sendPort, logs, '已同步类别信息到 data.yaml。');
    }
    _sendWorkerLog(
      sendPort,
      logs,
      '标签应用完成：写入 $writtenCount，合并 $mergedCount，跳过 $skippedCount。',
    );
    _sendWorkerCompleted(
      sendPort,
      logs,
      processed: processedCount,
      total: totalCount,
      written: writtenCount,
      merged: mergedCount,
      skipped: skippedCount,
      classCount: currentClassNames.length,
    );
  } catch (error) {
    _sendWorkerError(sendPort, '自动预标注后台任务失败：$error');
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

String? _detectImageJson({
  required _DetectImageDart detectImage,
  required _FreeStringDart freeString,
  required _GetLastErrorCodeDart getLastErrorCode,
  required SendPort sendPort,
  required String imagePath,
  required double conf,
  required double iou,
}) {
  final nativeImagePath = imagePath.toNativeUtf8();
  Pointer<Utf8> jsonPointer = nullptr;
  try {
    jsonPointer = detectImage(nativeImagePath, conf, iou);
    if (jsonPointer == nullptr) {
      final errorCode = getLastErrorCode();
      _sendWorkerError(
        sendPort,
        'native_core 图片检测失败，错误码：$errorCode（${_describeNativeDetectionError(errorCode)}），图片：$imagePath',
      );
      return null;
    }
    try {
      return jsonPointer.toDartString();
    } finally {
      freeString(jsonPointer);
    }
  } finally {
    malloc.free(nativeImagePath);
  }
}

List<String> _listAutoLabelImagePathsSync(
  String directory,
  DatasetFolderFilter folderFilter,
) {
  final paths = Directory(directory)
      .listSync(recursive: true, followLinks: false)
      .whereType<File>()
      .map((file) => file.path)
      .where((path) => _isSupportedImagePath(path))
      .where((path) {
        final relativePath = p.relative(path, from: directory);
        return folderFilter.matchesRelativePath(relativePath);
      })
      .toList();
  paths.sort();
  return paths;
}

bool _isSupportedImagePath(String path) {
  return {
    '.jpg',
    '.jpeg',
    '.png',
    '.bmp',
    '.webp',
  }.contains(p.extension(path).toLowerCase());
}

String _targetLabelPath({
  required String imagePath,
  required String imageDir,
  required String labelDir,
}) {
  final relativePath = p.relative(imagePath, from: imageDir);
  return p.join(labelDir, p.setExtension(relativePath, '.txt'));
}

List<String> _detectionJsonToYoloLines(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! List) {
    return const [];
  }
  final lines = <String>[];
  for (final item in decoded) {
    if (item is! Map) {
      continue;
    }
    final classId = (item['class_id'] as num?)?.toInt();
    final left = (item['x'] as num?)?.toDouble();
    final top = (item['y'] as num?)?.toDouble();
    final width = (item['w'] as num?)?.toDouble();
    final height = (item['h'] as num?)?.toDouble();
    final imageWidth = (item['image_width'] as num?)?.toDouble();
    final imageHeight = (item['image_height'] as num?)?.toDouble();
    if (classId == null ||
        classId < 0 ||
        left == null ||
        top == null ||
        width == null ||
        height == null ||
        imageWidth == null ||
        imageHeight == null ||
        imageWidth <= 0 ||
        imageHeight <= 0 ||
        width <= 0 ||
        height <= 0) {
      continue;
    }
    final centerX = _clamp01((left + width * 0.5) / imageWidth);
    final centerY = _clamp01((top + height * 0.5) / imageHeight);
    final normalizedWidth = _clamp01(width / imageWidth);
    final normalizedHeight = _clamp01(height / imageHeight);
    if (normalizedWidth == 0 || normalizedHeight == 0) {
      continue;
    }
    lines.add(
      [
        classId.toString(),
        centerX.toStringAsFixed(6),
        centerY.toStringAsFixed(6),
        normalizedWidth.toStringAsFixed(6),
        normalizedHeight.toStringAsFixed(6),
      ].join(' '),
    );
  }
  return lines;
}

List<DetectionResult> _detectionJsonToResults(String json) {
  final decoded = jsonDecode(json);
  if (decoded is! List) {
    return const [];
  }
  final detections = <DetectionResult>[];
  for (final item in decoded) {
    if (item is! Map) {
      continue;
    }
    final classId = (item['class_id'] as num?)?.toInt();
    final left = (item['x'] as num?)?.toDouble();
    final top = (item['y'] as num?)?.toDouble();
    final width = (item['w'] as num?)?.toDouble();
    final height = (item['h'] as num?)?.toDouble();
    if (classId == null ||
        classId < 0 ||
        left == null ||
        top == null ||
        width == null ||
        height == null ||
        width <= 0 ||
        height <= 0) {
      continue;
    }
    detections.add(
      DetectionResult(
        classId: classId,
        className: item['class_name']?.toString() ?? classId.toString(),
        confidence: (item['confidence'] as num?)?.toDouble() ?? 0,
        left: left,
        top: top,
        width: width,
        height: height,
      ),
    );
  }
  return detections;
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

List<String> _readNormalizedLabelLinesSync(File file) {
  if (!file.existsSync()) {
    return const [];
  }
  final result = <String>[];
  for (final line in file.readAsLinesSync()) {
    final normalized = _normalizeYoloLabelLine(line);
    if (normalized != null) {
      result.add(normalized);
    }
  }
  return result;
}

String? _normalizeYoloLabelLine(String line, {int? classCount}) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length < 5) {
    return null;
  }
  final classId = int.tryParse(parts[0]);
  if (classId == null || classId < 0) {
    return null;
  }
  if (classCount != null && classId >= classCount) {
    return null;
  }
  final coords = parts.skip(1).take(4).map(double.tryParse).toList();
  if (coords.any((value) => value == null || value < 0 || value > 1)) {
    return null;
  }
  if (coords[2] == 0 || coords[3] == 0) {
    return null;
  }
  return [
    classId.toString(),
    for (final value in coords) value!.toStringAsFixed(6),
  ].join(' ');
}

double _clamp01(double value) => value.clamp(0, 1).toDouble();

class _DetectedClassInfo {
  _DetectedClassInfo();

  final Map<int, String> namesById = <int, String>{};

  int get maxClassId {
    if (namesById.isEmpty) {
      return -1;
    }
    return namesById.keys.reduce((left, right) => left > right ? left : right);
  }

  void addDetections(Iterable<DetectionResult> detections) {
    for (final detection in detections) {
      add(detection.classId, detection.className);
    }
  }

  void addNames(Map<int, String> names) {
    for (final entry in names.entries) {
      add(entry.key, entry.value);
    }
  }

  void addYoloLines(Iterable<String> lines) {
    for (final line in lines) {
      final classId = _classIdFromYoloLine(line);
      if (classId != null) {
        add(classId, null);
      }
    }
  }

  void add(int classId, String? className) {
    if (classId < 0) {
      return;
    }
    final normalized = _normalizeDetectedClassName(classId, className);
    final existing = namesById[classId];
    if (existing == null || _isFallbackClassName(classId, existing)) {
      namesById[classId] = normalized;
      return;
    }
    if (!_isFallbackClassName(classId, normalized)) {
      namesById[classId] = normalized;
    }
  }
}

Future<List<String>> _readClassNamesIfAvailable(String dataYamlPath) async {
  final path = dataYamlPath.trim();
  if (path.isEmpty) {
    return const [];
  }
  final file = File(path);
  if (!await file.exists()) {
    return const [];
  }
  return _dataYamlService.readClassNames(path);
}

List<String> _readClassNamesIfAvailableSync(String dataYamlPath) {
  final path = dataYamlPath.trim();
  if (path.isEmpty) {
    return const [];
  }
  final file = File(path);
  if (!file.existsSync()) {
    return const [];
  }
  return _dataYamlService.readClassNamesSync(path);
}

bool _writeClassMetadataSync({
  required String dataYamlPath,
  required List<String> classNames,
}) {
  final path = dataYamlPath.trim();
  if (path.isEmpty) {
    return false;
  }
  _dataYamlService.writeClassesSync(dataYamlPath: path, classNames: classNames);
  return true;
}

({List<String> classNames, bool didWrite}) _syncDetectedClassMetadataSync({
  required String dataYamlPath,
  required List<String> currentClassNames,
  required int currentClassCount,
  required _DetectedClassInfo detectedClasses,
}) {
  final updatedClassNames = _resolveClassNames(
    existingNames: currentClassNames,
    currentClassCount: currentClassCount,
    detectedClasses: detectedClasses,
  );
  final metadataFileMissing =
      dataYamlPath.trim().isNotEmpty && !File(dataYamlPath.trim()).existsSync();
  if (!metadataFileMissing &&
      _sameClassNames(currentClassNames, updatedClassNames)) {
    return (classNames: currentClassNames, didWrite: false);
  }
  final didWrite = _writeClassMetadataSync(
    dataYamlPath: dataYamlPath,
    classNames: updatedClassNames,
  );
  return (classNames: updatedClassNames, didWrite: didWrite);
}

bool _sameClassNames(List<String> left, List<String> right) {
  if (left.length != right.length) {
    return false;
  }
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) {
      return false;
    }
  }
  return true;
}

Future<bool> _writeClassMetadata({
  required String dataYamlPath,
  required List<String> classNames,
}) async {
  final path = dataYamlPath.trim();
  if (path.isEmpty) {
    return false;
  }
  await _dataYamlService.writeClasses(
    dataYamlPath: path,
    classNames: classNames,
  );
  return true;
}

List<String> _resolveClassNames({
  required List<String> existingNames,
  required int currentClassCount,
  required _DetectedClassInfo detectedClasses,
}) {
  final targetCount = _resolvedClassCount(
    currentClassCount > existingNames.length
        ? currentClassCount
        : existingNames.length,
    detectedClasses,
  );
  final nextNames = <String>[];
  for (var classId = 0; classId < targetCount; classId++) {
    final detectedName = detectedClasses.namesById[classId];
    if (detectedName != null && !_isFallbackClassName(classId, detectedName)) {
      nextNames.add(detectedName);
      continue;
    }
    if (classId < existingNames.length &&
        existingNames[classId].trim().isNotEmpty) {
      nextNames.add(existingNames[classId]);
      continue;
    }
    nextNames.add(detectedName ?? _fallbackClassName(classId));
  }
  return nextNames;
}

String _resolveDataYamlPath({
  required String dataYamlPath,
  required String targetLabelDir,
}) {
  final normalized = dataYamlPath.trim();
  if (normalized.isNotEmpty) {
    return normalized;
  }
  final labelDir = targetLabelDir.trim();
  if (labelDir.isEmpty) {
    return '';
  }
  final normalizedLabelDir = p.normalize(labelDir);
  if (p.basename(normalizedLabelDir).toLowerCase() != 'labels') {
    return '';
  }
  return p.join(p.dirname(normalizedLabelDir), 'data.yaml');
}

int _resolvedClassCount(
  int currentClassCount,
  _DetectedClassInfo detectedClasses,
) {
  final detectedCount = detectedClasses.maxClassId + 1;
  return currentClassCount > detectedCount ? currentClassCount : detectedCount;
}

String _normalizeDetectedClassName(int classId, String? className) {
  final normalized = className?.trim();
  if (normalized == null ||
      normalized.isEmpty ||
      normalized == classId.toString()) {
    return _fallbackClassName(classId);
  }
  return normalized;
}

String _fallbackClassName(int classId) => 'class_$classId';

bool _isFallbackClassName(int classId, String className) {
  final normalized = className.trim();
  return normalized.isEmpty ||
      normalized == classId.toString() ||
      normalized == _fallbackClassName(classId);
}

int? _classIdFromYoloLine(String line) {
  final trimmed = line.trim();
  if (trimmed.isEmpty) {
    return null;
  }
  final firstPart = trimmed.split(RegExp(r'\s+')).first;
  final classId = int.tryParse(firstPart);
  if (classId == null || classId < 0) {
    return null;
  }
  return classId;
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
  throw FormatException('自动预标注后台任务缺少参数：$key');
}

int _requiredWorkerInt(Map<String, Object?> message, String key) {
  final value = message[key];
  if (value is int) {
    return value;
  }
  throw FormatException('自动预标注后台任务参数不是整数：$key');
}

DatasetFolderFilter _workerFolderFilter(Object? value) {
  final raw = value?.toString();
  if (raw == null || raw.isEmpty) {
    return DatasetFolderFilter.all;
  }
  return DatasetFolderFilter.values.firstWhere(
    (filter) => filter.name == raw,
    orElse: () => DatasetFolderFilter.all,
  );
}

String _workerOptionalString(Object? value) {
  return value is String ? value.trim() : '';
}

double _requiredWorkerDouble(Map<String, Object?> message, String key) {
  final value = message[key];
  if (value is num) {
    return value.toDouble();
  }
  throw FormatException('自动预标注后台任务参数不是数字：$key');
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

List<DetectionResult> _workerDetectionListValue(Map rawMessage, String key) {
  final value = rawMessage[key];
  if (value is! List) {
    return const [];
  }
  final detections = <DetectionResult>[];
  for (final item in value) {
    if (item is! Map) {
      continue;
    }
    final classId = (item['classId'] as num?)?.toInt();
    final confidence = (item['confidence'] as num?)?.toDouble();
    final left = (item['left'] as num?)?.toDouble();
    final top = (item['top'] as num?)?.toDouble();
    final width = (item['width'] as num?)?.toDouble();
    final height = (item['height'] as num?)?.toDouble();
    if (classId == null ||
        confidence == null ||
        left == null ||
        top == null ||
        width == null ||
        height == null ||
        width <= 0 ||
        height <= 0) {
      continue;
    }
    detections.add(
      DetectionResult(
        classId: classId,
        className: item['className']?.toString() ?? classId.toString(),
        confidence: confidence,
        left: left,
        top: top,
        width: width,
        height: height,
      ),
    );
  }
  return detections;
}

Map<String, Object> _detectionToWorkerMap(DetectionResult detection) {
  return {
    'classId': detection.classId,
    'className': detection.className,
    'confidence': detection.confidence,
    'left': detection.left,
    'top': detection.top,
    'width': detection.width,
    'height': detection.height,
  };
}

void _sendWorkerLog(SendPort sendPort, List<String> logs, String message) {
  logs.add(message);
  sendPort.send({_workerEventType: _workerLogEvent, 'message': message});
}

void _sendWorkerProgress(
  SendPort sendPort, {
  required int processed,
  required int total,
  required int written,
  required int merged,
  required int skipped,
  required String currentImagePath,
  List<DetectionResult> currentDetections = const [],
}) {
  sendPort.send({
    _workerEventType: _workerProgressEvent,
    'processedCount': processed,
    'totalCount': total,
    'writtenCount': written,
    'mergedCount': merged,
    'skippedCount': skipped,
    'currentImagePath': currentImagePath,
    'currentDetections': [
      for (final detection in currentDetections)
        _detectionToWorkerMap(detection),
    ],
  });
}

void _sendWorkerError(SendPort sendPort, String message) {
  sendPort.send({_workerEventType: _workerErrorEvent, 'message': message});
}

void _sendWorkerCompleted(
  SendPort sendPort,
  List<String> logs, {
  required int processed,
  required int total,
  required int written,
  required int merged,
  required int skipped,
  required int classCount,
}) {
  sendPort.send({
    _workerEventType: _workerCompletedEvent,
    'processedCount': processed,
    'totalCount': total,
    'writtenCount': written,
    'mergedCount': merged,
    'skippedCount': skipped,
    'classCount': classCount,
    'logs': logs,
  });
}
