import 'package:flutter/material.dart';

/// 工具页响应式断点，集中管理固定分栏切换阈值，避免页面里散落魔法数。
abstract final class ResponsiveBreakpoints {
  static const double twoPane = 840;
  static const double threePane = 1100;
  static const double annotation = 1024;
}

/// 工具页中的一个功能面板，宽屏可指定固定宽度，窄屏会转换为标签页。
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

/// 将桌面固定分栏自动降级为窄屏标签页，防止小窗口下 Row 固定宽度溢出。
class ResponsiveToolScaffold extends StatelessWidget {
  const ResponsiveToolScaffold({
    required this.title,
    required this.panes,
    this.breakpoint = ResponsiveBreakpoints.twoPane,
    this.actions,
    super.key,
  }) : assert(panes.length >= 2, '至少需要两个面板才能形成响应式工具页');

  final String title;
  final List<ResponsiveToolPane> panes;
  final double breakpoint;
  final List<Widget>? actions;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final useTabbedLayout = constraints.maxWidth < breakpoint;
        if (useTabbedLayout) {
          return DefaultTabController(
            length: panes.length,
            child: Scaffold(
              appBar: AppBar(
                title: Text(title),
                actions: actions,
                bottom: TabBar(
                  isScrollable: true,
                  tabs: [
                    for (final pane in panes)
                      Tab(icon: _tabIcon(pane.icon), text: pane.title),
                  ],
                ),
              ),
              body: TabBarView(
                children: [for (final pane in panes) pane.child],
              ),
            ),
          );
        }

        return Scaffold(
          appBar: AppBar(title: Text(title), actions: actions),
          body: Row(children: _buildDesktopChildren()),
        );
      },
    );
  }

  List<Widget> _buildDesktopChildren() {
    final children = <Widget>[];
    for (var index = 0; index < panes.length; index += 1) {
      final pane = panes[index];
      children.add(_buildDesktopPane(pane));
      if (index < panes.length - 1) {
        children.add(const VerticalDivider(width: 1));
      }
    }
    return children;
  }

  Widget _buildDesktopPane(ResponsiveToolPane pane) {
    final width = pane.width;
    if (width == null) {
      return Expanded(child: pane.child);
    }
    return SizedBox(width: width, child: pane.child);
  }

  Widget? _tabIcon(IconData? icon) {
    if (icon == null) {
      return null;
    }
    return Icon(icon);
  }
}
