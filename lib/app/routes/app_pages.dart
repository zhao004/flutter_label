import 'package:get/get.dart';

import '../bindings/annotation_binding.dart';
import '../bindings/auto_label_binding.dart';
import '../bindings/dataset_export_binding.dart';
import '../bindings/format_convert_binding.dart';
import '../bindings/model_verify_binding.dart';
import '../bindings/run_log_binding.dart';
import '../bindings/settings_binding.dart';
import '../bindings/video_extract_binding.dart';
import '../pages/auto_label/auto_label_view.dart';
import '../pages/annotation/annotation_view.dart';
import '../pages/dataset_export/dataset_export_view.dart';
import '../pages/format_convert/format_convert_view.dart';
import '../pages/home/home_binding.dart';
import '../pages/home/home_view.dart';
import '../pages/model_verify/model_verify_view.dart';
import '../pages/run_log/run_log_view.dart';
import '../pages/settings/settings_view.dart';
import '../pages/video_extract/video_extract_view.dart';
import 'app_route_names.dart';

part 'app_routes.dart';

class AppPages {
  AppPages._();

  static const initial = Routes.home;
  static const _routeTransition = Transition.noTransition;
  static const _routeTransitionDuration = Duration.zero;

  static final routes = [
    GetPage(
      name: _Paths.home,
      page: () => const HomeView(),
      binding: HomeBinding(),
      transition: _routeTransition,
      transitionDuration: _routeTransitionDuration,
    ),
    GetPage(
      name: _Paths.annotation,
      page: () => const AnnotationView(),
      binding: AnnotationBinding(),
      transition: _routeTransition,
      transitionDuration: _routeTransitionDuration,
    ),
    GetPage(
      name: _Paths.videoExtract,
      page: () => const VideoExtractView(),
      binding: VideoExtractBinding(),
      transition: _routeTransition,
      transitionDuration: _routeTransitionDuration,
    ),
    GetPage(
      name: _Paths.autoLabel,
      page: () => const AutoLabelView(),
      binding: AutoLabelBinding(),
      transition: _routeTransition,
      transitionDuration: _routeTransitionDuration,
    ),
    GetPage(
      name: _Paths.modelVerify,
      page: () => const ModelVerifyView(),
      binding: ModelVerifyBinding(),
      transition: _routeTransition,
      transitionDuration: _routeTransitionDuration,
    ),
    GetPage(
      name: _Paths.formatConvert,
      page: () => const FormatConvertView(),
      binding: FormatConvertBinding(),
      transition: _routeTransition,
      transitionDuration: _routeTransitionDuration,
    ),
    GetPage(
      name: _Paths.datasetExport,
      page: () => const DatasetExportView(),
      binding: DatasetExportBinding(),
      transition: _routeTransition,
      transitionDuration: _routeTransitionDuration,
    ),
    GetPage(
      name: _Paths.runLog,
      page: () => const RunLogView(),
      binding: RunLogBinding(),
      transition: _routeTransition,
      transitionDuration: _routeTransitionDuration,
    ),
    GetPage(
      name: _Paths.settings,
      page: () => const SettingsView(),
      binding: SettingsBinding(),
      transition: _routeTransition,
      transitionDuration: _routeTransitionDuration,
    ),
  ];
}
