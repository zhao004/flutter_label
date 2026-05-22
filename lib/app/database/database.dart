import 'dart:io';

import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import 'tables/history_records.dart';
import 'tables/image_index_records.dart';
import 'tables/run_log_records.dart';
import 'type/history_action_type.dart';
import 'type/run_log_level.dart';

part 'database.g.dart';

@DriftDatabase(tables: [HistoryRecords, RunLogRecords, ImageIndexRecords])
class AppDatabase extends _$AppDatabase {
  static const int recentHistoryLimit = 30;
  static const int recentRunLogLimit = 100;
  static const int _schemaVersion = 4;
  static const String _databaseFileName = 'flutter_label.sqlite';

  AppDatabase([QueryExecutor? executor]) : super(executor ?? _openConnection());

  @override
  int get schemaVersion => _schemaVersion;

  @override
  MigrationStrategy get migration {
    return MigrationStrategy(
      onUpgrade: (migrator, from, to) async {
        if (from < 3) {
          await migrator.createTable(imageIndexRecords);
        }
        if (from < 4) {
          await migrator.createTable(runLogRecords);
        }
      },
    );
  }

  /// 监听最近历史记录，限制数量避免首页长列表造成无意义渲染开销。
  Stream<List<HistoryRecord>> watchRecentHistory({
    int limit = recentHistoryLimit,
  }) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', '历史记录读取数量必须大于 0');
    }

    return (select(historyRecords)
          ..orderBy([
            (record) => OrderingTerm(
              expression: record.createdAt,
              mode: OrderingMode.desc,
            ),
            (record) =>
                OrderingTerm(expression: record.id, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  /// 写入一条历史记录，空标题会直接拒绝，避免产生不可展示的脏数据。
  Future<int> addHistoryRecord({
    required HistoryActionType actionType,
    required String title,
    String? description,
    String? targetRoute,
    String? payload,
  }) {
    final normalizedTitle = _normalizeHistoryTitle(title);

    return into(historyRecords).insert(
      HistoryRecordsCompanion.insert(
        actionType: actionType,
        title: normalizedTitle,
        description: Value(_normalizeNullableText(description)),
        targetRoute: Value(_normalizeNullableText(targetRoute)),
        payload: Value(_normalizeNullableText(payload)),
        createdAt: DateTime.now(),
      ),
    );
  }

  /// 写入或刷新同一目标的历史记录，避免首页重复展示相同项目入口。
  Future<int> upsertHistoryRecord({
    required HistoryActionType actionType,
    required String title,
    String? description,
    String? targetRoute,
    String? payload,
  }) async {
    final normalizedTitle = _normalizeHistoryTitle(title);
    final normalizedDescription = _normalizeNullableText(description);
    final normalizedTargetRoute = _normalizeNullableText(targetRoute);
    final normalizedPayload = _normalizeNullableText(payload);
    final now = DateTime.now();

    final existing =
        await (select(historyRecords)
              ..where(
                (record) =>
                    record.actionType.equals(actionType.name) &
                    _nullableTextEquals(
                      record.targetRoute,
                      normalizedTargetRoute,
                    ) &
                    _nullableTextEquals(record.payload, normalizedPayload),
              )
              ..limit(1))
            .getSingleOrNull();
    if (existing == null) {
      return into(historyRecords).insert(
        HistoryRecordsCompanion.insert(
          actionType: actionType,
          title: normalizedTitle,
          description: Value(normalizedDescription),
          targetRoute: Value(normalizedTargetRoute),
          payload: Value(normalizedPayload),
          createdAt: now,
        ),
      );
    }

    await (update(
      historyRecords,
    )..where((record) => record.id.equals(existing.id))).write(
      HistoryRecordsCompanion(
        title: Value(normalizedTitle),
        description: Value(normalizedDescription),
        targetRoute: Value(normalizedTargetRoute),
        payload: Value(normalizedPayload),
        createdAt: Value(now),
      ),
    );
    return existing.id;
  }

  Future<int> clearHistory() {
    return delete(historyRecords).go();
  }

  /// 删除单条历史记录，调用方必须传入数据库内已有的正整数 id。
  Future<int> deleteHistoryRecord(int id) {
    if (id <= 0) {
      throw ArgumentError.value(id, 'id', '历史记录 id 必须大于 0');
    }

    return (delete(
      historyRecords,
    )..where((record) => record.id.equals(id))).go();
  }

  /// 监听最近运行日志，倒序展示最新错误，避免日志页无限制渲染。
  Stream<List<RunLogRecord>> watchRecentRunLogs({
    int limit = recentRunLogLimit,
  }) {
    if (limit <= 0) {
      throw ArgumentError.value(limit, 'limit', '运行日志读取数量必须大于 0');
    }

    return (select(runLogRecords)
          ..orderBy([
            (record) => OrderingTerm(
              expression: record.createdAt,
              mode: OrderingMode.desc,
            ),
            (record) =>
                OrderingTerm(expression: record.id, mode: OrderingMode.desc),
          ])
          ..limit(limit))
        .watch();
  }

  /// 写入一条运行日志，空来源和空消息会被拒绝，避免日志页出现不可读记录。
  Future<int> addRunLogRecord({
    required RunLogLevel level,
    required String source,
    required String message,
    String? details,
  }) {
    final normalizedSource = source.trim();
    final normalizedMessage = message.trim();
    if (normalizedSource.isEmpty) {
      throw ArgumentError.value(source, 'source', '运行日志来源不能为空');
    }
    if (normalizedMessage.isEmpty) {
      throw ArgumentError.value(message, 'message', '运行日志消息不能为空');
    }

    return into(runLogRecords).insert(
      RunLogRecordsCompanion.insert(
        level: level,
        source: normalizedSource,
        message: normalizedMessage,
        details: Value(_normalizeNullableText(details)),
        createdAt: DateTime.now(),
      ),
    );
  }

  Future<int> clearRunLogs() {
    return delete(runLogRecords).go();
  }

  static String? _normalizeNullableText(String? value) {
    final normalized = value?.trim();
    if (normalized == null || normalized.isEmpty) {
      return null;
    }
    return normalized;
  }

  static String _normalizeHistoryTitle(String title) {
    final normalizedTitle = title.trim();
    if (normalizedTitle.isEmpty) {
      throw ArgumentError.value(title, 'title', '历史记录标题不能为空');
    }
    return normalizedTitle;
  }

  static Expression<bool> _nullableTextEquals(
    Expression<String> expression,
    String? value,
  ) {
    if (value == null) {
      return expression.isNull();
    }
    return expression.equals(value);
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final directory = await getApplicationSupportDirectory();
    if (!await directory.exists()) {
      await directory.create(recursive: true);
    }

    final databaseFile = File(
      path.join(directory.path, AppDatabase._databaseFileName),
    );
    return NativeDatabase.createInBackground(databaseFile);
  });
}
