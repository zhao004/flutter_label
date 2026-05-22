import 'dart:io';

import 'package:drift/drift.dart' show OrderingMode, OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_label/app/database/database.dart';
import 'package:flutter_label/app/database/type/history_action_type.dart';
import 'package:flutter_label/app/pages/home/home_controller.dart';
import 'package:flutter_label/app/pages/home/home_view.dart';
import 'package:flutter_label/app/routes/app_pages.dart';
import 'package:flutter_label/app/theme/fluent_design_tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:path/path.dart' as path;

import '../../support/test_app.dart';

void main() {
  late AppDatabase database;

  setUp(() {
    Get.testMode = true;
    database = AppDatabase(NativeDatabase.memory());
    Get.put<AppDatabase>(database);
    Get.put(HomeController());
  });

  tearDown(() async {
    await database.close();
    Get.reset();
  });

  testWidgets('首页展示 MVP 入口说明', (tester) async {
    setTestViewport(tester, const Size(1200, 900));

    await tester.pumpWidget(buildTestApp(home: const HomeView()));
    await tester.pumpAndSettle();

    expect(find.text('打开数据集项目'), findsAtLeastNWidgets(1));
    expect(find.text('新建数据集项目'), findsOneWidget);
    expect(find.text('项目历史'), findsOneWidget);
    expect(
      find.text('选择或新建包含 data.yaml 的 YOLO 数据集项目，进入图片标注并自动维护标准目录。'),
      findsOneWidget,
    );
    expect(find.textContaining('自动生成 images/labels'), findsNothing);
    expect(find.text('进入视频抽帧'), findsNothing);
    expect(find.text('进入自动预标注'), findsNothing);
    expect(find.text('进入模型验证'), findsNothing);
    expect(find.text('进入格式转换'), findsNothing);
    expect(find.text('进入数据集导出'), findsNothing);
    expect(find.byIcon(Icons.folder_open), findsAtLeastNWidgets(1));
    expect(
      find.byIcon(Icons.create_new_folder_outlined),
      findsAtLeastNWidgets(1),
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('首页桌面布局左右卡片等高且历史区更宽', (tester) async {
    setTestViewport(tester, const Size(1280, 900));

    await tester.pumpWidget(buildTestApp(home: const HomeView()));
    await tester.pumpAndSettle();

    final projectRect = tester.getRect(
      find.byKey(const ValueKey('project-entry-card')),
    );
    final historyRect = tester.getRect(
      find.byKey(const ValueKey('history-panel-card')),
    );

    expect(projectRect.top, historyRect.top);
    expect(projectRect.bottom, historyRect.bottom);
    expect(historyRect.width, greaterThan(projectRect.width));
    expect(historyRect.width / projectRect.width, closeTo(1.5, 0.08));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('首页窄屏布局不溢出', (tester) async {
    setTestViewport(tester, const Size(390, 800));

    await tester.pumpWidget(buildTestApp(home: const HomeView()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('数据集项目'), findsOneWidget);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('项目历史记录缺失时标红且可打开右键删除菜单', (tester) async {
    setTestViewport(tester, const Size(1200, 900));
    final missingProjectDir = _missingProjectPath();
    expect(Directory(missingProjectDir).existsSync(), isFalse);
    final recordId = await database.addHistoryRecord(
      actionType: HistoryActionType.openDatasetProject,
      title: '打开数据集项目',
      description: missingProjectDir,
      targetRoute: Routes.annotation,
      payload: missingProjectDir,
    );

    await tester.pumpWidget(buildTestApp(home: const HomeView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('项目文件夹不存在'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline), findsOneWidget);
    final errorIcon = tester.widget<Icon>(find.byIcon(Icons.error_outline));
    expect(errorIcon.color, FluentDesignPalette.light.errorRed);

    final tile = find.byKey(ValueKey('history-record-$recordId'));
    await tester.tap(tile);
    await tester.pump();
    final controller = Get.find<HomeController>();
    expect(controller.errorMessage.value, contains('项目文件夹不存在'));
    expect(find.byKey(ValueKey('history-open-$recordId')), findsOneWidget);
    expect(find.byKey(ValueKey('history-delete-$recordId')), findsOneWidget);

    await tester.tap(tile, buttons: kSecondaryButton);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('删除此记录'), findsOneWidget);

    await tester.pump(const Duration(milliseconds: 120));

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('项目历史长路径中间省略且移除冗余动作文本', (tester) async {
    setTestViewport(tester, const Size(1200, 900));
    final longProjectDir = Directory(
      path.join(
        Directory.systemTemp.path,
        'flutter_label_home_history',
        'Downloads',
        'datasets',
        'archive',
        'data_v3',
      ),
    )..createSync(recursive: true);
    addTearDown(() {
      final root = Directory(
        path.join(Directory.systemTemp.path, 'flutter_label_home_history'),
      );
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });
    final longProjectPath = longProjectDir.path;
    final recordId = await database.addHistoryRecord(
      actionType: HistoryActionType.openDatasetProject,
      title: '测试数据集',
      description: longProjectPath,
      targetRoute: Routes.annotation,
      payload: longProjectPath,
    );

    await tester.pumpWidget(buildTestApp(home: const HomeView()));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));

    expect(
      find.text(
        '${path.rootPrefix(longProjectPath)}...${path.separator}archive${path.separator}data_v3',
      ),
      findsOneWidget,
    );
    expect(find.text(longProjectPath), findsNothing);
    expect(find.text('快速打开'), findsNothing);
    expect(find.byIcon(Icons.open_in_new), findsOneWidget);
    expect(find.byIcon(Icons.delete_outline), findsWidgets);
    expect(_historyRecordActionLabelFinder(recordId), findsNothing);

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });

  testWidgets('删除单条项目历史记录后只移除该记录', (tester) async {
    setTestViewport(tester, const Size(1200, 900));
    final missingProjectPath = _missingProjectPath();
    final recordId = await database.addHistoryRecord(
      actionType: HistoryActionType.openDatasetProject,
      title: '打开数据集项目',
      description: missingProjectPath,
      targetRoute: Routes.annotation,
      payload: missingProjectPath,
    );
    await database.addHistoryRecord(
      actionType: HistoryActionType.openFeaturePage,
      title: '进入视频抽帧',
      targetRoute: Routes.videoExtract,
    );

    final controller = Get.find<HomeController>();
    final records = await _readRecentHistory(database);
    final record = records.singleWhere((item) => item.id == recordId);

    await controller.deleteHistoryRecord(record);
    final remainingRecords = await _readRecentHistory(database);

    expect(remainingRecords, hasLength(1));
    expect(remainingRecords.single.title, '进入视频抽帧');

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump(Duration.zero);
  });
}

String _missingProjectPath() {
  return path.join(
    Directory.systemTemp.path,
    'flutter_label_missing_project_${DateTime.now().microsecondsSinceEpoch}',
  );
}

Future<List<HistoryRecord>> _readRecentHistory(AppDatabase database) {
  return (database.select(database.historyRecords)
        ..orderBy([
          (record) => OrderingTerm(
            expression: record.createdAt,
            mode: OrderingMode.desc,
          ),
          (record) =>
              OrderingTerm(expression: record.id, mode: OrderingMode.desc),
        ])
        ..limit(10))
      .get();
}

Finder _historyRecordActionLabelFinder(int recordId) {
  return find.descendant(
    of: find.byKey(ValueKey('history-record-$recordId')),
    matching: find.text('打开数据集项目'),
  );
}
