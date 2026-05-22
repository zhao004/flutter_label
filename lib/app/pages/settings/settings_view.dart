import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/app_settings_controller.dart';
import '../../theme/fluent_design_tokens.dart';
import '../../widgets/fluent_app_shell.dart';
import '../../widgets/fluent_card.dart';

/// 配置页使用设计稿白卡表单布局，保留保存失败时的回滚和错误提示策略。
class SettingsView extends GetView<AppSettingsController> {
  const SettingsView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return FluentAppShell(
      child: ColoredBox(
        color: palette.appBackground,
        child: Obx(
          () => ListView(
            padding: FluentDesignTokens.pagePadding,
            children: [
              FluentPageHeader(
                title: '配置',
                description: '配置会保存在本机应用数据目录中，重启后仍然生效。',
                action: SizedBox(
                  width: 132,
                  height: 40,
                  child: OutlinedButton.icon(
                    onPressed: controller.isLoading.value
                        ? null
                        : () => unawaited(controller.load()),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('重新读取'),
                  ),
                ),
              ),
              const SizedBox(height: FluentDesignTokens.pageGap),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: FluentCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        '应用配置',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text('标注页快捷键'),
                                const SizedBox(height: 4),
                                Text(
                                  '开启后，空格会先保存当前标注，再标记已完成，并切换到下一张可见图片；保存失败会回滚开关并显示错误。',
                                  style: TextStyle(
                                    color: palette.textSecondary,
                                    fontSize: 13,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 16),
                          fluent.ToggleSwitch(
                            checked:
                                controller.spaceCompletesAndSelectsNext.value,
                            onChanged: controller.isSaving.value
                                ? null
                                : (value) => unawaited(
                                    controller.setSpaceCompletesAndSelectsNext(
                                      value,
                                    ),
                                  ),
                          ),
                        ],
                      ),
                      if (controller.isLoading.value ||
                          controller.isSaving.value)
                        const Padding(
                          padding: EdgeInsets.only(top: 16),
                          child: fluent.ProgressBar(),
                        ),
                      if (controller.errorMessage.value != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 16),
                          child: FluentCard(
                            color: palette.warningBackground,
                            borderColor: palette.warningBorder,
                            child: Row(
                              children: [
                                Icon(
                                  Icons.error_outline,
                                  color: palette.warningText,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(controller.errorMessage.value!),
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
