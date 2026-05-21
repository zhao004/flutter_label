import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';
import 'package:window_manager/window_manager.dart';

import 'app/controllers/app_settings_controller.dart';
import 'app/database/database.dart';
import 'app/routes/app_pages.dart';
import 'app/services/app_run_log_service.dart';
import 'app/theme/fluent_design_tokens.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await _configureDesktopWindow();
  if (!Get.isRegistered<AppDatabase>()) {
    Get.put<AppDatabase>(AppDatabase(), permanent: true);
  }
  if (!Get.isRegistered<AppRunLogService>()) {
    Get.put<AppRunLogService>(const AppRunLogService(), permanent: true);
  }
  ensureAppSettingsController();
  runApp(
    ToastificationWrapper(
      child: GetMaterialApp(
        title: 'YOLO 标注工具',
        debugShowCheckedModeBanner: false,
        theme: FluentDesignTokens.materialTheme(),
        defaultTransition: Transition.noTransition,
        transitionDuration: Duration.zero,
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
      ),
    ),
  );
}

Future<void> _configureDesktopWindow() async {
  if (kIsWeb || _isFlutterTestBinding()) {
    return;
  }
  if (!(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
    return;
  }

  await windowManager.ensureInitialized();
  const windowOptions = WindowOptions(
    size: Size(1440, 960),
    minimumSize: Size(1180, 760),
    center: true,
    backgroundColor: FluentDesignTokens.titleBarBackground,
    skipTaskbar: false,
    titleBarStyle: TitleBarStyle.hidden,
    windowButtonVisibility: false,
    title: 'YOLO 图片标注工具',
  );
  await windowManager.waitUntilReadyToShow(windowOptions, () async {
    await windowManager.show();
    await windowManager.focus();
  });
}

bool _isFlutterTestBinding() {
  final bindingType = WidgetsBinding.instance.runtimeType.toString();
  return bindingType.contains('TestWidgetsFlutterBinding');
}
