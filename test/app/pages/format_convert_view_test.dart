import 'package:flutter/material.dart';
import 'package:flutter_label/app/controllers/format_convert_controller.dart';
import 'package:flutter_label/app/pages/format_convert/format_convert_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/test_app.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(FormatConvertController());
  });

  tearDown(Get.reset);

  testWidgets('格式转换页面展示核心控件', (tester) async {
    setTestViewport(tester, const Size(1200, 900));

    await tester.pumpWidget(buildTestApp(home: const FormatConvertView()));

    expect(find.text('格式转换'), findsOneWidget);
    expect(find.text('输入格式'), findsOneWidget);
    expect(find.text('输出格式'), findsOneWidget);
    expect(find.text('输入目录'), findsOneWidget);
    expect(find.text('输出目录'), findsOneWidget);
    expect(find.text('data.yaml'), findsOneWidget);
    expect(find.text('开始转换'), findsOneWidget);
    expect(find.byIcon(Icons.swap_horiz), findsOneWidget);
  });

  testWidgets('格式转换页面窄屏布局不溢出', (tester) async {
    setTestViewport(tester, const Size(390, 800));

    await tester.pumpWidget(buildTestApp(home: const FormatConvertView()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('参数'), findsOneWidget);
    expect(find.text('日志'), findsOneWidget);
  });

  testWidgets('格式转换运行中会禁用路径选择', (tester) async {
    Get.find<FormatConvertController>().isRunning.value = true;

    await tester.pumpWidget(buildTestApp(home: const FormatConvertView()));

    final pickButtons = tester.widgetList<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '选择'),
    );

    expect(find.text('转换中...'), findsOneWidget);
    expect(pickButtons, hasLength(3));
    expect(pickButtons.every((button) => button.onPressed == null), isTrue);
  });
}
