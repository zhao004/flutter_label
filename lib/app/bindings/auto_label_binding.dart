import 'package:get/get.dart';

import '../controllers/auto_label_controller.dart';

class AutoLabelBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<AutoLabelController>(() => AutoLabelController());
  }
}
