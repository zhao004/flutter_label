import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:window_manager/window_manager.dart';

import '../routes/app_route_names.dart';
import '../theme/fluent_design_tokens.dart';

class FluentNavigationItem {
  const FluentNavigationItem({
    required this.route,
    required this.label,
    required this.icon,
  });

  final String route;
  final String label;
  final IconData icon;
}

/// 桌面应用统一外壳，负责自绘标题栏、窗口按钮和左侧 Fluent 导航。
class FluentAppShell extends StatefulWidget {
  const FluentAppShell({
    required this.child,
    this.showNavigation = true,
    super.key,
  });

  final Widget child;
  final bool showNavigation;
  static const double _compactNavigationBreakpoint = 760;

  static const List<FluentNavigationItem> _primaryItems = [
    FluentNavigationItem(
      route: AppRouteNames.home,
      label: '工作台',
      icon: Icons.dashboard_outlined,
    ),
    FluentNavigationItem(
      route: AppRouteNames.videoExtract,
      label: '视频抽帧',
      icon: Icons.movie_outlined,
    ),
    FluentNavigationItem(
      route: AppRouteNames.autoLabel,
      label: '自动预标注',
      icon: Icons.bolt_outlined,
    ),
    FluentNavigationItem(
      route: AppRouteNames.modelVerify,
      label: '模型验证',
      icon: Icons.analytics_outlined,
    ),
    FluentNavigationItem(
      route: AppRouteNames.formatConvert,
      label: '格式转换',
      icon: Icons.sync_alt,
    ),
    FluentNavigationItem(
      route: AppRouteNames.datasetExport,
      label: '数据集导出',
      icon: Icons.download_outlined,
    ),
  ];

  static const List<FluentNavigationItem> _footerItems = [
    FluentNavigationItem(
      route: AppRouteNames.runLog,
      label: '运行日志',
      icon: Icons.article_outlined,
    ),
    FluentNavigationItem(
      route: AppRouteNames.settings,
      label: '配置',
      icon: Icons.settings_outlined,
    ),
  ];

  @override
  State<FluentAppShell> createState() => _FluentAppShellState();
}

class _FluentAppShellState extends State<FluentAppShell> {
  var _isNavigationCollapsed = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: FluentDesignTokens.appBackground,
      body: Column(
        children: [
          const FluentWindowTitleBar(),
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) {
                if (!widget.showNavigation ||
                    constraints.maxWidth <
                        FluentAppShell._compactNavigationBreakpoint) {
                  return widget.child;
                }
                return Row(
                  children: [
                    FluentNavigationPane(
                      primaryItems: FluentAppShell._primaryItems,
                      footerItems: FluentAppShell._footerItems,
                      isCollapsed: _isNavigationCollapsed,
                      onToggleCollapsed: _toggleNavigationCollapsed,
                    ),
                    Expanded(child: widget.child),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  void _toggleNavigationCollapsed() {
    setState(() {
      _isNavigationCollapsed = !_isNavigationCollapsed;
    });
  }
}

class FluentWindowTitleBar extends StatelessWidget {
  const FluentWindowTitleBar({super.key});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FluentDesignTokens.titleBarBackground,
        border: Border(bottom: BorderSide(color: FluentDesignTokens.border)),
      ),
      child: SizedBox(
        height: FluentDesignTokens.titleBarHeight,
        child: Row(
          children: [
            const SizedBox(width: 16),
            const _AppMark(),
            const SizedBox(width: 10),
            const Text(
              'YOLO 图片标注工具',
              style: TextStyle(
                color: FluentDesignTokens.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(width: 16),
            const Expanded(child: _WindowDragArea()),
            _WindowControlButton(
              tooltip: '最小化',
              icon: Icons.remove,
              onPressed: () => unawaited(WindowControls.minimize()),
            ),
            _MaximizeButton(),
            _WindowControlButton(
              tooltip: '关闭',
              icon: Icons.close,
              hoverColor: FluentDesignTokens.closeHover,
              hoverIconColor: Colors.white,
              onPressed: () => unawaited(WindowControls.close()),
            ),
          ],
        ),
      ),
    );
  }
}

class FluentNavigationPane extends StatelessWidget {
  const FluentNavigationPane({
    required this.primaryItems,
    required this.footerItems,
    required this.isCollapsed,
    required this.onToggleCollapsed,
    super.key,
  });

  final List<FluentNavigationItem> primaryItems;
  final List<FluentNavigationItem> footerItems;
  final bool isCollapsed;
  final VoidCallback onToggleCollapsed;
  static const double _collapsedWidth = 64;
  static const double _expandedContentThreshold = 160;
  static const EdgeInsets _collapsedPadding = EdgeInsets.symmetric(
    horizontal: 8,
    vertical: 10,
  );

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: FluentDesignTokens.navigationBackground,
        border: Border(right: BorderSide(color: FluentDesignTokens.border)),
      ),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        curve: Curves.easeOutCubic,
        width: isCollapsed
            ? _collapsedWidth
            : FluentDesignTokens.navigationWidth,
        child: Padding(
          padding: isCollapsed
              ? _collapsedPadding
              : FluentDesignTokens.navigationPadding,
          child: LayoutBuilder(
            builder: (context, constraints) {
              final useCollapsedLayout =
                  isCollapsed ||
                  constraints.maxWidth < _expandedContentThreshold;
              return Column(
                children: [
                  _NavigationHeader(
                    isCollapsed: useCollapsedLayout,
                    onToggleCollapsed: onToggleCollapsed,
                  ),
                  const SizedBox(height: 8),
                  for (final item in primaryItems)
                    _NavigationTile(
                      item: item,
                      isCollapsed: useCollapsedLayout,
                    ),
                  const Spacer(),
                  for (final item in footerItems)
                    _NavigationTile(
                      item: item,
                      isCollapsed: useCollapsedLayout,
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// 将原生窗口调用隔离，测试环境不会因为缺少桌面窗口通道而失败。
abstract final class WindowControls {
  static bool get isSupportedDesktop {
    if (kIsWeb || _isFlutterTestBinding()) {
      return false;
    }
    return Platform.isWindows || Platform.isLinux || Platform.isMacOS;
  }

  static Future<void> minimize() async {
    if (!isSupportedDesktop) {
      return;
    }
    await windowManager.minimize();
  }

  static Future<void> toggleMaximize() async {
    if (!isSupportedDesktop) {
      return;
    }
    if (await windowManager.isMaximized()) {
      await windowManager.unmaximize();
    } else {
      await windowManager.maximize();
    }
  }

  static Future<void> close() async {
    if (!isSupportedDesktop) {
      return;
    }
    await windowManager.close();
  }

  static Future<void> startDragging() async {
    if (!isSupportedDesktop) {
      return;
    }
    await windowManager.startDragging();
  }

  static bool _isFlutterTestBinding() {
    final bindingType = WidgetsBinding.instance.runtimeType.toString();
    return bindingType.contains('TestWidgetsFlutterBinding');
  }
}

class _WindowDragArea extends StatelessWidget {
  const _WindowDragArea();

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onPanStart: (_) => unawaited(WindowControls.startDragging()),
      onDoubleTap: () => unawaited(WindowControls.toggleMaximize()),
      child: const SizedBox.expand(),
    );
  }
}

class _MaximizeButton extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return _WindowControlButton(
      tooltip: '最大化或还原',
      icon: Icons.crop_square,
      onPressed: () => unawaited(WindowControls.toggleMaximize()),
    );
  }
}

class _WindowControlButton extends StatefulWidget {
  const _WindowControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.hoverColor = const Color(0xFFEDEDED),
    this.hoverIconColor = FluentDesignTokens.textPrimary,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color hoverColor;
  final Color hoverIconColor;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: Tooltip(
        message: widget.tooltip,
        child: InkWell(
          borderRadius: BorderRadius.circular(FluentDesignTokens.controlRadius),
          onTap: widget.onPressed,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 120),
            width: 46,
            height: 32,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: _hovered ? widget.hoverColor : Colors.transparent,
              borderRadius: BorderRadius.circular(
                FluentDesignTokens.controlRadius,
              ),
            ),
            child: Icon(
              widget.icon,
              size: 16,
              color: _hovered
                  ? widget.hoverIconColor
                  : FluentDesignTokens.textPrimary,
            ),
          ),
        ),
      ),
    );
  }
}

class _AppMark extends StatelessWidget {
  const _AppMark();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: FluentDesignTokens.primaryBlue,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const SizedBox(
        width: 28,
        height: 28,
        child: Icon(Icons.label_outline, color: Colors.white, size: 18),
      ),
    );
  }
}

class _NavigationHeader extends StatelessWidget {
  const _NavigationHeader({
    required this.isCollapsed,
    required this.onToggleCollapsed,
  });

  final bool isCollapsed;
  final VoidCallback onToggleCollapsed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 32,
      child: Row(
        mainAxisAlignment: isCollapsed
            ? MainAxisAlignment.center
            : MainAxisAlignment.start,
        children: [
          Tooltip(
            message: isCollapsed ? '展开导航' : '折叠导航',
            child: InkWell(
              borderRadius: BorderRadius.circular(
                FluentDesignTokens.controlRadius,
              ),
              onTap: onToggleCollapsed,
              child: SizedBox.square(
                dimension: 32,
                child: Icon(
                  isCollapsed ? Icons.menu : Icons.menu_open,
                  size: 18,
                  color: FluentDesignTokens.textSecondary,
                ),
              ),
            ),
          ),
          if (!isCollapsed) ...[
            const SizedBox(width: 10),
            const Text(
              '导航',
              style: TextStyle(
                color: FluentDesignTokens.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _NavigationTile extends StatelessWidget {
  const _NavigationTile({required this.item, required this.isCollapsed});

  final FluentNavigationItem item;
  final bool isCollapsed;

  @override
  Widget build(BuildContext context) {
    final currentRoute = Get.currentRoute.isEmpty
        ? AppRouteNames.home
        : Get.currentRoute;
    final selected = currentRoute == item.route;
    final contentColor = selected
        ? FluentDesignTokens.primaryBlue
        : FluentDesignTokens.textSecondary;
    if (isCollapsed) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 5),
        child: Tooltip(
          message: item.label,
          child: InkWell(
            borderRadius: BorderRadius.circular(
              FluentDesignTokens.controlRadius,
            ),
            onTap: selected ? null : () => _openRoute(item.route),
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: selected
                    ? FluentDesignTokens.selectedBackground
                    : FluentDesignTokens.navigationBackground,
                borderRadius: BorderRadius.circular(
                  FluentDesignTokens.controlRadius,
                ),
              ),
              child: SizedBox(
                height: 40,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          color: selected
                              ? FluentDesignTokens.primaryBlue
                              : FluentDesignTokens.navigationBackground,
                          borderRadius: BorderRadius.circular(2),
                        ),
                        child: const SizedBox(width: 3, height: 20),
                      ),
                    ),
                    Icon(item.icon, size: 18, color: contentColor),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: InkWell(
        borderRadius: BorderRadius.circular(FluentDesignTokens.controlRadius),
        onTap: selected ? null : () => _openRoute(item.route),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: selected
                ? FluentDesignTokens.selectedBackground
                : FluentDesignTokens.navigationBackground,
            borderRadius: BorderRadius.circular(
              FluentDesignTokens.controlRadius,
            ),
          ),
          child: SizedBox(
            height: 34,
            child: Row(
              children: [
                const SizedBox(width: 2),
                DecoratedBox(
                  decoration: BoxDecoration(
                    color: selected
                        ? FluentDesignTokens.primaryBlue
                        : FluentDesignTokens.navigationBackground,
                    borderRadius: BorderRadius.circular(2),
                  ),
                  child: const SizedBox(width: 3, height: 20),
                ),
                const SizedBox(width: 8),
                Icon(item.icon, size: 18, color: contentColor),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    item.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: FluentDesignTokens.textPrimary,
                      fontSize: 13,
                      fontWeight: selected ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _openRoute(String route) {
    if (Get.testMode || Get.key.currentState == null) {
      return;
    }
    Get.offNamed(route);
  }
}
