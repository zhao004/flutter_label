import 'package:flutter/material.dart';
import 'package:flutter_label/app/widgets/responsive_tool_scaffold.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import '../../support/test_app.dart';

const _parameterPaneKey = Key('parameter-pane-content');
const _previewPaneKey = Key('preview-pane-content');

void main() {
  setUp(() {
    Get.testMode = true;
  });

  tearDown(Get.reset);

  testWidgets('桌面工具面板会跟随窗口高度扩展', (tester) async {
    setTestViewport(tester, const Size(1200, 760));

    await tester.pumpWidget(buildTestApp(home: _buildToolScaffold()));
    await tester.pump();

    final shortParameterHeight = _paneContentHeight(tester, _parameterPaneKey);
    final shortPreviewHeight = _paneContentHeight(tester, _previewPaneKey);

    tester.view.physicalSize = const Size(1200, 960);
    await tester.pump();

    final tallParameterHeight = _paneContentHeight(tester, _parameterPaneKey);
    final tallPreviewHeight = _paneContentHeight(tester, _previewPaneKey);

    expect(tallParameterHeight, greaterThan(shortParameterHeight + 150));
    expect(tallPreviewHeight, greaterThan(shortPreviewHeight + 150));
  });
}

Widget _buildToolScaffold() {
  return ResponsiveToolScaffold(
    title: '测试工具',
    description: '验证工具页面板随窗口高度扩展。',
    panes: const [
      ResponsiveToolPane(
        title: '参数',
        icon: Icons.tune,
        width: 420,
        child: SizedBox.expand(key: _parameterPaneKey),
      ),
      ResponsiveToolPane(
        title: '预览',
        icon: Icons.image_outlined,
        child: SizedBox.expand(key: _previewPaneKey),
      ),
    ],
  );
}

double _paneContentHeight(WidgetTester tester, Key key) {
  return tester.getSize(find.byKey(key)).height;
}
