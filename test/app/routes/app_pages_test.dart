import 'package:flutter_label/app/routes/app_pages.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

void main() {
  test('主页面路由不使用动画转场，避免导航切换时整壳层闪动', () {
    for (final route in AppPages.routes) {
      expect(route.transition, Transition.noTransition);
      expect(route.transitionDuration, Duration.zero);
    }
  });
}
