import 'package:flutter/material.dart';
import 'package:flutter_label/app/controllers/dataset_export_controller.dart';
import 'package:flutter_label/app/pages/dataset_export/dataset_export_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/test_app.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(DatasetExportController());
  });

  tearDown(Get.reset);

  testWidgets('数据集导出页面展示核心控件', (tester) async {
    setTestViewport(tester, const Size(1200, 900));

    await tester.pumpWidget(buildTestApp(home: const DatasetExportView()));

    expect(find.text('项目目录'), findsOneWidget);
    expect(find.text('导出目录'), findsOneWidget);
    expect(find.text('train'), findsOneWidget);
    expect(find.text('val'), findsOneWidget);
    expect(find.text('test'), findsOneWidget);
    expect(find.text('打乱图片顺序'), findsOneWidget);
    expect(find.text('复制空标签'), findsOneWidget);
    expect(find.text('生成 zip'), findsOneWidget);
    expect(find.text('开始导出'), findsAtLeastNWidgets(1));
    expect(find.text('停止'), findsNothing);
    expect(find.byIcon(Icons.archive_outlined), findsAtLeastNWidgets(1));
  });

  testWidgets('数据集导出页面窄屏布局不溢出', (tester) async {
    setTestViewport(tester, const Size(390, 800));

    await tester.pumpWidget(buildTestApp(home: const DatasetExportView()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('项目目录'), findsOneWidget);
    expect(find.text('导出日志'), findsOneWidget);
  });

  testWidgets('数据集导出运行中主按钮切换为停止并禁用输入', (tester) async {
    final controller = Get.find<DatasetExportController>()
      ..isRunning.value = true;

    await tester.pumpWidget(buildTestApp(home: const DatasetExportView()));

    final pickButtons = tester.widgetList<OutlinedButton>(
      find.widgetWithText(OutlinedButton, '选择'),
    );
    final ratioFields = tester.widgetList<TextFormField>(
      find.byType(TextFormField),
    );

    expect(find.text('开始导出'), findsNothing);
    expect(find.text('停止'), findsOneWidget);
    expect(find.byIcon(Icons.stop_circle_outlined), findsOneWidget);
    expect(pickButtons, hasLength(2));
    expect(pickButtons.every((button) => button.onPressed == null), isTrue);
    expect(ratioFields, hasLength(3));
    expect(ratioFields.every((field) => field.enabled == false), isTrue);

    controller.isStopping.value = true;
    await tester.pump();

    final stopButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, '停止'),
    );
    expect(stopButton.onPressed, isNull);
  });
}
