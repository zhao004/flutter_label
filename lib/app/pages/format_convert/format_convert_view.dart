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
          showHeader: false,
          child: _SettingsPanel(controller: controller),
        ),
        ResponsiveToolPane(
          title: '日志',
          icon: Icons.article_outlined,
          showHeader: false,
          child: Obx(
            () => TaskLogPanel(
              title: '转换日志',
              logs: controller.logs.toList(growable: false),
              emptyMessage: '配置格式与目录后开始转换',
            ),
          ),
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
            icon: Icons.swap_horiz,
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
            icon: Icons.folder_open_outlined,
            children: [
              TaskPathField(
                label: '输入目录',
                value: controller.inputDir.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickInputDir,
              ),
              TaskPathField(
                label: '输出目录',
                value: controller.outputDir.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickOutputDir,
              ),
              TaskPathField(
                label: 'data.yaml',
                value: controller.dataYamlPath.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickDataYamlFile,
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
                          : controller.stopConvert)
                    : () => unawaited(controller.startConvert()),
                icon: Icon(
                  controller.isRunning.value
                      ? Icons.stop_circle_outlined
                      : Icons.swap_horiz,
                ),
                label: Text(controller.isRunning.value ? '停止' : '开始转换'),
              ),
              if (controller.result.value != null)
                TaskResultCard(
                  title: '转换结果',
                  message:
                      '成功 ${controller.result.value!.convertedCount}，跳过 ${controller.result.value!.skippedCount}',
                  icon: Icons.swap_horiz,
                  success: true,
                ),
            ],
          ),
        ],
      ),
    );
  }
}
