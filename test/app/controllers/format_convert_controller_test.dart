import 'dart:async';

import 'package:flutter_label/app/controllers/format_convert_controller.dart';
import 'package:flutter_label/app/models/format_convert_config.dart';
import 'package:flutter_label/app/services/format_convert_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  test('格式转换停止后会忽略迟到结果并恢复运行状态', () async {
    final service = _DelayedFormatConvertService();
    final controller = FormatConvertController(formatConvertService: service)
      ..inputDir.value = 'input'
      ..outputDir.value = 'output'
      ..dataYamlPath.value = 'data.yaml';

    final running = controller.startConvert();
    await service.started.future;

    controller.stopConvert();
    expect(controller.isStopping.value, isTrue);

    service.finish();
    await running;

    expect(service.cancelObserved, isTrue);
    expect(controller.isRunning.value, isFalse);
    expect(controller.isStopping.value, isFalse);
    expect(controller.result.value, isNull);
    expect(controller.errorMessage.value, isNull);
    expect(controller.logs, contains('格式转换已停止。'));
  });
}

class _DelayedFormatConvertService extends FormatConvertService {
  final started = Completer<void>();
  final _finish = Completer<void>();
  bool cancelObserved = false;

  @override
  Future<FormatConvertResult> convert(
    FormatConvertConfig config, {
    FormatConvertCancelChecker? isCancelled,
  }) async {
    if (!started.isCompleted) {
      started.complete();
    }
    await _finish.future;
    if (isCancelled?.call() ?? false) {
      cancelObserved = true;
      throw const FormatConvertCancelledException();
    }
    return const FormatConvertResult(
      convertedCount: 1,
      skippedCount: 0,
      logs: [],
    );
  }

  void finish() {
    if (!_finish.isCompleted) {
      _finish.complete();
    }
  }
}
