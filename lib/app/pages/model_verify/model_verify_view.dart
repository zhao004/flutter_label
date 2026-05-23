import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/model_verify_controller.dart';
import '../../models/model_verify_config.dart';
import '../../theme/fluent_design_tokens.dart';
import '../../widgets/bbox_painter.dart';
import '../../widgets/detection_overlay.dart';
import '../../widgets/detection_preview.dart';
import '../../widgets/responsive_tool_scaffold.dart';
import '../../widgets/task_controls.dart';
import '../../widgets/window_detection_preview.dart';

class ModelVerifyView extends GetView<ModelVerifyController> {
  const ModelVerifyView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveToolScaffold(
      title: '模型验证',
      breakpoint: ResponsiveBreakpoints.threePane,
      panes: [
        ResponsiveToolPane(
          title: '参数',
          icon: Icons.tune,
          width: 430,
          showHeader: false,
          child: _SettingsPanel(controller: controller),
        ),
        ResponsiveToolPane(
          title: '实时预览',
          icon: Icons.image_outlined,
          showHeader: false,
          child: _PreviewPanel(controller: controller),
        ),
        ResponsiveToolPane(
          title: '检测结果',
          icon: Icons.list_alt_outlined,
          width: 280,
          child: _ResultPanel(controller: controller),
        ),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.controller});

  final ModelVerifyController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => TaskSettingsPanel(
        children: [
          TaskSettingsSection(
            title: '验证模式',
            icon: Icons.visibility_outlined,
            children: [
              SegmentedButton<ModelVerifyMode>(
                segments: const [
                  ButtonSegment(
                    value: ModelVerifyMode.image,
                    label: Text('图片'),
                  ),
                  ButtonSegment(
                    value: ModelVerifyMode.window,
                    label: Text('窗口'),
                  ),
                ],
                selected: {controller.mode.value},
                onSelectionChanged: controller.isRunning.value
                    ? null
                    : (values) => controller.setMode(values.first),
              ),
              TaskPathField(
                label: 'ONNX 模型',
                value: controller.modelPath.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickModel,
              ),
              if (controller.mode.value == ModelVerifyMode.window)
                _WindowPicker(controller: controller)
              else
                TaskPathField(
                  label: '图片文件',
                  value: controller.sourcePath.value,
                  enabled: !controller.isRunning.value,
                  onPick: controller.pickSource,
                ),
            ],
          ),
          TaskSettingsSection(
            title: '推理参数',
            icon: Icons.tune_outlined,
            description: '图片和窗口验证共用这组阈值，运行中保持锁定。',
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
              _ClassCountField(
                enabled: !controller.isRunning.value,
                value: controller.classCount.value,
                onChanged: controller.setClassCount,
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
                    ? () => unawaited(controller.stopVerify())
                    : () => unawaited(controller.runVerify()),
                icon: controller.isRunning.value
                    ? const Icon(Icons.stop_circle_outlined)
                    : const Icon(Icons.play_arrow),
                label: Text(controller.isRunning.value ? '停止' : '开始验证'),
              ),
              if (controller.isRunning.value)
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    LinearProgressIndicator(
                      value: controller.totalFrames.value > 0
                          ? controller.processedFrames.value /
                                controller.totalFrames.value
                          : null,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      controller.verifyStage.value.isEmpty
                          ? '模型验证运行中...'
                          : controller.verifyStage.value,
                    ),
                    if (controller.totalFrames.value > 0)
                      Text(
                        '处理帧 ${controller.processedFrames.value}/${controller.totalFrames.value}',
                      ),
                    if (controller.currentFramePath.value.isNotEmpty)
                      Text(
                        controller.currentFramePath.value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                  ],
                ),
              if (controller.mode.value == ModelVerifyMode.window)
                const Text('窗口验证默认限制为 5 FPS，避免推理占满 CPU/GPU。'),
            ],
          ),
        ],
      ),
    );
  }
}

class _WindowPicker extends StatefulWidget {
  const _WindowPicker({required this.controller});

  final ModelVerifyController controller;

  @override
  State<_WindowPicker> createState() => _WindowPickerState();
}

class _WindowPickerState extends State<_WindowPicker> {
  Timer? _timer;
  var _dragging = false;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final colorScheme = Theme.of(context).colorScheme;
      final hovered = widget.controller.hoveredWindow.value;
      final selected = widget.controller.selectedWindow.value;
      final activeWindow = hovered ?? selected;
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          GestureDetector(
            onPanStart: (_) => _startDragging(),
            onPanEnd: (_) => _finishDragging(),
            onPanCancel: _cancelDragging,
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: Border.all(color: colorScheme.outline),
                borderRadius: BorderRadius.circular(12),
                color: _dragging
                    ? colorScheme.primaryContainer
                    : colorScheme.surfaceContainerHighest,
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      Icons.ads_click,
                      size: 40,
                      color: _dragging
                          ? colorScheme.onPrimaryContainer
                          : colorScheme.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _dragging ? '拖到目标窗口后松开' : '按住准星拖动选择窗口',
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            activeWindow == null
                ? '未选择窗口'
                : '${activeWindow.title}（${activeWindow.width}x${activeWindow.height}）',
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 12),
        ],
      );
    });
  }

  void _startDragging() {
    setState(() => _dragging = true);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      unawaited(widget.controller.previewWindowUnderCursor());
    });
    unawaited(widget.controller.previewWindowUnderCursor());
  }

  void _finishDragging() {
    _timer?.cancel();
    setState(() => _dragging = false);
    unawaited(widget.controller.selectWindowUnderCursor());
  }

  void _cancelDragging() {
    _timer?.cancel();
    setState(() => _dragging = false);
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.controller});

  final ModelVerifyController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      if (controller.mode.value == ModelVerifyMode.window) {
        return _buildWindowPreview(context);
      }
      final imageResult = controller.imageResult.value;
      if (imageResult == null) {
        return const _ModelVerifyEmpty(
          icon: Icons.image_search_outlined,
          message: '运行验证后显示实时预览',
        );
      }
      final palette = FluentDesignTokens.of(context);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('实时预览', style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: palette.previewBackground,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: DetectionPreview(
                    imagePath: imageResult.imagePath,
                    detections: imageResult.detections,
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    });
  }

  Widget _buildWindowPreview(BuildContext context) {
    final selectedWindow = controller.selectedWindow.value;
    if (selectedWindow == null) {
      return const _ModelVerifyEmpty(
        icon: Icons.ads_click,
        message: '请拖动准星选择窗口后显示实时预览',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(
            '实时预览：${selectedWindow.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
        const Divider(height: 1),
        Expanded(
          child: WindowDetectionPreview(result: controller.windowResult.value),
        ),
      ],
    );
  }
}

class _ResultPanel extends StatelessWidget {
  const _ResultPanel({required this.controller});

  final ModelVerifyController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final detections =
          switch (controller.mode.value) {
            ModelVerifyMode.window => controller.windowResult.value?.detections,
            ModelVerifyMode.image => controller.imageResult.value?.detections,
          } ??
          const [];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '检测结果',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
                TaskStatusChip(
                  icon: Icons.radar_outlined,
                  label: '目标',
                  value: '${detections.length}',
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: detections.isEmpty
                ? const _ModelVerifyEmpty(
                    icon: Icons.fact_check_outlined,
                    message: '暂无检测结果',
                  )
                : ListView.builder(
                    padding: const EdgeInsets.all(12),
                    itemCount: detections.length,
                    itemBuilder: (context, index) {
                      final item = detections[index];
                      return _DetectionResultTile(
                        label: detectionLabelText(item),
                        classId: item.classId,
                        confidence: item.confidence,
                        coordinateText:
                            'x=${item.left.toStringAsFixed(0)}, y=${item.top.toStringAsFixed(0)}, '
                            'w=${item.width.toStringAsFixed(0)}, h=${item.height.toStringAsFixed(0)}',
                      );
                    },
                  ),
          ),
        ],
      );
    });
  }
}

class _DetectionResultTile extends StatelessWidget {
  const _DetectionResultTile({
    required this.label,
    required this.classId,
    required this.confidence,
    required this.coordinateText,
  });

  final String label;
  final int classId;
  final double confidence;
  final String coordinateText;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    final classColor = BboxPainter.colorForClass(classId);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: palette.fieldBackground,
          border: Border.all(color: palette.fieldBorder),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Row(
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                color: classColor,
                borderRadius: const BorderRadius.horizontal(
                  left: Radius.circular(10),
                ),
              ),
              child: const SizedBox(width: 3, height: 58),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(10, 8, 8, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            label,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                        Text(
                          '${(confidence * 100).toStringAsFixed(0)}%',
                          style: TextStyle(
                            color: classColor,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      coordinateText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontFamily: 'Consolas',
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModelVerifyEmpty extends StatelessWidget {
  const _ModelVerifyEmpty({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: palette.textSecondary),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: palette.textSecondary)),
        ],
      ),
    );
  }
}

class _ClassCountField extends StatefulWidget {
  const _ClassCountField({
    required this.enabled,
    required this.value,
    required this.onChanged,
  });

  final bool enabled;
  final int value;
  final ValueChanged<String> onChanged;

  @override
  State<_ClassCountField> createState() => _ClassCountFieldState();
}

class _ClassCountFieldState extends State<_ClassCountField> {
  late final TextEditingController _controller;
  late final FocusNode _focusNode;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.value.toString());
    _focusNode = FocusNode();
  }

  @override
  void didUpdateWidget(covariant _ClassCountField oldWidget) {
    super.didUpdateWidget(oldWidget);
    final nextText = widget.value.toString();
    if (!_focusNode.hasFocus && _controller.text != nextText) {
      _controller.text = nextText;
    }
  }

  @override
  void dispose() {
    _focusNode.dispose();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: _focusNode,
      enabled: widget.enabled,
      keyboardType: TextInputType.number,
      decoration: const InputDecoration(
        labelText: '类别数量（自动读取 data.yaml，可手动填写）',
        border: OutlineInputBorder(),
      ),
      onChanged: widget.onChanged,
    );
  }
}
