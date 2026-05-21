import 'package:get/get.dart';

import '../controllers/video_extract_controller.dart';

class VideoExtractBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VideoExtractController>(() => VideoExtractController());
  }
}
