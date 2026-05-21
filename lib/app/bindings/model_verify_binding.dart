import 'package:get/get.dart';

import '../controllers/model_verify_controller.dart';

class ModelVerifyBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ModelVerifyController>(() => ModelVerifyController());
  }
}
