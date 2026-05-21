import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/dataset_export_controller.dart';
import '../../widgets/responsive_tool_scaffold.dart';

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

  final DatasetExportController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('路径', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _PathField(
              label: '项目目录',
              value: controller.projectDir.value,
              enabled: !controller.isRunning.value,
              onPick: controller.pickProjectDir,
            ),
            const SizedBox(height: 12),
            _PathField(
              label: '导出目录',
              value: controller.outputDir.value,
              enabled: !controller.isRunning.value,
              onPick: controller.pickOutputDir,
            ),
            const SizedBox(height: 20),
            Text('划分比例（%）', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _RatioField(
                    label: 'train',
                    value: controller.trainRatioText.value,
                    enabled: !controller.isRunning.value,
                    onChanged: controller.setTrainRatio,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RatioField(
                    label: 'val',
                    value: controller.valRatioText.value,
                    enabled: !controller.isRunning.value,
                    onChanged: controller.setValRatio,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _RatioField(
                    label: 'test',
                    value: controller.testRatioText.value,
                    enabled: !controller.isRunning.value,
                    onChanged: controller.setTestRatio,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('打乱图片顺序'),
              value: controller.shuffle.value,
              onChanged: controller.isRunning.value
                  ? null
                  : (value) => controller.shuffle.value = value,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('复制空标签'),
              subtitle: const Text('开启后缺失或空 txt 会导出为空标签文件'),
              value: controller.includeEmptyLabels.value,
              onChanged: controller.isRunning.value
                  ? null
                  : (value) => controller.includeEmptyLabels.value = value,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('生成 zip'),
              value: controller.createZip.value,
              onChanged: controller.isRunning.value
                  ? null
                  : (value) => controller.createZip.value = value,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: controller.isRunning.value
                  ? null
                  : () => unawaited(controller.startExport()),
              icon: controller.isRunning.value
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.archive_outlined),
              label: Text(controller.isRunning.value ? '导出中...' : '开始导出'),
            ),
            const SizedBox(height: 12),
            if (controller.result.value != null)
              Text(
                '已导出 ${controller.result.value!.exportedCount} 张，跳过 ${controller.result.value!.skippedCount} 张',
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

class _LogPanel extends StatelessWidget {
  const _LogPanel({required this.controller});

  final DatasetExportController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('导出日志', style: Theme.of(context).textTheme.titleMedium),
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
