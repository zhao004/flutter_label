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
      title: '应用配置',
      child: ColoredBox(
        color: palette.appBackground,
        child: Obx(
          () => ListView(
            padding: FluentDesignTokens.pagePadding,
            children: [
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 760),
                child: FluentCard(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          Icon(
                            Icons.settings_outlined,
                            size: 20,
                            color: FluentDesignTokens.primaryBlue,
                          ),
                          const SizedBox(width: 8),
                          const Expanded(
                            child: Text(
                              '应用配置',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          IconButton(
                            tooltip: '重新读取',
                            onPressed: controller.isLoading.value
                                ? null
                                : () => unawaited(controller.load()),
                            icon: const Icon(Icons.refresh, size: 18),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      _SettingsOptionTile(
                        icon: Icons.keyboard_outlined,
                        title: '标注页快捷键',
                        description:
                            '开启后，空格会先保存当前标注，再标记已完成，并切换到下一张可见图片；保存失败会回滚开关并显示错误。',
                        checked: controller.spaceCompletesAndSelectsNext.value,
                        enabled: !controller.isSaving.value,
                        onChanged: (value) => unawaited(
                          controller.setSpaceCompletesAndSelectsNext(value),
                        ),
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
                            padding: EdgeInsets.zero,
                            child: IntrinsicHeight(
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: palette.warningText,
                                      borderRadius:
                                          const BorderRadius.horizontal(
                                            left: Radius.circular(
                                              FluentDesignTokens.cardRadius,
                                            ),
                                          ),
                                    ),
                                    child: const SizedBox(width: 3),
                                  ),
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.all(14),
                                      child: Row(
                                        children: [
                                          Icon(
                                            Icons.error_outline,
                                            color: palette.warningText,
                                          ),
                                          const SizedBox(width: 10),
                                          Expanded(
                                            child: Text(
                                              controller.errorMessage.value!,
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

class _SettingsOptionTile extends StatelessWidget {
  const _SettingsOptionTile({
    required this.icon,
    required this.title,
    required this.description,
    required this.checked,
    required this.enabled,
    required this.onChanged,
  });

  final IconData icon;
  final String title;
  final String description;
  final bool checked;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.fieldBackground,
        border: Border.all(color: palette.fieldBorder),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, size: 22, color: FluentDesignTokens.primaryBlue),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
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
              checked: checked,
              onChanged: enabled ? onChanged : null,
            ),
          ],
        ),
      ),
    );
  }
}
