import 'package:drift/drift.dart';

import '../type/run_log_level.dart';

/// 持久化用户可见运行错误，供首页“运行日志”页面统一查看。
class RunLogRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get level => text().map(const RunLogLevelConverter())();

  TextColumn get source => text().withLength(min: 1, max: 80)();

  TextColumn get message => text().withLength(min: 1)();

  TextColumn get details => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}
