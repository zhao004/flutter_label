import 'package:get/get.dart';

import '../controllers/annotation_controller.dart';
import '../controllers/app_settings_controller.dart';
import '../controllers/class_controller.dart';
import '../controllers/image_list_controller.dart';
import '../controllers/project_controller.dart';

class AnnotationBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<ImageListController>(() => ImageListController());
    Get.lazyPut<ClassController>(() => ClassController());
    Get.lazyPut<ProjectController>(() => ProjectController());
    ensureAppSettingsController();
    Get.lazyPut<AnnotationController>(
      () => AnnotationController(
        imageListController: Get.find<ImageListController>(),
        classController: Get.find<ClassController>(),
        projectController: Get.find<ProjectController>(),
      ),
    );
  }
}
