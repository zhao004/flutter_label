import 'package:flutter/material.dart';
import 'package:flutter_label/app/widgets/fluent_app_shell.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/test_app.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('左侧导航不显示图片标注入口', (tester) async {
    setTestViewport(tester, const Size(1200, 800));

    await tester.pumpWidget(
      buildTestApp(home: const FluentAppShell(child: SizedBox.shrink())),
    );

    expect(find.text('工作台'), findsOneWidget);
    expect(find.text('视频抽帧'), findsOneWidget);
    expect(find.text('图片标注'), findsNothing);
  });

  testWidgets('左侧导航折叠后只显示图标', (tester) async {
    setTestViewport(tester, const Size(1200, 800));

    await tester.pumpWidget(
      buildTestApp(home: const FluentAppShell(child: SizedBox.shrink())),
    );

    expect(find.text('工作台'), findsOneWidget);
    expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('折叠导航'));
    await tester.pumpAndSettle();

    expect(find.byTooltip('展开导航'), findsOneWidget);
    expect(find.text('导航'), findsNothing);
    expect(find.text('工作台'), findsNothing);
    expect(find.text('视频抽帧'), findsNothing);
    expect(find.byIcon(Icons.dashboard_outlined), findsOneWidget);
    expect(find.byIcon(Icons.movie_outlined), findsOneWidget);

    await tester.tap(find.byTooltip('展开导航'));
    await tester.pumpAndSettle();

    expect(find.text('工作台'), findsOneWidget);
    expect(find.text('视频抽帧'), findsOneWidget);
  });

  testWidgets('窄屏导航按钮可以打开最小化浮层', (tester) async {
    setTestViewport(tester, const Size(390, 800));

    await tester.pumpWidget(
      buildTestApp(home: const FluentAppShell(child: SizedBox.shrink())),
    );

    expect(find.byTooltip('展开导航'), findsOneWidget);
    expect(tester.getTopLeft(find.text('工作台')).dx, lessThan(0));

    await tester.tap(find.byTooltip('展开导航'));
    await tester.pumpAndSettle();

    expect(find.text('工作台'), findsOneWidget);
    expect(find.text('视频抽帧'), findsOneWidget);
    expect(tester.getTopLeft(find.text('工作台')).dx, greaterThanOrEqualTo(0));
  });
}
