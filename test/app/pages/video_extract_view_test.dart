import 'package:flutter/material.dart';
import 'package:flutter_label/app/controllers/video_extract_controller.dart';
import 'package:flutter_label/app/pages/video_extract/video_extract_view.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/test_app.dart';

void main() {
  setUp(() {
    Get.testMode = true;
    Get.put(VideoExtractController());
  });

  tearDown(Get.reset);

  testWidgets('视频抽帧页面展示核心控件', (tester) async {
    setTestViewport(tester, const Size(1200, 900));

    await tester.pumpWidget(buildTestApp(home: const VideoExtractView()));

    expect(find.text('视频抽帧'), findsAtLeastNWidgets(1));
    expect(find.text('视频文件'), findsOneWidget);
    expect(find.text('输出目录'), findsOneWidget);
    expect(find.text('开始抽帧'), findsAtLeastNWidgets(1));
    expect(find.text('停止抽帧'), findsOneWidget);
    expect(find.text('实时预览'), findsOneWidget);
    expect(find.text('同名文件处理'), findsOneWidget);
    expect(find.byIcon(Icons.play_arrow), findsAtLeastNWidgets(1));
  });

  testWidgets('视频抽帧页面窄屏布局不溢出', (tester) async {
    setTestViewport(tester, const Size(390, 800));

    await tester.pumpWidget(buildTestApp(home: const VideoExtractView()));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('参数'), findsOneWidget);
    expect(find.text('预览'), findsOneWidget);
  });
}
