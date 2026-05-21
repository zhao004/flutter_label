import 'dart:async';

import 'package:get/get.dart';

import '../models/app_settings.dart';
import '../services/app_settings_service.dart';
import '../services/app_toast_service.dart';

/// 管理应用配置状态，并在保存失败时回滚界面上的乐观更新。
class AppSettingsController extends GetxController {
  AppSettingsController({
    AppSettingsService settingsService = const AppSettingsService(),
  }) : _settingsService = settingsService;

  final AppSettingsService _settingsService;
  final spaceCompletesAndSelectsNext = false.obs;
  final isLoading = false.obs;
  final isSaving = false.obs;
  final errorMessage = RxnString();
  Future<void>? _loadingTask;

  @override
  void onInit() {
    super.onInit();
    unawaited(load());
  }

  Future<void> load() {
    final currentTask = _loadingTask;
    if (currentTask != null) {
      return currentTask;
    }

    final nextTask = _load();
    _loadingTask = nextTask.whenComplete(() => _loadingTask = null);
    return _loadingTask!;
  }

  Future<void> _load() async {
    isLoading.value = true;
    errorMessage.value = null;
    try {
      final settings = await _settingsService.load();
      spaceCompletesAndSelectsNext.value =
          settings.spaceCompletesAndSelectsNext;
    } catch (error) {
      errorMessage.value = '读取配置失败：$error';
      AppToast.error(errorMessage.value, source: '配置');
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> setSpaceCompletesAndSelectsNext(bool enabled) async {
    if (isSaving.value || spaceCompletesAndSelectsNext.value == enabled) {
      return;
    }

    final previousValue = spaceCompletesAndSelectsNext.value;
    spaceCompletesAndSelectsNext.value = enabled;
    isSaving.value = true;
    errorMessage.value = null;
    try {
      await _settingsService.save(
        AppSettings(spaceCompletesAndSelectsNext: enabled),
      );
    } catch (error) {
      spaceCompletesAndSelectsNext.value = previousValue;
      errorMessage.value = '保存配置失败：$error';
      AppToast.error(errorMessage.value, source: '配置');
    } finally {
      isSaving.value = false;
    }
  }
}

AppSettingsController ensureAppSettingsController({
  AppSettingsService settingsService = const AppSettingsService(),
}) {
  if (Get.isRegistered<AppSettingsController>()) {
    return Get.find<AppSettingsController>();
  }
  return Get.put<AppSettingsController>(
    AppSettingsController(settingsService: settingsService),
    permanent: true,
  );
}
