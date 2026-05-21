import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../database/database.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  static const double _desktopBreakpoint = 900;
  static const double _panelGap = 24;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isDesktop = constraints.maxWidth >= _desktopBreakpoint;
            final contentPadding = EdgeInsets.all(isDesktop ? 32 : 16);

            if (isDesktop) {
              return Padding(
                padding: contentPadding,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      width: 420,
                      child: _FunctionPanel(controller: controller),
                    ),
                    const SizedBox(width: _panelGap),
                    Expanded(child: _HistoryPanel(controller: controller)),
                  ],
                ),
              );
            }

            return ListView(
              padding: contentPadding,
              children: [
                _FunctionPanel(controller: controller),
                const SizedBox(height: _panelGap),
                _HistoryPanel(controller: controller, shrinkWrap: true),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 首页左侧功能区，集中放置所有入口，避免业务入口散落在多个 Widget 中。
class _FunctionPanel extends StatelessWidget {
  const _FunctionPanel({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.45),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(28),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'YOLO 图片标注工具',
              style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 12),
            Obx(
              () => FilledButton.icon(
                onPressed: controller.isPicking.value
                    ? null
                    : controller.openDatasetProject,
                icon: controller.isPicking.value
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.folder_open),
                label: const Text('打开数据集项目'),
              ),
            ),
            const SizedBox(height: 12),
            Obx(
              () => OutlinedButton.icon(
                onPressed: controller.isPicking.value
                    ? null
                    : controller.createDatasetProject,
                icon: const Icon(Icons.create_new_folder_outlined),
                label: const Text('新建数据集项目'),
              ),
            ),
            const SizedBox(height: 20),
            _FeatureButton(
              icon: Icons.movie_outlined,
              label: '进入视频抽帧',
              onPressed: controller.openVideoExtractPage,
            ),
            _FeatureButton(
              icon: Icons.auto_fix_high,
              label: '进入自动预标注',
              onPressed: controller.openAutoLabelPage,
            ),
            _FeatureButton(
              icon: Icons.analytics_outlined,
              label: '进入模型验证',
              onPressed: controller.openModelVerifyPage,
            ),
            _FeatureButton(
              icon: Icons.swap_horiz,
              label: '进入格式转换',
              onPressed: controller.openFormatConvertPage,
            ),
            _FeatureButton(
              icon: Icons.archive_outlined,
              label: '进入数据集导出',
              onPressed: controller.openDatasetExportPage,
            ),
            _FeatureButton(
              icon: Icons.article_outlined,
              label: '运行日志',
              onPressed: controller.openRunLogPage,
            ),
            _FeatureButton(
              icon: Icons.settings_outlined,
              label: '配置',
              onPressed: controller.openSettingsPage,
            ),
            const SizedBox(height: 16),
          ],
        ),
      ),
    );
  }
}

class _FeatureButton extends StatelessWidget {
  const _FeatureButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final Future<void> Function() onPressed;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: OutlinedButton.icon(
        onPressed: onPressed,
        icon: Icon(icon),
        label: Text(label),
      ),
    );
  }
}

/// 首页右侧历史区，直接订阅 Drift Stream，数据库变更后自动刷新。
class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.controller, this.shrinkWrap = false});

  final HomeController controller;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      color: colorScheme.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: colorScheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                const Expanded(
                  child: Text(
                    '历史记录',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.w700),
                  ),
                ),
                TextButton.icon(
                  onPressed: controller.clearHistory,
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('清空'),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              '自动记录最近打开的功能、数据集项目和导入入口。',
              style: TextStyle(color: colorScheme.onSurfaceVariant),
            ),
            const SizedBox(height: 20),
            StreamBuilder<List<HistoryRecord>>(
              stream: controller.recentHistoryStream,
              initialData: const <HistoryRecord>[],
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return _HistoryMessage(
                    icon: Icons.error_outline,
                    message: '读取历史记录失败：${snapshot.error}',
                  );
                }

                final records = snapshot.data ?? const <HistoryRecord>[];
                if (records.isEmpty) {
                  return const _HistoryMessage(
                    icon: Icons.history_toggle_off,
                    message: '暂无历史记录',
                  );
                }

                final listView = ListView.separated(
                  shrinkWrap: shrinkWrap,
                  physics: shrinkWrap
                      ? const NeverScrollableScrollPhysics()
                      : const AlwaysScrollableScrollPhysics(),
                  itemCount: records.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    return _HistoryTile(record: records[index]);
                  },
                );

                if (shrinkWrap) {
                  return listView;
                }
                return Expanded(child: listView);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryTile extends StatelessWidget {
  const _HistoryTile({required this.record});

  final HistoryRecord record;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final description = record.description;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    record.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  _formatHistoryTime(record.createdAt),
                  style: TextStyle(
                    color: colorScheme.onSurfaceVariant,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 8,
              runSpacing: 8,
              children: [
                Chip(
                  visualDensity: VisualDensity.compact,
                  label: Text(record.actionType.label),
                ),
                if (description != null)
                  Text(
                    description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: colorScheme.onSurfaceVariant),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: colorScheme.onSurfaceVariant),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: colorScheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

String _formatHistoryTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
