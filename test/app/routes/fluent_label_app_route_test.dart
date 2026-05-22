import 'package:flutter/material.dart';
import 'package:flutter_label/app/controllers/app_settings_controller.dart';
import 'package:flutter_label/app/routes/app_route_names.dart';
import 'package:flutter_label/main.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import '../../support/test_app.dart';

void main() {
  tearDown(Get.reset);

  testWidgets('FluentLabelApp 保留 GetX 命名路由和 binding', (tester) async {
    await tester.pumpWidget(
      const ToastificationWrapper(child: FluentLabelApp()),
    );
    await tester.pump();

    expect(find.text('项目工作台'), findsOneWidget);

    Get.offNamed(AppRouteNames.settings);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('应用配置'), findsOneWidget);
    expect(Get.currentRoute, AppRouteNames.settings);
    expect(Get.isRegistered<AppSettingsController>(), isTrue);
  });

  testWidgets('左侧导航折叠后切换路由保持折叠', (tester) async {
    setTestViewport(tester, const Size(1200, 800));

    await tester.pumpWidget(
      const ToastificationWrapper(child: FluentLabelApp()),
    );
    await tester.pump();

    await tester.tap(find.byTooltip('折叠导航'));
    await tester.pump();

    expect(find.byTooltip('展开导航'), findsOneWidget);
    expect(find.text('工作台'), findsNothing);

    await tester.tap(find.byIcon(Icons.settings_outlined));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('应用配置'), findsOneWidget);
    expect(Get.currentRoute, AppRouteNames.settings);
    expect(find.byTooltip('展开导航'), findsOneWidget);
    expect(find.text('工作台'), findsNothing);
    expect(find.text('视频抽帧'), findsNothing);
  });
}
