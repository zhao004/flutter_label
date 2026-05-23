import 'package:fluent_ui/fluent_ui.dart' as fluent;
import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../database/database.dart';
import '../../database/type/history_action_type.dart';
import '../../theme/fluent_design_tokens.dart';
import '../../widgets/fluent_app_shell.dart';
import '../../widgets/fluent_card.dart';
import 'home_controller.dart';

const int _maxHistoryPathDisplayLength = 48;
const double _historyActionIconSize = 38;
const double _historyHoverOverlayAlpha = 0.06;

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
            Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                KeyedSubtree(
                  key: const ValueKey('project-entry-card'),
                  child: _ProjectEntryCard(controller: controller),
                ),
                const SizedBox(height: 16),
                KeyedSubtree(
                  key: const ValueKey('history-panel-card'),
                  child: _HistoryPanel(controller: controller),
                ),
              ],
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
        mainAxisSize: MainAxisSize.min,
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
          const SizedBox(height: 18),
          _ProjectActionBar(controller: controller),
        ],
      ),
    );
  }
}

class _ProjectActionBar extends StatelessWidget {
  const _ProjectActionBar({required this.controller});

  final HomeController controller;

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

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [openButton, createButton],
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  const _HistoryPanel({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return FluentCard(
      padding: const EdgeInsets.all(20),
      hoverable: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: FluentDesignTokens.primaryBlue.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: FluentDesignTokens.primaryBlue.withValues(
                      alpha: 0.18,
                    ),
                  ),
                ),
                child: const Icon(
                  Icons.history_rounded,
                  color: FluentDesignTokens.primaryBlue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '项目历史',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '快速回到最近打开或创建的数据集项目',
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 12,
                      ),
                    ),
                  ],
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
                  description: '打开或创建项目后，历史记录将显示在此处',
                );
              }

              final groups = _groupHistoryRecords(records, DateTime.now());
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (
                    var groupIndex = 0;
                    groupIndex < groups.length;
                    groupIndex++
                  ) ...[
                    if (groupIndex > 0) const SizedBox(height: 16),
                    _HistorySectionHeader(group: groups[groupIndex]),
                    const SizedBox(height: 8),
                    DecoratedBox(
                      decoration: BoxDecoration(
                        color: palette.fieldBackground.withValues(alpha: 0.56),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: palette.fieldBorder.withValues(alpha: 0.46),
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(6),
                        child: Column(
                          children: [
                            for (
                              var recordIndex = 0;
                              recordIndex < groups[groupIndex].records.length;
                              recordIndex++
                            ) ...[
                              _HistoryTile(
                                controller: controller,
                                record: groups[groupIndex].records[recordIndex],
                              ),
                              if (recordIndex <
                                  groups[groupIndex].records.length - 1)
                                Divider(
                                  height: 1,
                                  thickness: 1,
                                  indent: 64,
                                  color: palette.fieldBorder.withValues(
                                    alpha: 0.34,
                                  ),
                                ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ],
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _HistorySectionHeader extends StatelessWidget {
  const _HistorySectionHeader({required this.group});

  final _HistoryGroup group;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return Row(
      children: [
        Text(
          group.label,
          style: TextStyle(
            color: palette.textPrimary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
          decoration: BoxDecoration(
            color: palette.selectedBackground.withValues(alpha: 0.72),
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            '${group.records.length} 条',
            style: TextStyle(color: palette.textSecondary, fontSize: 11),
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Divider(
            height: 1,
            thickness: 1,
            color: palette.fieldBorder.withValues(alpha: 0.32),
          ),
        ),
      ],
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
  var _hovered = false;

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
    final theme = fluent.FluentTheme.of(context);
    final record = widget.record;
    final isProjectRecord = widget.controller.isProjectHistoryRecord(record);
    final projectExists = widget.controller.historyProjectExists(record);
    final isMissingProject = isProjectRecord && !projectExists;
    final accentColor = isMissingProject
        ? palette.errorRed
        : _historyAccentColor(record.actionType, palette);
    final subtitle = _historySubtitle(
      record: record,
      projectPath: widget.controller.historyProjectPath(record),
      isMissingProject: isMissingProject,
    );
    final displaySubtitle = subtitle == null
        ? null
        : _compactHistoryPath(subtitle);
    final actionVisible = _hovered || isMissingProject;

    final tile = MouseRegion(
      hitTestBehavior: HitTestBehavior.translucent,
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
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
        child: AnimatedContainer(
          duration: theme.fastAnimationDuration,
          curve: theme.animationCurve,
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            color: _historyTileBackground(
              palette: palette,
              hovered: _hovered,
              isMissingProject: isMissingProject,
            ),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(
              color: _hovered || isMissingProject
                  ? accentColor.withValues(
                      alpha: isMissingProject ? 0.36 : 0.24,
                    )
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 4,
                height: 50,
                decoration: BoxDecoration(
                  color: accentColor.withValues(
                    alpha: isMissingProject ? 0.9 : 0.72,
                  ),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(width: 10),
              _HistoryActionBadge(
                actionType: record.actionType,
                color: accentColor,
                isMissingProject: isMissingProject,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            record.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: isMissingProject
                                  ? palette.errorRed
                                  : palette.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (isMissingProject) ...[
                          const SizedBox(width: 8),
                          _HistoryStatusPill(
                            label: '缺失',
                            color: palette.errorRed,
                          ),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    _HistoryMetaLine(
                      icon: Icons.schedule,
                      text: _formatHistoryTime(
                        record.createdAt,
                        DateTime.now(),
                      ),
                      color: isMissingProject
                          ? palette.errorRed
                          : palette.textSecondary,
                    ),
                    if (displaySubtitle != null) ...[
                      const SizedBox(height: 4),
                      Tooltip(
                        message: subtitle ?? '',
                        child: _HistoryMetaLine(
                          icon: isMissingProject
                              ? Icons.folder_off_outlined
                              : Icons.folder_outlined,
                          text: displaySubtitle,
                          color: isMissingProject
                              ? palette.errorRed
                              : palette.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              AnimatedSize(
                duration: theme.fasterAnimationDuration,
                curve: theme.animationCurve,
                child: actionVisible
                    ? const SizedBox(width: 10)
                    : const SizedBox.shrink(),
              ),
              _HistoryActions(
                controller: widget.controller,
                record: record,
                isProjectRecord: isProjectRecord,
                isMissingProject: isMissingProject,
                visible: actionVisible,
              ),
            ],
          ),
        ),
      ),
    );

    return fluent.FlyoutTarget(controller: _flyoutController, child: tile);
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

class _HistoryActions extends StatelessWidget {
  const _HistoryActions({
    required this.controller,
    required this.record,
    required this.isProjectRecord,
    required this.isMissingProject,
    required this.visible,
  });

  final HomeController controller;
  final HistoryRecord record;
  final bool isProjectRecord;
  final bool isMissingProject;
  final bool visible;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    final theme = fluent.FluentTheme.of(context);
    const compactActionsBreakpoint = 620.0;
    final canShowAllActions =
        MediaQuery.sizeOf(context).width >= compactActionsBreakpoint;
    if (!canShowAllActions && !visible) {
      return const SizedBox.shrink();
    }

    return AnimatedOpacity(
      duration: theme.fasterAnimationDuration,
      opacity: visible ? 1 : 0,
      child: IgnorePointer(
        ignoring: !visible,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (isProjectRecord && canShowAllActions) ...[
              _HistoryIconButton(
                key: ValueKey('history-open-${record.id}'),
                tooltip: isMissingProject ? '项目文件夹不存在' : '快速打开',
                icon: isMissingProject
                    ? Icons.error_outline
                    : Icons.open_in_new,
                color: isMissingProject
                    ? palette.errorRed
                    : palette.textSecondary,
                onPressed: () => controller.openHistoryProject(record),
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
              onPressed: () => controller.deleteHistoryRecord(record),
            ),
          ],
        ),
      ),
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

class _HistoryActionBadge extends StatelessWidget {
  const _HistoryActionBadge({
    required this.actionType,
    required this.color,
    required this.isMissingProject,
  });

  final HistoryActionType actionType;
  final Color color;
  final bool isMissingProject;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return Tooltip(
      message: actionType.label,
      child: Container(
        width: _historyActionIconSize,
        height: _historyActionIconSize,
        decoration: BoxDecoration(
          color: color.withValues(alpha: isMissingProject ? 0.12 : 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: color.withValues(alpha: isMissingProject ? 0.28 : 0.18),
          ),
        ),
        child: Icon(
          _historyActionIcon(actionType),
          size: 19,
          color: isMissingProject ? palette.errorRed : color,
        ),
      ),
    );
  }
}

class _HistoryMetaLine extends StatelessWidget {
  const _HistoryMetaLine({
    required this.icon,
    required this.text,
    required this.color,
  });

  final IconData icon;
  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 13, color: color),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ),
      ],
    );
  }
}

class _HistoryStatusPill extends StatelessWidget {
  const _HistoryStatusPill({required this.label, required this.color});

  final String label;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
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

List<_HistoryGroup> _groupHistoryRecords(
  List<HistoryRecord> records,
  DateTime now,
) {
  final groups = <String, List<HistoryRecord>>{};
  for (final record in records) {
    final label = _historyGroupLabel(record.createdAt, now);
    groups.putIfAbsent(label, () => <HistoryRecord>[]).add(record);
  }

  return groups.entries
      .map((entry) => _HistoryGroup(label: entry.key, records: entry.value))
      .toList(growable: false);
}

String _historyGroupLabel(DateTime dateTime, DateTime now) {
  final local = dateTime.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final recordDay = DateTime(local.year, local.month, local.day);
  final dayOffset = today.difference(recordDay).inDays;
  if (dayOffset <= 0) {
    return '今天';
  }
  if (dayOffset == 1) {
    return '昨天';
  }
  if (dayOffset < 7) {
    return '近 7 天';
  }
  return '更早';
}

Color _historyAccentColor(
  HistoryActionType actionType,
  FluentDesignPalette palette,
) {
  return switch (actionType) {
    HistoryActionType.createDatasetProject => palette.successGreen,
    HistoryActionType.openProjectFile => const Color(0xFF8764B8),
    HistoryActionType.openImagesDirectory => const Color(0xFFD83B01),
    HistoryActionType.openDatasetProject ||
    HistoryActionType.openFeaturePage => FluentDesignTokens.primaryBlue,
  };
}

IconData _historyActionIcon(HistoryActionType actionType) {
  return switch (actionType) {
    HistoryActionType.openImagesDirectory => Icons.photo_library_outlined,
    HistoryActionType.openProjectFile => Icons.description_outlined,
    HistoryActionType.openDatasetProject => Icons.folder_open,
    HistoryActionType.createDatasetProject => Icons.create_new_folder_outlined,
    HistoryActionType.openFeaturePage => Icons.explore_outlined,
  };
}

Color _historyTileBackground({
  required FluentDesignPalette palette,
  required bool hovered,
  required bool isMissingProject,
}) {
  if (isMissingProject) {
    return palette.errorRed.withValues(alpha: hovered ? 0.12 : 0.08);
  }
  return hovered
      ? palette.textPrimary.withValues(alpha: _historyHoverOverlayAlpha)
      : Colors.transparent;
}

class _HistoryGroup {
  const _HistoryGroup({required this.label, required this.records});

  final String label;
  final List<HistoryRecord> records;
}

class _HistoryMessage extends StatelessWidget {
  const _HistoryMessage({
    required this.icon,
    required this.message,
    this.description,
  });

  final IconData icon;
  final String message;
  final String? description;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: palette.selectedBackground.withValues(alpha: 0.72),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: palette.fieldBorder.withValues(alpha: 0.42),
              ),
            ),
            child: Icon(icon, size: 30, color: palette.textSecondary),
          ),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              color: palette.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          if (description != null) ...[
            const SizedBox(height: 6),
            Text(
              description!,
              textAlign: TextAlign.center,
              style: TextStyle(color: palette.textSecondary, fontSize: 12),
            ),
          ],
        ],
      ),
    );
  }
}

String _formatHistoryTime(DateTime dateTime, DateTime now) {
  final local = dateTime.toLocal();
  final today = DateTime(now.year, now.month, now.day);
  final recordDay = DateTime(local.year, local.month, local.day);
  final dayOffset = today.difference(recordDay).inDays;
  final hour = local.hour.toString().padLeft(2, '0');
  final minute = local.minute.toString().padLeft(2, '0');
  if (dayOffset == 0) {
    return '今天 $hour:$minute';
  }
  if (dayOffset == 1) {
    return '昨天 $hour:$minute';
  }

  final month = local.month.toString().padLeft(2, '0');
  final day = local.day.toString().padLeft(2, '0');
  return '$month-$day $hour:$minute';
}
