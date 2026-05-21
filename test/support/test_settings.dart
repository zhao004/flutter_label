import 'package:flutter_label/app/controllers/app_settings_controller.dart';
import 'package:flutter_label/app/models/app_settings.dart';
import 'package:flutter_label/app/services/app_settings_service.dart';
import 'package:get/get.dart';

class MemoryAppSettingsService extends AppSettingsService {
  MemoryAppSettingsService({required AppSettings initialSettings})
    : _settings = initialSettings;

  AppSettings _settings;

  @override
  Future<AppSettings> load() async {
    return _settings;
  }

  @override
  Future<void> save(AppSettings settings) async {
    _settings = settings;
  }
}

Future<AppSettingsController> putTestSettingsController({
  bool spaceCompletesAndSelectsNext = false,
}) async {
  final service = MemoryAppSettingsService(
    initialSettings: AppSettings(
      spaceCompletesAndSelectsNext: spaceCompletesAndSelectsNext,
    ),
  );

  final controller = Get.put<AppSettingsController>(
    AppSettingsController(settingsService: service),
    permanent: true,
  );
  await controller.load();
  return controller;
}
