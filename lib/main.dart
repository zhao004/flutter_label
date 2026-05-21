import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:toastification/toastification.dart';

import 'app/controllers/app_settings_controller.dart';
import 'app/database/database.dart';
import 'app/routes/app_pages.dart';
import 'app/services/app_run_log_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF176B5B)),
          useMaterial3: true,
        ),
        initialRoute: AppPages.initial,
        getPages: AppPages.routes,
      ),
    ),
  );
}
