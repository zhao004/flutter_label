import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/format_convert_controller.dart';
import '../../models/format_convert_config.dart';
import '../../widgets/responsive_tool_scaffold.dart';
import '../../widgets/task_controls.dart';

class FormatConvertView extends GetView<FormatConvertController> {
  const FormatConvertView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveToolScaffold(
      title: '格式转换',
      panes: [
        ResponsiveToolPane(
          title: '参数',
          icon: Icons.tune,
          width: 430,
          child: _SettingsPanel(controller: controller),
        ),
        ResponsiveToolPane(
          title: '日志',
          icon: Icons.article_outlined,
          child: _LogPanel(controller: controller),
        ),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.controller});

  final FormatConvertController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => TaskSettingsPanel(
        children: [
          TaskSettingsSection(
            title: '格式',
            children: [
              DropdownButtonFormField<AnnotationFormat>(
                initialValue: controller.inputFormat.value,
                decoration: const InputDecoration(
                  labelText: '输入格式',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final format in AnnotationFormat.values)
                    DropdownMenuItem(value: format, child: Text(format.label)),
                ],
                onChanged: controller.isRunning.value
                    ? null
                    : (value) {
                        if (value != null) {
                          controller.setInputFormat(value);
                        }
                      },
              ),
              DropdownButtonFormField<AnnotationFormat>(
                initialValue: controller.outputFormat.value,
                decoration: const InputDecoration(
                  labelText: '输出格式',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final format in AnnotationFormat.values)
                    DropdownMenuItem(value: format, child: Text(format.label)),
                ],
                onChanged: controller.isRunning.value
                    ? null
                    : (value) {
                        if (value != null) {
                          controller.setOutputFormat(value);
                        }
                      },
              ),
            ],
          ),
          TaskSettingsSection(
            title: '路径',
            children: [
              _PathField(
                label: '输入目录',
                value: controller.inputDir.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickInputDir,
              ),
              _PathField(
                label: '输出目录',
                value: controller.outputDir.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickOutputDir,
              ),
              _PathField(
                label: 'data.yaml',
                value: controller.dataYamlPath.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickDataYamlFile,
              ),
            ],
          ),
          TaskActionArea(
            children: [
              FilledButton.icon(
                onPressed: controller.isRunning.value
                    ? null
                    : () => unawaited(controller.startConvert()),
                icon: controller.isRunning.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.swap_horiz),
                label: Text(controller.isRunning.value ? '转换中...' : '开始转换'),
              ),
              if (controller.result.value != null)
                TaskResultCard(
                  title: '转换结果',
                  message:
                      '成功 ${controller.result.value!.convertedCount}，跳过 ${controller.result.value!.skippedCount}',
                  icon: Icons.swap_horiz,
                ),
            ],
          ),
        ],
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

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.controller});

  final FormatConvertController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => TaskLogPanel(
        title: '转换日志',
        logs: controller.logs.toList(growable: false),
        emptyMessage: '配置格式与目录后开始转换',
      ),
    );
  }
}
