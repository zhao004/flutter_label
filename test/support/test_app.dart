import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import 'package:flutter_test/flutter_test.dart';

Widget buildTestApp({required Widget home}) {
  return ToastificationWrapper(child: GetMaterialApp(home: home));
}

/// 设置测试视口，模拟桌面或窄屏场景，便于回归检查布局溢出。
void setTestViewport(WidgetTester tester, Size size) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
}
