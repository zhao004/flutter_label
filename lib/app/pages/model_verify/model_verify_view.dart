import 'dart:async';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/model_verify_controller.dart';
import '../../models/model_verify_config.dart';
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
          child: _SettingsPanel(controller: controller),
        ),
        ResponsiveToolPane(
          title: '检测结果',
          icon: Icons.list_alt_outlined,
          child: _ResultPanel(controller: controller),
        ),
        ResponsiveToolPane(
          title: '实时预览',
          icon: Icons.image_outlined,
          width: 420,
          child: _PreviewPanel(controller: controller),
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
              _PathField(
                label: 'ONNX 模型',
                value: controller.modelPath.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickModel,
              ),
              if (controller.mode.value == ModelVerifyMode.window)
                _WindowPicker(controller: controller)
              else
                _PathField(
                  label: '图片文件',
                  value: controller.sourcePath.value,
                  enabled: !controller.isRunning.value,
                  onPick: controller.pickSource,
                ),
            ],
          ),
          TaskSettingsSection(
            title: '推理参数',
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
            children: [
              FilledButton.icon(
                onPressed: controller.isRunning.value
                    ? null
                    : () => unawaited(controller.runVerify()),
                icon: controller.isRunning.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.play_arrow),
                label: Text(controller.isRunning.value ? '验证中...' : '开始验证'),
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
              if (controller.isRunning.value &&
                  controller.mode.value == ModelVerifyMode.window)
                OutlinedButton.icon(
                  onPressed: controller.isStopping.value
                      ? null
                      : () => unawaited(controller.stopVerify()),
                  icon: const Icon(Icons.stop_circle_outlined),
                  label: Text(controller.isStopping.value ? '停止中...' : '停止验证'),
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
        return const Center(child: Text('运行验证后显示实时预览'));
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Text('实时预览', style: Theme.of(context).textTheme.titleMedium),
          ),
          const Divider(height: 1),
          Expanded(
            child: DetectionPreview(
              imagePath: imageResult.imagePath,
              detections: imageResult.detections,
            ),
          ),
        ],
      );
    });
  }

  Widget _buildWindowPreview(BuildContext context) {
    final selectedWindow = controller.selectedWindow.value;
    if (selectedWindow == null) {
      return const Center(child: Text('请拖动准星选择窗口后显示实时预览'));
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
            child: Text(
              '检测结果（${detections.length}）',
              style: Theme.of(context).textTheme.titleMedium,
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: ListView.builder(
              itemCount: detections.length,
              itemBuilder: (context, index) {
                final item = detections[index];
                return ListTile(
                  dense: true,
                  title: Text(detectionLabelText(item)),
                  subtitle: Text(
                    'x=${item.left.toStringAsFixed(0)}, y=${item.top.toStringAsFixed(0)}, '
                    'w=${item.width.toStringAsFixed(0)}, h=${item.height.toStringAsFixed(0)}',
                  ),
                );
              },
            ),
          ),
        ],
      );
    });
  }
}

class _PathField extends StatelessWidget {
  const _PathField({
    required this.label,
    required this.value,
    required this.onPick,
    this.enabled = true,
  });

  final String label;
  final String value;
  final Future<void> Function() onPick;
  final bool enabled;

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
