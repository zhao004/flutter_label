import 'package:flutter/material.dart';

import '../theme/fluent_design_tokens.dart';
import 'fluent_card.dart';

/// 任务页通用路径选择字段，统一路径展示、禁用态和选择按钮布局。
class TaskPathField extends StatelessWidget {
  const TaskPathField({
    required this.label,
    required this.value,
    required this.onPick,
    this.enabled = true,
    this.placeholder = '未选择',
    this.buttonLabel = '选择',
    super.key,
  });

  final String label;
  final String value;
  final Future<void> Function() onPick;
  final bool enabled;
  final String placeholder;
  final String buttonLabel;

  @override
  Widget build(BuildContext context) {
    final visibleValue = value.trim().isEmpty ? placeholder : value;
    return LayoutBuilder(
      builder: (context, constraints) {
        final field = InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            border: const OutlineInputBorder(),
          ),
          child: SelectableText(visibleValue, maxLines: 1),
        );
        final button = OutlinedButton(
          onPressed: enabled ? onPick : null,
          child: Text(buttonLabel),
        );

        if (constraints.maxWidth < 360) {
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [field, const SizedBox(height: 8), button],
          );
        }

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(child: field),
            const SizedBox(width: 8),
            button,
          ],
        );
      },
    );
  }
}

/// 任务参数面板的统一滚动容器，集中控制边距和顶层分组间距。
class TaskSettingsPanel extends StatelessWidget {
  const TaskSettingsPanel({
    required this.children,
    this.padding = const EdgeInsets.all(16),
    this.gap = 16,
    super.key,
  }) : assert(gap >= 0, 'gap 不能为负数');

  final List<Widget> children;
  final EdgeInsetsGeometry padding;
  final double gap;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _spacedChildren(children, gap),
      ),
    );
  }
}

/// 任务参数分组卡片，用浅底色把路径、参数和选项分区，降低长表单的扫描成本。
class TaskSettingsSection extends StatelessWidget {
  const TaskSettingsSection({
    required this.title,
    required this.children,
    this.description,
    this.gap = 12,
    super.key,
  }) : assert(gap >= 0, 'gap 不能为负数');

  final String title;
  final String? description;
  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final description = this.description;
    final palette = FluentDesignTokens.of(context);
    return FluentCard(
      color: palette.fieldBackground,
      borderColor: palette.fieldBorder,
      radius: FluentDesignTokens.controlRadius,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          if (description != null && description.trim().isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              description,
              style: TextStyle(color: palette.textSecondary, fontSize: 13),
            ),
          ],
          if (children.isNotEmpty) ...[
            const SizedBox(height: 12),
            ..._spacedChildren(children, gap),
          ],
        ],
      ),
    );
  }
}

/// 任务操作区，统一主按钮、停止按钮、进度和结果状态的视觉承载。
class TaskActionArea extends StatelessWidget {
  const TaskActionArea({required this.children, this.gap = 12, super.key})
    : assert(gap >= 0, 'gap 不能为负数');

  final List<Widget> children;
  final double gap;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return FluentCard(
      color: palette.cardBackground,
      borderColor: FluentDesignTokens.primaryBlue.withValues(alpha: 0.18),
      radius: FluentDesignTokens.controlRadius,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: _spacedChildren(children, gap),
      ),
    );
  }
}

/// 任务页通用日志面板，空日志时给出明确空态，避免页面复制 ListView 结构。
class TaskLogPanel extends StatelessWidget {
  const TaskLogPanel({
    required this.title,
    required this.logs,
    this.emptyMessage = '暂无任务日志',
    super.key,
  });

  final String title;
  final List<String> logs;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Text(title, style: Theme.of(context).textTheme.titleMedium),
        ),
        Divider(height: 1, color: palette.border),
        Expanded(
          child: logs.isEmpty
              ? _TaskLogEmpty(message: emptyMessage)
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: logs.length,
                  itemBuilder: (context, index) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: SelectableText(logs[index]),
                  ),
                ),
        ),
      ],
    );
  }
}

/// 轻量结果卡，用于展示批处理完成后的统计或当前任务状态。
class TaskResultCard extends StatelessWidget {
  const TaskResultCard({
    required this.title,
    required this.message,
    this.icon = Icons.fact_check_outlined,
    this.color,
    this.borderColor,
    super.key,
  });

  final String title;
  final String message;
  final IconData icon;
  final Color? color;
  final Color? borderColor;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return FluentCard(
      color: color ?? palette.fieldBackground,
      borderColor: borderColor ?? palette.fieldBorder,
      radius: FluentDesignTokens.controlRadius,
      padding: const EdgeInsets.all(14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: FluentDesignTokens.primaryBlue),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(color: palette.textSecondary, fontSize: 13),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _TaskLogEmpty extends StatelessWidget {
  const _TaskLogEmpty({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.article_outlined, size: 40, color: palette.textSecondary),
          const SizedBox(height: 10),
          Text(message, style: TextStyle(color: palette.textSecondary)),
        ],
      ),
    );
  }
}

List<Widget> _spacedChildren(List<Widget> children, double gap) {
  if (children.isEmpty) {
    return const [];
  }

  final spaced = <Widget>[];
  for (var index = 0; index < children.length; index += 1) {
    if (index > 0 && gap > 0) {
      spaced.add(SizedBox(height: gap));
    }
    spaced.add(children[index]);
  }
  return spaced;
}
