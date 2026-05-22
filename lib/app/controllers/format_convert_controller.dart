import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import '../models/format_convert_config.dart';
import '../services/app_toast_service.dart';
import '../services/format_convert_service.dart';

class FormatConvertController extends GetxController {
  FormatConvertController({
    FormatConvertService formatConvertService = const FormatConvertService(),
  }) : _formatConvertService = formatConvertService;

  final FormatConvertService _formatConvertService;

  final inputFormat = AnnotationFormat.yolo.obs;
  final outputFormat = AnnotationFormat.coco.obs;
  final inputDir = ''.obs;
  final outputDir = ''.obs;
  final dataYamlPath = ''.obs;
  final isRunning = false.obs;
  final isStopping = false.obs;
  final logs = <String>[].obs;
  final errorMessage = RxnString();
  final result = Rxn<FormatConvertResult>();

  bool _stopRequested = false;

  void setInputFormat(AnnotationFormat format) {
    inputFormat.value = format;
    if (outputFormat.value == format) {
      outputFormat.value = _firstDifferentFormat(format);
    }
  }

  void setOutputFormat(AnnotationFormat format) {
    outputFormat.value = format;
    if (inputFormat.value == format) {
      inputFormat.value = _firstDifferentFormat(format);
    }
  }

  Future<void> pickInputDir() async {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '请选择输入目录',
    );
    if (directory != null && directory.trim().isNotEmpty) {
      inputDir.value = directory;
    }
  }

  Future<void> pickOutputDir() async {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '请选择输出目录',
    );
    if (directory != null && directory.trim().isNotEmpty) {
      outputDir.value = directory;
    }
  }

  Future<void> pickDataYamlFile() async {
    final picked = await FilePicker.platform.pickFiles(
      dialogTitle: '请选择 data.yaml',
      type: FileType.custom,
      allowedExtensions: ['yaml', 'yml'],
      allowMultiple: false,
    );
    final path = picked?.files.single.path;
    if (path != null && path.trim().isNotEmpty) {
      dataYamlPath.value = path;
    }
  }

  Future<void> startConvert() async {
    if (isRunning.value) {
      return;
    }

    isRunning.value = true;
    isStopping.value = false;
    _stopRequested = false;
    errorMessage.value = null;
    result.value = null;
    logs
      ..clear()
      ..add('开始格式转换...');
    try {
      final output = await _formatConvertService.convert(
        FormatConvertConfig(
          inputFormat: inputFormat.value,
          outputFormat: outputFormat.value,
          inputDir: inputDir.value,
          outputDir: outputDir.value,
          dataYamlPath: dataYamlPath.value,
        ),
        isCancelled: () => _stopRequested,
      );
      result.value = output;
      logs.addAll(output.logs);
      logs.add('转换完成：成功 ${output.convertedCount}，跳过 ${output.skippedCount}。');
      AppToast.success(
        '转换完成：成功 ${output.convertedCount}，跳过 ${output.skippedCount}',
      );
    } catch (error) {
      if (_stopRequested || error is FormatConvertCancelledException) {
        _markConvertStopped();
        return;
      }
      errorMessage.value = error.toString();
      logs.add('转换失败：$error');
      AppToast.error(error, source: '格式转换');
    } finally {
      isRunning.value = false;
      isStopping.value = false;
      _stopRequested = false;
    }
  }

  void stopConvert() {
    if (!isRunning.value || isStopping.value) {
      return;
    }
    _stopRequested = true;
    isStopping.value = true;
    logs.add('正在停止格式转换...');
  }

  void _markConvertStopped() {
    if (!logs.contains('格式转换已停止。')) {
      logs.add('格式转换已停止。');
    }
    AppToast.success('已停止格式转换');
  }

  AnnotationFormat _firstDifferentFormat(AnnotationFormat format) {
    return AnnotationFormat.values.firstWhere((item) => item != format);
  }
}
