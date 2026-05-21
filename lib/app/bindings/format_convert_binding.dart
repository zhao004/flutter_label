import 'package:get/get.dart';

import '../controllers/format_convert_controller.dart';

class FormatConvertBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<FormatConvertController>(() => FormatConvertController());
  }
}
