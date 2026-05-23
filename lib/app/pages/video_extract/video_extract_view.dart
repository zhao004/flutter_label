import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/video_extract_controller.dart';
import '../../models/video_extract_config.dart';
import '../../theme/fluent_design_tokens.dart';
import '../../widgets/responsive_tool_scaffold.dart';
import '../../widgets/task_controls.dart';

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
          showHeader: false,
          child: _SettingsPanel(controller: controller),
        ),
        ResponsiveToolPane(
          title: '预览',
          icon: Icons.image_outlined,
          showHeader: false,
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
    return Obx(
      () => TaskSettingsPanel(
        children: [
          TaskSettingsSection(
            title: '输入输出',
            icon: Icons.folder_open_outlined,
            children: [
              TaskPathField(
                label: '视频文件',
                value: controller.videoPath.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickVideo,
              ),
              TaskPathField(
                label: '输出目录',
                value: controller.outputDir.value,
                enabled: !controller.isRunning.value,
                onPick: controller.pickOutputDir,
              ),
            ],
          ),
          TaskSettingsSection(
            title: '抽帧模式',
            icon: Icons.speed_outlined,
            description: '根据视频内容选择固定帧率或固定间隔抽帧。',
            children: [
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
            ],
          ),
          TaskActionArea(
            isRunning: controller.isRunning.value,
            children: [
              FilledButton.icon(
                onPressed: controller.isRunning.value
                    ? controller.isCancelRequested.value
                          ? null
                          : controller.stopExtract
                    : () => unawaited(controller.startExtract()),
                icon: controller.isRunning.value
                    ? const Icon(Icons.stop_circle_outlined)
                    : const Icon(Icons.play_arrow),
                label: Text(controller.isRunning.value ? '停止' : '开始抽帧'),
              ),
              OutlinedButton.icon(
                onPressed: controller.generatedImages.isEmpty
                    ? null
                    : () => unawaited(controller.openOutputInAnnotation()),
                icon: const Icon(Icons.drive_folder_upload),
                label: const Text('导入输出目录到标注页'),
              ),
            ],
          ),
        ],
      ),
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
                TaskStatusChip(
                  icon: Icons.photo_library_outlined,
                  label: '已生成',
                  value: '${controller.generatedImages.length} 张',
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
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PreviewContent extends StatelessWidget {
  const _PreviewContent({required this.imagePath});

  final String? imagePath;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    final path = imagePath;
    if (path == null || path.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.movie_filter_outlined,
              size: 52,
              color: palette.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(
              '开始抽帧后将自动显示最新生成的图片',
              style: TextStyle(color: palette.textSecondary),
            ),
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
              color: palette.previewBackground,
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
        SelectableText(
          path,
          maxLines: 1,
          style: TextStyle(
            color: palette.textSecondary,
            fontFamily: 'Consolas',
            fontSize: 12,
          ),
        ),
      ],
    );
  }
}
