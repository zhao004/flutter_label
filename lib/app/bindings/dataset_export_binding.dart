import 'package:get/get.dart';

import '../controllers/dataset_export_controller.dart';

class DatasetExportBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut(() => DatasetExportController());
  }
}
