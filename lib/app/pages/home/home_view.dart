import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../database/database.dart';
import '../../theme/fluent_design_tokens.dart';
import '../../widgets/fluent_app_shell.dart';
import '../../widgets/fluent_card.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return FluentAppShell(
      title: '项目工作台',
      child: ColoredBox(
        color: palette.appBackground,
        child: ListView(
          padding: FluentDesignTokens.pagePadding,
          children: [
            LayoutBuilder(
              builder: (context, constraints) {
                final useTwoColumns = constraints.maxWidth >= 960;
                if (!useTwoColumns) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _ProjectEntryCard(controller: controller),
                      const SizedBox(height: 16),
                      _HistoryPanel(controller: controller, shrinkWrap: true),
                    ],
                  );
                }
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 460,
                      child: _ProjectEntryCard(controller: controller),
                    ),
                    const SizedBox(width: 16),
                    Expanded(child: _HistoryPanel(controller: controller)),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _ProjectEntryCard extends StatelessWidget {
  const _ProjectEntryCard({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return FluentCard(
      padding: const EdgeInsets.all(20),
      hoverable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '数据集项目',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '选择包含 data.yaml 的项目根目录，读取类别并进入图片标注；也可以新建空项目目录。',
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          DecoratedBox(
            decoration: BoxDecoration(
              color: palette.fieldBackground,
              border: Border.fromBorderSide(
                BorderSide(color: palette.fieldBorder),
              ),
              borderRadius: const BorderRadius.all(Radius.circular(6)),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Text(
                '也可以新建数据集项目，自动生成 images/labels/train/val/test 目录。',
                style: TextStyle(color: palette.textSecondary, fontSize: 13),
              ),
            ),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Obx(
                () => SizedBox(
                  height: 38,
                  child: FilledButton.icon(
                    onPressed: controller.isPicking.value
                        ? null
                        : controller.openDatasetProject,
                    icon: controller.isPicking.value
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.folder_open, size: 18),
                    label: const Text('打开数据集项目'),
                  ),
                ),
              ),
              Obx(
                () => SizedBox(
                  height: 38,
                  child: OutlinedButton.icon(
                    onPressed: controller.isPicking.value
                        ? null
                        : controller.createDatasetProject,
                    icon: const Icon(
                      Icons.create_new_folder_outlined,
                      size: 18,
                    ),
                    label: const Text('新建数据集项目'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.controller, this.shrinkWrap = false});

  final HomeController controller;
  final bool shrinkWrap;

  @override
  Widget build(BuildContext context) {
    return FluentCard(
      padding: const EdgeInsets.all(20),
      hoverable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  '项目历史',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                ),
              ),
              TextButton.icon(
                onPressed: controller.clearHistory,
                icon: const Icon(Icons.delete_outline, size: 18),
                label: const Text('清空'),
              ),
            ],
          ),
          const SizedBox(height: 12),
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
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (context, index) {
                  return _HistoryTile(
                    controller: controller,
                    record: records[index],
                  );
                },
              );

              if (shrinkWrap) {
                return listView;
              }
              return SizedBox(height: 360, child: listView);
            },
          ),
        ],
      ),
    );
  }
}

class _HistoryTile extends StatefulWidget {
  const _HistoryTile({required this.controller, required this.record});

  final HomeController controller;
  final HistoryRecord record;

  @override
  State<_HistoryTile> createState() => _HistoryTileState();
}

class _HistoryTileState extends State<_HistoryTile> {
  late final fluent.FlyoutController _flyoutController;

  @override
  void initState() {
    super.initState();
    _flyoutController = fluent.FlyoutController();
  }

  @override
  void dispose() {
    _flyoutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    final record = widget.record;
    final isProjectRecord = widget.controller.isProjectHistoryRecord(record);
    final projectExists = widget.controller.historyProjectExists(record);
    final isMissingProject = isProjectRecord && !projectExists;
    final subtitle = _historySubtitle(
      record: record,
      projectPath: widget.controller.historyProjectPath(record),
      isMissingProject: isMissingProject,
    );

    final card = FluentCard(
      padding: EdgeInsets.zero,
      color: isMissingProject
          ? palette.errorRed.withValues(alpha: 0.08)
          : palette.fieldBackground,
      borderColor: isMissingProject
          ? palette.errorRed.withValues(alpha: 0.78)
          : palette.fieldBorder.withValues(alpha: 0.52),
      radius: 8,
      hoverable: true,
      blurSigma: 8,
      child: MouseRegion(
        cursor: isProjectRecord
            ? SystemMouseCursors.click
            : SystemMouseCursors.basic,
        child: GestureDetector(
          key: ValueKey('history-record-${record.id}'),
          behavior: HitTestBehavior.opaque,
          onTap: isProjectRecord
              ? () => widget.controller.openHistoryProject(record)
              : null,
          onSecondaryTap: _showDeleteMenu,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                SizedBox(
                  width: 46,
                  child: Text(
                    _formatHistoryTime(record.createdAt),
                    style: TextStyle(
                      color: isMissingProject
                          ? palette.errorRed
                          : palette.textSecondary,
                      fontSize: 12,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        record.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isMissingProject
                              ? palette.errorRed
                              : palette.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      if (subtitle != null) ...[
                        const SizedBox(height: 3),
                        Text(
                          subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: isMissingProject
                                ? palette.errorRed
                                : palette.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (isMissingProject) ...[
                  Icon(Icons.error_outline, size: 18, color: palette.errorRed),
                  const SizedBox(width: 8),
                ],
                Text(
                  record.actionType.label,
                  style: TextStyle(
                    color: isMissingProject
                        ? palette.errorRed
                        : palette.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return fluent.FlyoutTarget(controller: _flyoutController, child: card);
  }

  void _showDeleteMenu() {
    _flyoutController.showFlyout(
      barrierDismissible: true,
      dismissOnPointerMoveAway: false,
      builder: (context) {
        return fluent.MenuFlyout(
          items: [
            fluent.MenuFlyoutItem(
              leading: const Icon(Icons.delete_outline, size: 16),
              text: const Text('删除此记录'),
              onPressed: () {
                WidgetsBinding.instance.addPostFrameCallback((_) {
                  if (!mounted) {
                    return;
                  }
                  widget.controller.deleteHistoryRecord(widget.record);
                });
              },
            ),
          ],
        );
      },
    );
  }
}

String? _historySubtitle({
  required HistoryRecord record,
  required String? projectPath,
  required bool isMissingProject,
}) {
  if (isMissingProject) {
    return '项目文件夹不存在';
  }
  if (projectPath != null && projectPath.isNotEmpty) {
    return projectPath;
  }

  final description = record.description?.trim();
  if (description != null && description.isNotEmpty) {
    return description;
  }

  final targetRoute = record.targetRoute?.trim();
  if (targetRoute != null && targetRoute.isNotEmpty) {
    return targetRoute;
  }
  return null;
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({required this.icon, required this.message});

  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: palette.textSecondary),
          const SizedBox(height: 12),
          Text(message, style: TextStyle(color: palette.textSecondary)),
        ],
      ),
    );
  }
}

String _formatHistoryTime(DateTime dateTime) {
  final local = dateTime.toLocal();
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  return '$hour:$minute';
}
