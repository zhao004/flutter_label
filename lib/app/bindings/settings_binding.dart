import 'package:get/get.dart';

import '../controllers/app_settings_controller.dart';

/// 配置页绑定复用全局配置控制器，避免不同页面持有不一致的开关状态。
class SettingsBinding extends Bindings {
  @override
  void dependencies() {
    ensureAppSettingsController();
  }
}
