import 'package:get/get.dart';

import '../../controllers/app_settings_controller.dart';
import '../../database/database.dart';
import '../../services/app_run_log_service.dart';
import 'home_controller.dart';

class HomeBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AppDatabase>()) {
      Get.put<AppDatabase>(AppDatabase(), permanent: true);
    }
    if (!Get.isRegistered<AppRunLogService>()) {
      Get.put<AppRunLogService>(const AppRunLogService(), permanent: true);
    }
    ensureAppSettingsController();
    Get.lazyPut<HomeController>(() => HomeController());
  }
}
