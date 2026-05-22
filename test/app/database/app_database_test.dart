import 'package:drift/native.dart';
import 'package:flutter_label/app/database/database.dart';
import 'package:flutter_label/app/database/type/history_action_type.dart';
import 'package:flutter_label/app/database/type/run_log_level.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    database = AppDatabase(NativeDatabase.memory());
  });

  tearDown(() async {
    await database.close();
  });

  test('写入历史记录后按创建时间倒序读取', () async {
    await database.addHistoryRecord(
      actionType: HistoryActionType.openFeaturePage,
      title: '进入视频抽帧',
      targetRoute: '/video-extract',
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await database.addHistoryRecord(
      actionType: HistoryActionType.openProjectFile,
      title: '打开项目文件',
      description: 'dataset/project.json',
      payload: 'dataset/project.json',
    );

    final records = await database.watchRecentHistory(limit: 10).first;

    expect(records, hasLength(2));
    expect(records.first.title, '打开项目文件');
    expect(records.last.title, '进入视频抽帧');
  });

  test('空标题会拒绝写入历史记录', () {
    expect(
      () => database.addHistoryRecord(
        actionType: HistoryActionType.openFeaturePage,
        title: ' ',
      ),
      throwsArgumentError,
    );
  });

  test('非法读取数量会拒绝监听历史记录', () {
    expect(() => database.watchRecentHistory(limit: 0), throwsArgumentError);
  });

  test('按 id 删除单条历史记录', () async {
    final firstId = await database.addHistoryRecord(
      actionType: HistoryActionType.openDatasetProject,
      title: '打开数据集项目',
      payload: 'dataset-a',
    );
    final secondId = await database.addHistoryRecord(
      actionType: HistoryActionType.openDatasetProject,
      title: '打开数据集项目',
      payload: 'dataset-b',
    );

    final deletedCount = await database.deleteHistoryRecord(firstId);
    final records = await database.watchRecentHistory(limit: 10).first;

    expect(deletedCount, 1);
    expect(records, hasLength(1));
    expect(records.single.id, secondId);
    expect(records.single.payload, 'dataset-b');
  });

  test('非法历史记录 id 会拒绝删除', () {
    expect(() => database.deleteHistoryRecord(0), throwsArgumentError);
  });

  test('写入运行日志后按创建时间倒序读取', () async {
    await database.addRunLogRecord(
      level: RunLogLevel.error,
      source: '自动预标注',
      message: '模型加载失败',
      details: 'native_core 初始化失败',
    );
    await Future<void>.delayed(const Duration(milliseconds: 2));
    await database.addRunLogRecord(
      level: RunLogLevel.error,
      source: '模型验证',
      message: '图片不存在',
    );

    final records = await database.watchRecentRunLogs(limit: 10).first;

    expect(records, hasLength(2));
    expect(records.first.source, '模型验证');
    expect(records.last.details, 'native_core 初始化失败');
  });

  test('空运行日志来源和消息会被拒绝', () {
    expect(
      () => database.addRunLogRecord(
        level: RunLogLevel.error,
        source: ' ',
        message: '模型加载失败',
      ),
      throwsArgumentError,
    );
    expect(
      () => database.addRunLogRecord(
        level: RunLogLevel.error,
        source: '模型验证',
        message: ' ',
      ),
      throwsArgumentError,
    );
  });

  test('清空运行日志会删除全部记录', () async {
    await database.addRunLogRecord(
      level: RunLogLevel.error,
      source: '系统',
      message: '测试错误',
    );

    await database.clearRunLogs();

    final records = await database.watchRecentRunLogs(limit: 10).first;
    expect(records, isEmpty);
  });

  test('非法读取数量会拒绝监听运行日志', () {
    expect(() => database.watchRecentRunLogs(limit: 0), throwsArgumentError);
  });
}
