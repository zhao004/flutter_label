import 'package:flutter/material.dart';
import 'package:flutter_label/app/pages/settings/settings_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/test_app.dart';
import '../../support/test_settings.dart';

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('配置页展示空格完成并切换开关', (tester) async {
    setTestViewport(tester, const Size(900, 700));
    final controller = await putTestSettingsController();

    await tester.pumpWidget(buildTestApp(home: const SettingsView()));
    await tester.pumpAndSettle();

    expect(find.text('配置'), findsOneWidget);
    expect(find.text('应用配置'), findsOneWidget);
    expect(find.text('标注页点击空格会标记已完成并调整下一张图片'), findsOneWidget);
    expect(controller.spaceCompletesAndSelectsNext.value, isFalse);

    await tester.tap(find.byType(SwitchListTile));
    await tester.pumpAndSettle();

    expect(controller.spaceCompletesAndSelectsNext.value, isTrue);
  });
}
