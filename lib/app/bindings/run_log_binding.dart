import 'package:get/get.dart';

import '../controllers/run_log_controller.dart';
import '../services/app_run_log_service.dart';

class RunLogBinding extends Bindings {
  @override
  void dependencies() {
    if (!Get.isRegistered<AppRunLogService>()) {
      Get.put<AppRunLogService>(const AppRunLogService(), permanent: true);
    }
    Get.lazyPut<RunLogController>(() => RunLogController());
  }
}
