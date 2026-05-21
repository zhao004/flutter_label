import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/format_convert_controller.dart';
import '../../models/format_convert_config.dart';
import '../../widgets/responsive_tool_scaffold.dart';

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
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('格式', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
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
            const SizedBox(height: 12),
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
            const SizedBox(height: 20),
            _PathField(
              label: '输入目录',
              value: controller.inputDir.value,
              enabled: !controller.isRunning.value,
              onPick: controller.pickInputDir,
            ),
            const SizedBox(height: 12),
            _PathField(
              label: '输出目录',
              value: controller.outputDir.value,
              enabled: !controller.isRunning.value,
              onPick: controller.pickOutputDir,
            ),
            const SizedBox(height: 12),
            _PathField(
              label: 'data.yaml',
              value: controller.dataYamlPath.value,
              enabled: !controller.isRunning.value,
              onPick: controller.pickDataYamlFile,
            ),
            const SizedBox(height: 24),
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
            const SizedBox(height: 12),
            if (controller.result.value != null)
              Text(
                '成功 ${controller.result.value!.convertedCount}，跳过 ${controller.result.value!.skippedCount}',
              ),
          ],
        ),
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
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: label,
              border: const OutlineInputBorder(),
            ),
            child: SelectableText(value.isEmpty ? '未选择' : value, maxLines: 1),
          ),
        ),
        const SizedBox(width: 8),
        OutlinedButton(
          onPressed: enabled ? onPick : null,
          child: const Text('选择'),
        ),
      ],
    );
  }
}

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.controller});

  final FormatConvertController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('转换日志', style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: controller.logs.length,
              itemBuilder: (context, index) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(controller.logs[index]),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
