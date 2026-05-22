import 'dart:async';

import 'package:flutter_label/app/controllers/dataset_export_controller.dart';
import 'package:flutter_label/app/models/dataset_export_config.dart';
import 'package:flutter_label/app/services/dataset_export_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  test('数据集导出停止后会忽略迟到结果并恢复运行状态', () async {
    final service = _DelayedDatasetExportService();
    final controller = DatasetExportController(datasetExportService: service)
      ..projectDir.value = 'project'
      ..outputDir.value = 'output';

    final running = controller.startExport();
    await service.started.future;

    controller.stopExport();
    expect(controller.isStopping.value, isTrue);

    service.finish();
    await running;

    expect(service.cancelObserved, isTrue);
    expect(controller.isRunning.value, isFalse);
    expect(controller.isStopping.value, isFalse);
    expect(controller.result.value, isNull);
    expect(controller.errorMessage.value, isNull);
    expect(controller.logs, contains('数据集导出已停止。'));
  });
}

class _DelayedDatasetExportService extends DatasetExportService {
  final started = Completer<void>();
  final _finish = Completer<void>();
  bool cancelObserved = false;

  @override
  Future<DatasetExportResult> export(
    DatasetExportConfig config, {
    DatasetExportCancelChecker? isCancelled,
  }) async {
    if (!started.isCompleted) {
      started.complete();
    }
    await _finish.future;
    if (isCancelled?.call() ?? false) {
      cancelObserved = true;
      throw const DatasetExportCancelledException();
    }
    return const DatasetExportResult(
      trainCount: 1,
      valCount: 0,
      testCount: 0,
      skippedCount: 0,
      emptyLabelCount: 0,
      duplicateCount: 0,
      logs: [],
    );
  }

  void finish() {
    if (!_finish.isCompleted) {
      _finish.complete();
    }
  }
}
