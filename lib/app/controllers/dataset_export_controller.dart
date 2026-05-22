import 'package:file_picker/file_picker.dart';
import 'package:get/get.dart';

import '../models/dataset_export_config.dart';
import '../services/app_toast_service.dart';
import '../services/dataset_export_service.dart';

class DatasetExportController extends GetxController {
  DatasetExportController({
    DatasetExportService datasetExportService = const DatasetExportService(),
  }) : _datasetExportService = datasetExportService;

  final DatasetExportService _datasetExportService;

  final projectDir = ''.obs;
  final outputDir = ''.obs;
  final trainRatioText = '80'.obs;
  final valRatioText = '15'.obs;
  final testRatioText = '5'.obs;
  final shuffle = true.obs;
  final includeEmptyLabels = true.obs;
  final createZip = false.obs;
  final isRunning = false.obs;
  final isStopping = false.obs;
  final logs = <String>[].obs;
  final errorMessage = RxnString();
  final result = Rxn<DatasetExportResult>();

  bool _stopRequested = false;

  Future<void> pickProjectDir() async {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '请选择项目目录',
    );
    if (directory != null && directory.trim().isNotEmpty) {
      projectDir.value = directory;
    }
  }

  Future<void> pickOutputDir() async {
    final directory = await FilePicker.platform.getDirectoryPath(
      dialogTitle: '请选择导出目录',
    );
    if (directory != null && directory.trim().isNotEmpty) {
      outputDir.value = directory;
    }
  }

  void setTrainRatio(String value) => trainRatioText.value = value;

  void setValRatio(String value) => valRatioText.value = value;

  void setTestRatio(String value) => testRatioText.value = value;

  Future<void> startExport() async {
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
      ..add('开始导出数据集...');
    try {
      final output = await _datasetExportService.export(
        DatasetExportConfig(
          projectDir: projectDir.value,
          outputDir: outputDir.value,
          trainRatio: _parsePercent(trainRatioText.value, 'train'),
          valRatio: _parsePercent(valRatioText.value, 'val'),
          testRatio: _parsePercent(testRatioText.value, 'test'),
          shuffle: shuffle.value,
          includeEmptyLabels: includeEmptyLabels.value,
          createZip: createZip.value,
        ),
        isCancelled: () => _stopRequested,
      );
      result.value = output;
      logs.addAll(output.logs);
      logs.add('导出完成：共 ${output.exportedCount} 张，跳过 ${output.skippedCount} 张。');
      AppToast.success(
        '导出完成：共 ${output.exportedCount} 张，跳过 ${output.skippedCount} 张',
      );
    } catch (error) {
      if (_stopRequested || error is DatasetExportCancelledException) {
        _markExportStopped();
        return;
      }
      errorMessage.value = error.toString();
      logs.add('导出失败：$error');
      AppToast.error(error, source: '数据集导出');
    } finally {
      isRunning.value = false;
      isStopping.value = false;
      _stopRequested = false;
    }
  }

  void stopExport() {
    if (!isRunning.value || isStopping.value) {
      return;
    }
    _stopRequested = true;
    isStopping.value = true;
    logs.add('正在停止数据集导出...');
  }

  void _markExportStopped() {
    if (!logs.contains('数据集导出已停止。')) {
      logs.add('数据集导出已停止。');
    }
    AppToast.success('已停止数据集导出');
  }

  double _parsePercent(String value, String name) {
    final percent = double.tryParse(value.trim());
    if (percent == null || percent < 0 || percent > 100) {
      throw FormatException('$name 比例必须是 0 到 100 的数字');
    }
    return percent / 100;
  }
}
