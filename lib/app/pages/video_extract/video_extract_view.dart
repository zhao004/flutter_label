import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/video_extract_controller.dart';
import '../../models/video_extract_config.dart';
import '../../widgets/responsive_tool_scaffold.dart';

class VideoExtractView extends GetView<VideoExtractController> {
  const VideoExtractView({super.key});

  @override
  Widget build(BuildContext context) {
    return ResponsiveToolScaffold(
      title: '视频抽帧',
      panes: [
        ResponsiveToolPane(
          title: '参数',
          icon: Icons.tune,
          width: 420,
          child: _SettingsPanel(controller: controller),
        ),
        ResponsiveToolPane(
          title: '预览',
          icon: Icons.image_outlined,
          child: _PreviewPanel(controller: controller),
        ),
      ],
    );
  }
}

class _SettingsPanel extends StatelessWidget {
  const _SettingsPanel({required this.controller});

  final VideoExtractController controller;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Obx(
        () => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('输入输出', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            _PathField(
              label: '视频文件',
              value: controller.videoPath.value,
              onPick: controller.pickVideo,
            ),
            const SizedBox(height: 12),
            _PathField(
              label: '输出目录',
              value: controller.outputDir.value,
              onPick: controller.pickOutputDir,
            ),
            const SizedBox(height: 24),
            Text('抽帧模式', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 12),
            SegmentedButton<VideoExtractMode>(
              segments: const [
                ButtonSegment(
                  value: VideoExtractMode.fps,
                  label: Text('每秒 N 张'),
                  icon: Icon(Icons.speed),
                ),
                ButtonSegment(
                  value: VideoExtractMode.interval,
                  label: Text('每 N 帧'),
                  icon: Icon(Icons.filter_frames),
                ),
              ],
              selected: {controller.mode.value},
              onSelectionChanged: controller.isRunning.value
                  ? null
                  : (values) => controller.setMode(values.first),
            ),
            const SizedBox(height: 16),
            TextFormField(
              enabled:
                  !controller.isRunning.value &&
                  controller.mode.value == VideoExtractMode.fps,
              keyboardType: TextInputType.number,
              initialValue: controller.fps.value.toString(),
              decoration: const InputDecoration(
                labelText: 'fps',
                helperText: '推荐普通游戏视频 3~5，动作快 8~10',
                border: OutlineInputBorder(),
              ),
              onChanged: controller.setFps,
            ),
            const SizedBox(height: 12),
            TextFormField(
              enabled:
                  !controller.isRunning.value &&
                  controller.mode.value == VideoExtractMode.interval,
              keyboardType: TextInputType.number,
              initialValue: controller.frameInterval.value.toString(),
              decoration: const InputDecoration(
                labelText: '帧间隔',
                border: OutlineInputBorder(),
              ),
              onChanged: controller.setFrameInterval,
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<VideoExtractConflictStrategy>(
              initialValue: controller.conflictStrategy.value,
              decoration: const InputDecoration(
                labelText: '同名文件处理',
                border: OutlineInputBorder(),
              ),
              items: [
                for (final item in VideoExtractConflictStrategy.values)
                  DropdownMenuItem(value: item, child: Text(item.label)),
              ],
              onChanged: controller.isRunning.value
                  ? null
                  : (value) {
                      if (value != null) {
                        controller.setConflictStrategy(value);
                      }
                    },
            ),
            const SizedBox(height: 24),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: controller.isRunning.value
                        ? null
                        : () => unawaited(controller.startExtract()),
                    icon: controller.isRunning.value
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.play_arrow),
                    label: Text(controller.isRunning.value ? '抽帧中...' : '开始抽帧'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed:
                        controller.isRunning.value &&
                            !controller.isCancelRequested.value
                        ? controller.stopExtract
                        : null,
                    icon: const Icon(Icons.stop_circle_outlined),
                    label: Text(
                      controller.isCancelRequested.value ? '停止中...' : '停止抽帧',
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: controller.generatedImages.isEmpty
                  ? null
                  : () => unawaited(controller.openOutputInAnnotation()),
              icon: const Icon(Icons.drive_folder_upload),
              label: const Text('导入输出目录到标注页'),
            ),
            const SizedBox(height: 12),
            Text(
              '${controller.statusMessage.value}；已生成 ${controller.generatedImages.length} 张图片',
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
    required this.onPick,
  });

  final String label;
  final String value;
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
        OutlinedButton(onPressed: onPick, child: const Text('选择')),
      ],
    );
  }
}

class _PreviewPanel extends StatelessWidget {
  const _PreviewPanel({required this.controller});

  final VideoExtractController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(
      () => Column(
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
                Text(
                  '${controller.generatedImages.length} 张',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: _PreviewContent(
                imagePath: controller.latestPreviewImage.value,
                status: controller.statusMessage.value,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.imagePath, required this.status});

  final String? imagePath;
  final String status;

  @override
  Widget build(BuildContext context) {
    final path = imagePath;
    if (path == null || path.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.image_search_outlined,
              size: 56,
              color: Theme.of(context).colorScheme.outline,
            ),
            const SizedBox(height: 12),
            Text(status, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            const Text('开始抽帧后将自动显示最新生成的图片'),
          ],
        ),
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Expanded(
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Image.file(
                File(path),
                key: ValueKey(path),
                fit: BoxFit.contain,
                gaplessPlayback: true,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Text('预览图片读取失败')),
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        SelectableText(path, maxLines: 1),
        const SizedBox(height: 4),
        Text(status),
      ],
    );
  }
}
