import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_settings_controller.dart';

/// 配置页使用居中窄列布局，桌面和移动端都保持可读的表单宽度。
class SettingsView extends GetView<AppSettingsController> {
  const SettingsView({super.key});

  static const double _maxContentWidth = 720;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('配置')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: _maxContentWidth),
            child: Obx(
              () => ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  Text(
                    '应用配置',
                    style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '这些配置会保存在本机应用数据目录中，重启后仍然生效。',
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 20),
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                      side: BorderSide(color: colorScheme.outlineVariant),
                    ),
                    child: SwitchListTile(
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 24,
                        vertical: 12,
                      ),
                      title: const Text('标注页点击空格会标记已完成并调整下一张图片'),
                      subtitle: const Text(
                        '开启后，空格会先保存当前标注，再标记当前图片已完成，并切换到下一张可见图片。',
                      ),
                      value: controller.spaceCompletesAndSelectsNext.value,
                      onChanged: controller.isSaving.value
                          ? null
                          : (value) => unawaited(
                              controller.setSpaceCompletesAndSelectsNext(value),
                            ),
                    ),
                  ),
                  if (controller.isLoading.value || controller.isSaving.value)
                    const Padding(
                      padding: EdgeInsets.only(top: 16),
                      child: LinearProgressIndicator(),
                    ),
                  if (controller.errorMessage.value != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Card(
                        color: colorScheme.errorContainer,
                        elevation: 0,
                        child: ListTile(
                          leading: Icon(
                            Icons.error_outline,
                            color: colorScheme.onErrorContainer,
                          ),
                          title: Text(
                            controller.errorMessage.value!,
                            style: TextStyle(
                              color: colorScheme.onErrorContainer,
                            ),
                          ),
                          trailing: IconButton(
                            tooltip: '重新读取配置',
                            onPressed: controller.isLoading.value
                                ? null
                                : () => unawaited(controller.load()),
                            icon: const Icon(Icons.refresh),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
