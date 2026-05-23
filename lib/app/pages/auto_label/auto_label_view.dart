import 'dart:async';

import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/auto_label_controller.dart';
import '../../models/auto_label_config.dart';
import '../../models/dataset_split.dart';
import '../../theme/fluent_design_tokens.dart';
import '../../widgets/detection_preview.dart';
import '../../widgets/responsive_tool_scaffold.dart';
import '../../widgets/task_controls.dart';

class AutoLabelView extends GetView<AutoLabelController> {
  const AutoLabelView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveToolScaffold(
      title: '自动预标注',
      panes: [
        ResponsiveToolPane(
          title: '参数',
          icon: Icons.tune,
          width: 460,
          showHeader: false,
          child: _AutoLabelSettings(controller: controller),
        ),
        ResponsiveToolPane(
          title: '实时预览',
          icon: Icons.image_outlined,
          showHeader: false,
          child: _AutoLabelPreviewPanel(controller: controller),
        ),
      ],
    );
  }
}

class _AutoLabelSettings extends StatelessWidget {
  const _AutoLabelSettings({required this.controller});

  final AutoLabelController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => TaskSettingsPanel(
        children: [
          TaskSettingsSection(
            title: '输入输出',
            icon: Icons.folder_open_outlined,
            children: [
              _PathField(
                label: 'ONNX 模型',
                value: controller.modelPath.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickModel,
              ),
              _PathField(
                label: '图片目录（可选择数据集根目录）',
                value: controller.imageDir.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickImageDir,
              ),
              DropdownButtonFormField<DatasetFolderFilter>(
                initialValue: controller.folderFilter.value,
                decoration: const InputDecoration(
                  labelText: '文件夹筛选',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final filter in DatasetFolderFilter.values)
                    DropdownMenuItem(value: filter, child: Text(filter.label)),
                ],
                onChanged: controller.isRunning.value
                    ? null
                    : (value) {
                        if (value != null) {
                          controller.setFolderFilter(value);
                        }
                      },
              ),
              _PathField(
                label: '标签输出目录',
                value: controller.labelDir.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickLabelDir,
              ),
            ],
          ),
          TaskSettingsSection(
            title: '推理参数',
            icon: Icons.tune_outlined,
            description: '调整输入尺寸、置信度和 NMS 阈值后再开始批量写入标签。',
            children: [
              TextFormField(
                enabled: !controller.isRunning.value,
                initialValue: controller.imgsz.value.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'imgsz',
                  border: OutlineInputBorder(),
                ),
                onChanged: controller.setImgsz,
              ),
              TextFormField(
                enabled: !controller.isRunning.value,
                initialValue: controller.conf.value.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'conf',
                  border: OutlineInputBorder(),
                ),
                onChanged: controller.setConf,
              ),
              TextFormField(
                enabled: !controller.isRunning.value,
                initialValue: controller.iou.value.toString(),
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'iou',
                  border: OutlineInputBorder(),
                ),
                onChanged: controller.setIou,
              ),
              TextFormField(
                enabled: false,
                initialValue: controller.classCount.value.toString(),
                decoration: const InputDecoration(
                  labelText: '当前类别数量（可自动补齐）',
                  border: OutlineInputBorder(),
                ),
              ),
              DropdownButtonFormField<AutoLabelOverwriteStrategy>(
                initialValue: controller.strategy.value,
                decoration: const InputDecoration(
                  labelText: '覆盖策略',
                  border: OutlineInputBorder(),
                ),
                items: [
                  for (final item in AutoLabelOverwriteStrategy.values)
                    DropdownMenuItem(value: item, child: Text(item.label)),
                ],
                onChanged: controller.isRunning.value
                    ? null
                    : (value) {
                        if (value != null) {
                          controller.setStrategy(value);
                        }
                      },
              ),
            ],
          ),
          TaskActionArea(
            isRunning: controller.isRunning.value,
            children: [
              FilledButton.icon(
                onPressed: controller.isStopping.value
                    ? null
                    : controller.isRunning.value
                    ? () => unawaited(controller.stopAutoLabel())
                    : () => unawaited(controller.startAutoLabel()),
                icon: controller.isRunning.value
                    ? const Icon(Icons.stop_circle_outlined)
                    : const Icon(Icons.auto_fix_high),
                label: Text(controller.isRunning.value ? '停止' : '开始预标注'),
              ),
              if (controller.isRunning.value && controller.totalCount.value > 0)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    fluent.ProgressBar(
                      value:
                          controller.processedCount.value /
                          controller.totalCount.value,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '处理中 ${controller.processedCount.value}/${controller.totalCount.value}',
                    ),
                    if (controller.currentImagePath.value.isNotEmpty)
                      Text(
                        controller.currentImagePath.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 12,
                        ),
                      ),
                  ],
                ),
              if (controller.result.value != null)
                TaskResultCard(
                  title: '预标注结果',
                  message:
                      '写入 ${controller.result.value!.writtenCount}，合并 ${controller.result.value!.mergedCount}，跳过 ${controller.result.value!.skippedCount}',
                  icon: Icons.auto_fix_high,
                  success: true,
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

class _AutoLabelPreviewPanel extends StatelessWidget {
  const _AutoLabelPreviewPanel({required this.controller});

  final AutoLabelController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final palette = FluentDesignTokens.of(context);
      final previewImage = controller.activePreviewImage;
      final previewPath = controller.activePreviewImagePath;
      final currentIndex = controller.filteredPreviewImages.isEmpty
          ? 0
          : controller.selectedPreviewIndex.value + 1;
      final filteredCount = controller.filteredPreviewImages.length;
      final totalCount = controller.previewImages.length;
      final countText = controller.folderFilter.value == DatasetFolderFilter.all
          ? '$currentIndex/$filteredCount'
          : '$currentIndex/$filteredCount（共 $totalCount）';
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '实时预览',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TaskStatusChip(
                  icon: Icons.image_outlined,
                  label: '样本',
                  value: countText,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: previewPath.isEmpty
                ? const _AutoLabelPreviewEmpty()
                : Padding(
                    padding: const EdgeInsets.all(16),
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.previewBackground,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: DetectionPreview(
                          key: ValueKey(previewPath),
                          imagePath: previewPath,
                          detections: controller.activePreviewDetections,
                          imageWidth: previewImage?.width,
                          imageHeight: previewImage?.height,
                        ),
                      ),
                    ),
                  ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  controller.activePreviewLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                _PreviewNavigationButtonGroup(
                  canPrevious:
                      !controller.isRunning.value &&
                      controller.selectedPreviewIndex.value > 0,
                  canNext:
                      !controller.isRunning.value &&
                      controller.selectedPreviewIndex.value <
                          controller.filteredPreviewImages.length - 1,
                  onPrevious: controller.selectPreviousPreview,
                  onNext: controller.selectNextPreview,
                ),
              ],
            ),
          ),
        ],
      );
    });
  }
}

class _AutoLabelPreviewEmpty extends StatelessWidget {
  const _AutoLabelPreviewEmpty();

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.image_search_outlined,
            size: 56,
            color: palette.textSecondary,
          ),
          const SizedBox(height: 12),
          Text(
            '选择图片目录后显示样本预览',
            textAlign: TextAlign.center,
            style: TextStyle(color: palette.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PreviewNavigationButtonGroup extends StatelessWidget {
  const _PreviewNavigationButtonGroup({
    required this.canPrevious,
    required this.canNext,
    required this.onPrevious,
    required this.onNext,
  });

  final bool canPrevious;
  final bool canNext;
  final VoidCallback onPrevious;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return Center(
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.fieldBackground,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            _CompactPreviewButton(
              tooltip: '上一张',
              icon: Icons.chevron_left,
              onPressed: canPrevious ? onPrevious : null,
            ),
            Container(width: 1, height: 20, color: palette.border),
            _CompactPreviewButton(
              tooltip: '下一张',
              icon: Icons.chevron_right,
              onPressed: canNext ? onNext : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _CompactPreviewButton extends StatelessWidget {
  const _CompactPreviewButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton(
      tooltip: tooltip,
      onPressed: onPressed,
      icon: Icon(icon, size: 18),
      constraints: const BoxConstraints.tightFor(width: 36, height: 36),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
    );
  }
}
