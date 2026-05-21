import 'package:drift/drift.dart';

import '../type/history_action_type.dart';

/// 存放首页操作历史，按创建时间倒序读取供首页右侧面板展示。
class HistoryRecords extends Table {
  IntColumn get id => integer().autoIncrement()();

  TextColumn get actionType => text().map(const HistoryActionTypeConverter())();

  TextColumn get title => text().withLength(min: 1, max: 80)();

  TextColumn get description => text().nullable()();

  TextColumn get targetRoute => text().nullable()();

  TextColumn get payload => text().nullable()();

  DateTimeColumn get createdAt => dateTime()();
}
