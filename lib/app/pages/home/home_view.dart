import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../database/database.dart';
import '../../theme/fluent_design_tokens.dart';
import '../../widgets/fluent_app_shell.dart';
import '../../widgets/fluent_card.dart';
import 'home_controller.dart';

const double _homeDesktopBreakpoint = 900;
const double _desktopHomeCardHeight = 432;
const double _historyListHeight = 360;
const int _maxHistoryPathDisplayLength = 48;

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
                final useTwoColumns =
                    constraints.maxWidth >= _homeDesktopBreakpoint;
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
                return _DesktopHomeLayout(controller: controller);
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _DesktopHomeLayout extends StatelessWidget {
  const _DesktopHomeLayout({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: _desktopHomeCardHeight,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            flex: 2,
            child: KeyedSubtree(
              key: const ValueKey('project-entry-card'),
              child: _ProjectEntryCard(
                controller: controller,
                pinActionsToBottom: true,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 3,
            child: KeyedSubtree(
              key: const ValueKey('history-panel-card'),
              child: _HistoryPanel(controller: controller),
            ),
          ),
        ],
      ),
    );
  }
}

class _ProjectEntryCard extends StatelessWidget {
  const _ProjectEntryCard({
    required this.controller,
    this.pinActionsToBottom = false,
  });

  final HomeController controller;
  final bool pinActionsToBottom;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return FluentCard(
      padding: const EdgeInsets.all(20),
      hoverable: true,
      child: Column(
        mainAxisSize: pinActionsToBottom ? MainAxisSize.max : MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '数据集项目',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            '选择或新建包含 data.yaml 的 YOLO 数据集项目，进入图片标注并自动维护标准目录。',
            style: TextStyle(color: palette.textSecondary, fontSize: 13),
          ),
          if (pinActionsToBottom)
            const Spacer()
          else
            const SizedBox(height: 18),
          _ProjectActionBar(
            controller: controller,
            expandButtons: pinActionsToBottom,
          ),
        ],
      ),
    );
  }
}

class _ProjectActionBar extends StatelessWidget {
  const _ProjectActionBar({
    required this.controller,
    required this.expandButtons,
  });

  final HomeController controller;
  final bool expandButtons;

  @override
  Widget build(BuildContext context) {
    final openButton = Obx(
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
    );
    final createButton = Obx(
      () => SizedBox(
        height: 38,
        child: OutlinedButton.icon(
          onPressed: controller.isPicking.value
              ? null
              : controller.createDatasetProject,
          icon: const Icon(Icons.create_new_folder_outlined, size: 18),
          label: const Text('新建数据集项目'),
        ),
      ),
    );

    if (expandButtons) {
      return Row(
        children: [
          Expanded(child: openButton),
          const SizedBox(width: 12),
          Expanded(child: createButton),
        ],
      );
    }
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [openButton, createButton],
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
              return SizedBox(height: _historyListHeight, child: listView);
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
    final displaySubtitle = subtitle == null
        ? null
        : _compactHistoryPath(subtitle);

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
                      if (displaySubtitle != null) ...[
                        const SizedBox(height: 3),
                        Tooltip(
                          message: subtitle ?? '',
                          child: Text(
                            displaySubtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isMissingProject
                                  ? palette.errorRed
                                  : palette.textSecondary,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                if (isProjectRecord) ...[
                  _HistoryIconButton(
                    key: ValueKey('history-open-${record.id}'),
                    tooltip: isMissingProject ? '项目文件夹不存在' : '快速打开',
                    icon: isMissingProject
                        ? Icons.error_outline
                        : Icons.open_in_new,
                    color: isMissingProject
                        ? palette.errorRed
                        : palette.textSecondary,
                    onPressed: () =>
                        widget.controller.openHistoryProject(record),
                  ),
                  const SizedBox(width: 4),
                ],
                _HistoryIconButton(
                  key: ValueKey('history-delete-${record.id}'),
                  tooltip: '删除此记录',
                  icon: Icons.delete_outline,
                  color: isMissingProject
                      ? palette.errorRed
                      : palette.textSecondary,
                  onPressed: () =>
                      widget.controller.deleteHistoryRecord(record),
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

class _HistoryIconButton extends StatelessWidget {
  const _HistoryIconButton({
    required this.tooltip,
    required this.icon,
    required this.color,
    required this.onPressed,
    super.key,
  });

  final String tooltip;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: IconButton(
        constraints: const BoxConstraints.tightFor(width: 32, height: 32),
        padding: EdgeInsets.zero,
        iconSize: 18,
        onPressed: onPressed,
        icon: Icon(icon, color: color),
      ),
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

String _compactHistoryPath(String value) {
  final text = value.trim();
  if (text.length <= _maxHistoryPathDisplayLength) {
    return text;
  }

  const windowsSeparator = '\\';
  final separator = text.contains(windowsSeparator) ? windowsSeparator : '/';
  final parts = text.split(RegExp(r'[\\/]')).where((part) => part.isNotEmpty);
  final segments = parts.toList(growable: false);
  if (segments.length < 4) {
    return text;
  }

  final head = segments.first;
  final tail = segments.skip(segments.length - 2).join(separator);
  return '$head$separator...$separator$tail';
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
