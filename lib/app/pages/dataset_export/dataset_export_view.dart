import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/dataset_export_controller.dart';
import '../../theme/fluent_design_tokens.dart';
import '../../widgets/responsive_tool_scaffold.dart';
import '../../widgets/task_controls.dart';

/// 数据集导出页面，负责采集导出参数并展示服务层返回的日志与统计。
class DatasetExportView extends GetView<DatasetExportController> {
  const DatasetExportView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveToolScaffold(
      title: '数据集导出',
      panes: [
        ResponsiveToolPane(
          title: '参数',
          icon: Icons.tune,
          width: 460,
          showHeader: false,
          child: _SettingsPanel(controller: controller),
        ),
        ResponsiveToolPane(
          title: '日志',
          icon: Icons.article_outlined,
          showHeader: false,
          child: _LogPanel(controller: controller),
        ),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.controller});

  final DatasetExportController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => TaskSettingsPanel(
        children: [
          TaskSettingsSection(
            title: '路径',
            icon: Icons.folder_open_outlined,
            children: [
              _PathField(
                label: '项目目录',
                value: controller.projectDir.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickProjectDir,
              ),
              _PathField(
                label: '导出目录',
                value: controller.outputDir.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickOutputDir,
              ),
            ],
          ),
          TaskSettingsSection(
            title: '划分比例（%）',
            icon: Icons.pie_chart,
            description: '比例总和由控制器校验，窄宽度下自动纵向排列。',
            children: [_RatioFields(controller: controller)],
          ),
          TaskSettingsSection(
            title: '导出选项',
            icon: Icons.checklist_outlined,
            children: [
              _ExportOptionTile(
                title: '打乱图片顺序',
                value: controller.shuffle.value,
                enabled: !controller.isRunning.value,
                onChanged: (value) => controller.shuffle.value = value,
              ),
              _ExportOptionTile(
                title: '复制空标签',
                subtitle: '开启后缺失或空 txt 会导出为空标签文件',
                value: controller.includeEmptyLabels.value,
                enabled: !controller.isRunning.value,
                onChanged: (value) =>
                    controller.includeEmptyLabels.value = value,
              ),
              _ExportOptionTile(
                title: '生成 zip',
                value: controller.createZip.value,
                enabled: !controller.isRunning.value,
                onChanged: (value) => controller.createZip.value = value,
              ),
            ],
          ),
          TaskActionArea(
            isRunning: controller.isRunning.value,
            children: [
              FilledButton.icon(
                onPressed: controller.isRunning.value
                    ? (controller.isStopping.value
                          ? null
                          : controller.stopExport)
                    : () => unawaited(controller.startExport()),
                icon: Icon(
                  controller.isRunning.value
                      ? Icons.stop_circle_outlined
                      : Icons.archive_outlined,
                ),
                label: Text(controller.isRunning.value ? '停止' : '开始导出'),
              ),
              if (controller.result.value != null)
                TaskResultCard(
                  title: '导出结果',
                  message:
                      '已导出 ${controller.result.value!.exportedCount} 张，跳过 ${controller.result.value!.skippedCount} 张',
                  icon: Icons.archive_outlined,
                  success: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ExportOptionTile extends StatelessWidget {
  const _ExportOptionTile({
    required this.title,
    required this.value,
    required this.enabled,
    required this.onChanged,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: palette.cardBackground.withValues(alpha: 0.42),
        border: Border.all(color: palette.fieldBorder),
        borderRadius: BorderRadius.circular(10),
      ),
      child: SwitchListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 12),
        title: Text(title),
        subtitle: subtitle == null
            ? null
            : Text(
                subtitle!,
                style: TextStyle(color: palette.textSecondary, fontSize: 12),
              ),
        value: value,
        onChanged: enabled ? onChanged : null,
      ),
    );
  }
}

class _PathField extends StatelessWidget {
  const _PathField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onPick,
  });

  final String label;
  final String value;
  final bool enabled;
  final Future<void> Function() onPick;

  @override
  Widget build(BuildContext context) {
    return TaskPathField(
      label: label,
      value: value,
      enabled: enabled,
      onPick: onPick,
    );
  }
}

class _RatioField extends StatelessWidget {
  const _RatioField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final String label;
  final String value;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      initialValue: value,
      enabled: enabled,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: enabled ? onChanged : null,
    );
  }
}

class _RatioFields extends StatelessWidget {
  const _RatioFields({required this.controller});

  final DatasetExportController controller;

  @override
  Widget build(BuildContext context) {
    final fields = [
      _RatioField(
        label: 'train',
        value: controller.trainRatioText.value,
        enabled: !controller.isRunning.value,
        onChanged: controller.setTrainRatio,
      ),
      _RatioField(
        label: 'val',
        value: controller.valRatioText.value,
        enabled: !controller.isRunning.value,
        onChanged: controller.setValRatio,
      ),
      _RatioField(
        label: 'test',
        value: controller.testRatioText.value,
        enabled: !controller.isRunning.value,
        onChanged: controller.setTestRatio,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth < 330) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < fields.length; index += 1) ...[
                if (index > 0) const SizedBox(height: 8),
                fields[index],
              ],
            ],
          );
        }

        return Row(
          children: [
            Expanded(child: fields[0]),
            const SizedBox(width: 8),
            Expanded(child: fields[1]),
            const SizedBox(width: 8),
            Expanded(child: fields[2]),
          ],
        );
      },
    );
  }
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.controller});

  final DatasetExportController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => TaskLogPanel(
        title: '导出日志',
        logs: controller.logs.toList(growable: false),
        emptyMessage: '配置项目和导出目录后开始导出',
      ),
    );
  }
}
