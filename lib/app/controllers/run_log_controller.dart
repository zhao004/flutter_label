import 'package:get/get.dart';

import '../database/database.dart';
import '../services/app_run_log_service.dart';
import '../services/app_toast_service.dart';

class RunLogController extends GetxController {
  RunLogController({AppRunLogService? runLogService})
    : _runLogService = runLogService ?? Get.find<AppRunLogService>();

  static const int _logLimit = 200;

  final AppRunLogService _runLogService;

  Stream<List<RunLogRecord>> get logsStream {
    return _runLogService.watchRecentLogs(limit: _logLimit);
  }

  Future<void> clearLogs() async {
    try {
      await _runLogService.clearLogs();
      AppToast.success('运行日志已清空');
    } catch (error) {
      AppToast.error(error, source: '运行日志', details: '清空运行日志失败');
    }
  }
}
