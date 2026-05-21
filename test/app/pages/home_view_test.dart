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

    expect(find.text('项目工作台'), findsOneWidget);
    expect(find.text('打开数据集项目'), findsAtLeastNWidgets(1));
    expect(find.text('新建数据集项目'), findsOneWidget);
    expect(find.text('项目历史'), findsOneWidget);
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
  });

  testWidgets('首页窄屏布局不溢出', (tester) async {
    setTestViewport(tester, const Size(390, 800));

    await tester.pumpWidget(buildTestApp(home: const HomeView()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('项目工作台'), findsOneWidget);
  });
}
