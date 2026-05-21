import 'package:get/get.dart';

import '../database/database.dart';
import '../database/type/run_log_level.dart';

/// 统一记录用户可见运行错误；数据库不可用时静默降级，避免日志系统影响主流程。
class AppRunLogService {
  const AppRunLogService({AppDatabase? database}) : _database = database;

  final AppDatabase? _database;

  AppDatabase? get _activeDatabase {
    if (_database != null) {
      return _database;
    }
    if (!Get.isRegistered<AppDatabase>()) {
      return null;
    }
    return Get.find<AppDatabase>();
  }

  Stream<List<RunLogRecord>> watchRecentLogs({
    int limit = AppDatabase.recentRunLogLimit,
  }) {
    final database = _activeDatabase;
    if (database == null) {
      return Stream.value(const <RunLogRecord>[]);
    }
    return database.watchRecentRunLogs(limit: limit);
  }

  Future<void> recordError({
    required String source,
    required Object? message,
    Object? details,
  }) async {
    final database = _activeDatabase;
    if (database == null) {
      return;
    }

    final normalizedMessage = _normalize(message, fallback: '操作失败');
    final normalizedSource = _normalize(source, fallback: '系统');
    final normalizedDetails = details?.toString().trim();
    try {
      await database.addRunLogRecord(
        level: RunLogLevel.error,
        source: normalizedSource,
        message: normalizedMessage,
        details: normalizedDetails == null || normalizedDetails.isEmpty
            ? null
            : normalizedDetails,
      );
    } catch (_) {
      // 错误日志只用于诊断，写入失败不能反向中断用户正在执行的业务流程。
    }
  }

  Future<void> clearLogs() async {
    final database = _activeDatabase;
    if (database == null) {
      return;
    }
    await database.clearRunLogs();
  }

  String _normalize(Object? value, {required String fallback}) {
    final normalized = value?.toString().trim() ?? '';
    return normalized.isEmpty ? fallback : normalized;
  }
}
