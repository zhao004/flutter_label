import 'package:flutter/material.dart';
import 'package:flutter_label/app/controllers/model_verify_controller.dart';
import 'package:flutter_label/app/models/detection_result.dart';
import 'package:flutter_label/app/pages/model_verify/model_verify_view.dart';
import 'package:flutter_label/app/services/model_verify_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/test_app.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(ModelVerifyController());
  });

  tearDown(Get.reset);

  testWidgets('模型验证页面展示核心控件', (tester) async {
    setTestViewport(tester, const Size(1200, 900));

    await tester.pumpWidget(buildTestApp(home: const ModelVerifyView()));

    expect(find.text('模型验证'), findsOneWidget);
    expect(find.text('ONNX 模型'), findsOneWidget);
    expect(find.text('输出目录'), findsNothing);
    expect(find.text('开始验证'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsOneWidget);
    expect(find.text('视频'), findsNothing);
    expect(find.text('类别数量（自动读取 data.yaml，可手动填写）'), findsOneWidget);
    expect(find.textContaining('实时预览'), findsAtLeastNWidgets(1));
  });

  testWidgets('模型验证页面窄屏布局不溢出', (tester) async {
    setTestViewport(tester, const Size(390, 800));

    await tester.pumpWidget(buildTestApp(home: const ModelVerifyView()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('参数'), findsOneWidget);
    expect(find.text('实时预览'), findsAtLeastNWidgets(1));
    expect(find.text('检测结果'), findsAtLeastNWidgets(1));
  });

  testWidgets('模型验证检测结果列表同时显示类别名称和 ID', (tester) async {
    setTestViewport(tester, const Size(1200, 900));
    final controller = Get.find<ModelVerifyController>();
    controller.imageResult.value = const ModelVerifyResult(
      imagePath: 'C:/dataset/images/a.jpg',
      detections: [
        DetectionResult(
          classId: 2,
          className: 'helmet',
          confidence: 0.934,
          left: 10,
          top: 12,
          width: 30,
          height: 24,
        ),
      ],
      inferMs: 0,
      captureMs: 0,
      fps: 0,
      usedNative: true,
      logs: [],
    );

    await tester.pumpWidget(buildTestApp(home: const ModelVerifyView()));
    await tester.pump();

    expect(find.text('helmet (#2) 93.4%'), findsOneWidget);
  });
}
