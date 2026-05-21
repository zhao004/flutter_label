import 'package:flutter/material.dart';
import 'package:flutter_label/app/pages/home/home_controller.dart';
import 'package:flutter_label/app/pages/home/home_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/test_app.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(HomeController());
  });

  tearDown(Get.reset);

  testWidgets('首页展示 MVP 入口说明', (tester) async {
    setTestViewport(tester, const Size(1200, 900));

    await tester.pumpWidget(buildTestApp(home: const HomeView()));
    await tester.pumpAndSettle();

    expect(find.text('YOLO 图片标注工具'), findsOneWidget);
    expect(find.text('打开数据集项目'), findsOneWidget);
    expect(find.text('新建数据集项目'), findsOneWidget);
    expect(find.text('进入视频抽帧'), findsOneWidget);
    expect(find.text('进入自动预标注'), findsOneWidget);
    expect(find.text('进入模型验证'), findsOneWidget);
    expect(find.text('进入格式转换'), findsOneWidget);
    expect(find.text('进入数据集导出'), findsOneWidget);
    expect(find.text('运行日志'), findsOneWidget);
    expect(find.text('配置'), findsOneWidget);
    expect(find.byIcon(Icons.folder_open), findsOneWidget);
    expect(find.byIcon(Icons.create_new_folder_outlined), findsOneWidget);
    expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
  });

  testWidgets('首页窄屏布局不溢出', (tester) async {
    setTestViewport(tester, const Size(390, 800));

    await tester.pumpWidget(buildTestApp(home: const HomeView()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('YOLO 图片标注工具'), findsOneWidget);
  });
}
