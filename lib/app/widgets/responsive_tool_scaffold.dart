import 'package:flutter/material.dart';

import '../theme/fluent_design_tokens.dart';
import 'fluent_app_shell.dart';
import 'fluent_card.dart';

/// 工具页响应式断点，集中管理固定分栏切换阈值，避免页面里散落魔法数。
abstract final class ResponsiveBreakpoints {
  static const double twoPane = 840;
  static const double threePane = 1100;
  static const double annotation = 900;
}

/// 工具页中的一个功能面板，宽屏可指定固定宽度，窄屏会转换为纵向卡片。
class ResponsiveToolPane {
  const ResponsiveToolPane({
    required this.title,
    required this.child,
    this.icon,
    this.width,
  });

  final String title;
  final Widget child;
  final IconData? icon;
  final double? width;
}

/// 将工具页统一到 Pencil 设计稿的标题区、白色参数卡和深色预览卡布局。
class ResponsiveToolScaffold extends StatelessWidget {
  const ResponsiveToolScaffold({
    required this.title,
    required this.panes,
    this.description,
    this.breakpoint = ResponsiveBreakpoints.twoPane,
    super.key,
  }) : assert(panes.length >= 2, '至少需要两个面板才能形成响应式工具页');

  final String title;
  final String? description;
  final List<ResponsiveToolPane> panes;
  final double breakpoint;

  @override
  Widget build(BuildContext context) {
    return FluentAppShell(
      child: ColoredBox(
        color: FluentDesignTokens.appBackground,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final useStackedLayout = constraints.maxWidth < breakpoint;
            return ListView(
              padding: FluentDesignTokens.pagePadding,
              children: [
                FluentPageHeader(
                  title: title,
                  description: description ?? _defaultDescription(title),
                ),
                const SizedBox(height: FluentDesignTokens.pageGap),
                if (useStackedLayout)
                  _StackedToolLayout(panes: panes)
                else
                  _DesktopToolLayout(panes: panes),
              ],
            );
          },
        ),
      ),
    );
  }

  String _defaultDescription(String title) {
    return switch (title) {
      '视频抽帧' => '按帧间隔、目标目录和切分策略生成图片样本。',
      '自动预标注' => '选择模型、图片目录和写入策略，批量生成 YOLO 标签。',
      '模型验证' => '选择验证类型、模型和素材，检查检测结果与预览。',
      '格式转换' => '读取 data.yaml 与标签目录，校验类别映射后输出目标格式。',
      '数据集导出' => '按 train / val / test 比例切分并生成可复现实验包。',
      _ => '配置参数并查看任务运行状态。',
    };
  }
}

class _DesktopToolLayout extends StatelessWidget {
  const _DesktopToolLayout({required this.panes});

  final List<ResponsiveToolPane> panes;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          height: 420,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < panes.length; index += 1) ...[
                _DesktopPane(pane: panes[index], index: index),
                if (index < panes.length - 1) const SizedBox(width: 16),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _DesktopPane extends StatelessWidget {
  const _DesktopPane({required this.pane, required this.index});

  final ResponsiveToolPane pane;
  final int index;

  @override
  Widget build(BuildContext context) {
    final width = pane.width ?? (index == 0 ? 410.0 : null);
    final content = _ToolPaneCard(pane: pane, prominent: index > 0);
    if (width == null) {
      return Expanded(child: content);
    }
    return SizedBox(width: width, child: content);
  }
}

class _StackedToolLayout extends StatelessWidget {
  const _StackedToolLayout({required this.panes});

  final List<ResponsiveToolPane> panes;
  static const double _paneHeight = 420;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var index = 0; index < panes.length; index += 1) ...[
          SizedBox(
            height: _paneHeight,
            child: _ToolPaneCard(pane: panes[index], prominent: index > 0),
          ),
          if (index < panes.length - 1) const SizedBox(height: 14),
        ],
      ],
    );
  }
}

class _ToolPaneCard extends StatelessWidget {
  const _ToolPaneCard({required this.pane, required this.prominent});

  final ResponsiveToolPane pane;
  final bool prominent;

  @override
  Widget build(BuildContext context) {
    return FluentCard(
      padding: EdgeInsets.zero,
      color: prominent ? FluentDesignTokens.cardBackground : Colors.white,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                if (pane.icon != null) ...[
                  Icon(
                    pane.icon,
                    size: 18,
                    color: FluentDesignTokens.textSecondary,
                  ),
                  const SizedBox(width: 8),
                ],
                Text(
                  pane.title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1, color: FluentDesignTokens.border),
          Expanded(child: pane.child),
        ],
      ),
    );
  }
}
