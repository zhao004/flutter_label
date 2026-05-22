import 'package:flutter/widgets.dart';
import 'package:flutter_label/app/controllers/run_log_controller.dart';
import 'package:flutter_label/app/database/database.dart';
import 'package:flutter_label/app/database/type/run_log_level.dart';
import 'package:flutter_label/app/pages/run_log/run_log_view.dart';
import 'package:flutter_label/app/services/app_run_log_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/test_app.dart';

void main() {
  late AppRunLogService runLogService;

  setUp(() {
    Get.testMode = true;
    runLogService = _FakeRunLogService(logs: const <RunLogRecord>[]);
    Get.put<AppRunLogService>(runLogService);
    Get.put(RunLogController(runLogService: runLogService));
  });

  tearDown(() async {
    Get.reset();
  });

  testWidgets('运行日志页空态可展示', (tester) async {
    await tester.pumpWidget(buildTestApp(home: const RunLogView()));
    await tester.pump();

    expect(find.text('错误记录'), findsOneWidget);
    expect(find.text('暂无错误日志'), findsOneWidget);
    expect(find.text('清空'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets('运行日志页展示错误来源和详情', (tester) async {
    final fakeRunLogService = _FakeRunLogService(
      logs: [
        RunLogRecord(
          id: 1,
          level: RunLogLevel.error,
          source: '模型验证',
          message: '图片不存在',
          details: 'sourcePath 为空',
          createdAt: DateTime(2026, 5, 19, 21, 30),
        ),
      ],
    );
    Get
      ..replace<AppRunLogService>(fakeRunLogService)
      ..replace(RunLogController(runLogService: fakeRunLogService));

    await tester.pumpWidget(buildTestApp(home: const RunLogView()));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('模型验证'), findsAtLeastNWidgets(1));
    expect(find.text('图片不存在'), findsOneWidget);
    expect(find.text('sourcePath 为空'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });
}

class _FakeRunLogService extends AppRunLogService {
  const _FakeRunLogService({required this.logs});

  final List<RunLogRecord> logs;

  @override
  Stream<List<RunLogRecord>> watchRecentLogs({
    int limit = AppDatabase.recentRunLogLimit,
  }) {
    return Stream<List<RunLogRecord>>.value(logs.take(limit).toList());
  }

  @override
  Future<void> clearLogs() async {}
}
