import 'dart:async';
import 'dart:io';

import 'package:fluent_ui/fluent_ui.dart' hide Tooltip;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icons, Tooltip;
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

/// 保存桌面导航栏折叠状态，保证命名路由切换后新 Shell 复用同一份状态。
class FluentNavigationShellController extends GetxController {
  final isNavigationCollapsed = false.obs;

  PaneDisplayMode get desktopDisplayMode => isNavigationCollapsed.value
      ? PaneDisplayMode.compact
      : PaneDisplayMode.expanded;

  void toggleNavigationCollapsed() {
    isNavigationCollapsed.value = !isNavigationCollapsed.value;
  }
}

FluentNavigationShellController ensureFluentNavigationShellController() {
  if (Get.isRegistered<FluentNavigationShellController>()) {
    return Get.find<FluentNavigationShellController>();
  }
  return Get.put<FluentNavigationShellController>(
    FluentNavigationShellController(),
    permanent: true,
  );
}

/// 桌面应用统一外壳，负责自绘标题栏、窗口按钮和 Fluent NavigationView。
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

  static const List<FluentNavigationItem> _allItems = [
    ..._primaryItems,
    ..._footerItems,
  ];

  @override
  State<FluentAppShell> createState() => _FluentAppShellState();
}

class _FluentAppShellState extends State<FluentAppShell> {
  final _navigationViewKey = GlobalKey<NavigationViewState>();
  late final FluentNavigationShellController _navigationShellController;

  @override
  void initState() {
    super.initState();
    _navigationShellController = ensureFluentNavigationShellController();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showNavigation) {
      return NavigationView(
        titleBar: const FluentWindowTitleBar(),
        content: _ShellContentSurface(child: widget.child),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final useMinimalNavigation =
            constraints.maxWidth < FluentAppShell._compactNavigationBreakpoint;
        if (useMinimalNavigation) {
          return _buildNavigationView(
            displayMode: PaneDisplayMode.minimal,
            isCollapsed: true,
            useMinimalNavigation: true,
          );
        }

        return Obx(() {
          final isCollapsed =
              _navigationShellController.isNavigationCollapsed.value;
          return _buildNavigationView(
            displayMode: _navigationShellController.desktopDisplayMode,
            isCollapsed: isCollapsed,
            useMinimalNavigation: false,
          );
        });
      },
    );
  }

  Widget _buildNavigationView({
    required PaneDisplayMode displayMode,
    required bool isCollapsed,
    required bool useMinimalNavigation,
  }) {
    return NavigationView(
      key: _navigationViewKey,
      titleBar: FluentWindowTitleBar(
        leading: _NavigationToggleButton(
          isCollapsed: isCollapsed,
          onPressed: () => _handleNavigationToggle(useMinimalNavigation),
        ),
      ),
      pane: NavigationPane(
        selected: _selectedNavigationIndex(),
        onChanged: _openNavigationIndex,
        displayMode: displayMode,
        size: const NavigationPaneSize(
          compactWidth: 64,
          openWidth: FluentDesignTokens.navigationWidth,
          openMinWidth: 220,
          openMaxWidth: FluentDesignTokens.navigationWidth,
          headerHeight: 40,
        ),
        header: const Text('导航'),
        toggleButton: null,
        items: _buildNavigationPaneItems(FluentAppShell._primaryItems),
        footerItems: _buildNavigationPaneItems(FluentAppShell._footerItems),
      ),
      paneBodyBuilder: (_, _) => _ShellContentSurface(child: widget.child),
    );
  }

  List<NavigationPaneItem> _buildNavigationPaneItems(
    List<FluentNavigationItem> items,
  ) {
    return [
      for (final item in items)
        PaneItem(
          icon: Icon(item.icon, size: 18),
          title: Text(item.label),
          body: const SizedBox.shrink(),
        ),
    ];
  }

  int? _selectedNavigationIndex() {
    final currentRoute = Get.currentRoute.isEmpty
        ? AppRouteNames.home
        : Uri.tryParse(Get.currentRoute)?.path ?? Get.currentRoute;
    final index = FluentAppShell._allItems.indexWhere(
      (item) => item.route == currentRoute,
    );
    return index.isNegative ? null : index;
  }

  void _openNavigationIndex(int index) {
    if (index < 0 || index >= FluentAppShell._allItems.length) {
      return;
    }
    _openRoute(FluentAppShell._allItems[index].route);
  }

  void _handleNavigationToggle(bool useMinimalNavigation) {
    if (useMinimalNavigation) {
      _navigationViewKey.currentState?.togglePane();
      return;
    }
    _navigationShellController.toggleNavigationCollapsed();
  }

  void _openRoute(String route) {
    final currentRoute = Get.currentRoute.isEmpty
        ? AppRouteNames.home
        : Get.currentRoute;
    if (currentRoute == route || Get.testMode || Get.key.currentState == null) {
      return;
    }
    Get.offNamed(route);
  }
}

class _ShellContentSurface extends StatelessWidget {
  const _ShellContentSurface({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            palette.appBackground,
            palette.cardBackground.withValues(alpha: 0.82),
          ],
        ),
      ),
      child: child,
    );
  }
}

class FluentWindowTitleBar extends TitleBar {
  const FluentWindowTitleBar({this.leading, super.key})
    : super(height: FluentDesignTokens.titleBarHeight);

  final Widget? leading;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    return Acrylic(
      tint: palette.titleBarBackground,
      tintAlpha: 0.86,
      luminosityAlpha: 0.82,
      blurAmount: 20,
      child: DecoratedBox(
        decoration: BoxDecoration(
          border: Border(bottom: BorderSide(color: palette.border)),
        ),
        child: SizedBox(
          height: FluentDesignTokens.titleBarHeight,
          child: Row(
            children: [
              const SizedBox(width: 16),
              if (leading != null) ...[leading!, const SizedBox(width: 8)],
              const _AppMark(),
              const SizedBox(width: 10),
              Text(
                'YOLO 图片标注工具',
                style: FluentTheme.of(context).typography.caption?.copyWith(
                  color: palette.textPrimary,
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
                hoverColor: palette.closeHover,
                hoverIconColor: Colors.white,
                onPressed: () => unawaited(WindowControls.close()),
              ),
            ],
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
    this.hoverColor,
    this.hoverIconColor,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback onPressed;
  final Color? hoverColor;
  final Color? hoverIconColor;

  @override
  State<_WindowControlButton> createState() => _WindowControlButtonState();
}

class _WindowControlButtonState extends State<_WindowControlButton> {
  var _hovered = false;
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final palette = FluentDesignTokens.of(context);
    final hoverColor = widget.hoverColor ?? palette.fieldBackground;
    final iconColor = _hovered
        ? widget.hoverIconColor ?? palette.textPrimary
        : palette.textPrimary;

    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() {
        _hovered = false;
        _pressed = false;
      }),
      child: Tooltip(
        message: widget.tooltip,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (_) => setState(() => _pressed = true),
          onTapCancel: () => setState(() => _pressed = false),
          onTapUp: (_) => setState(() => _pressed = false),
          onTap: widget.onPressed,
          child: AnimatedScale(
            duration: theme.fasterAnimationDuration,
            curve: theme.animationCurve,
            scale: _pressed ? 0.96 : (_hovered ? 1.03 : 1),
            child: AnimatedContainer(
              duration: theme.fasterAnimationDuration,
              curve: theme.animationCurve,
              width: 46,
              height: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: _hovered ? hoverColor : Colors.transparent,
                borderRadius: BorderRadius.circular(
                  FluentDesignTokens.controlRadius,
                ),
              ),
              child: Icon(widget.icon, size: 16, color: iconColor),
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
        gradient: const LinearGradient(
          colors: [Color(0xFF0067C0), Color(0xFF60CDFF)],
        ),
        borderRadius: BorderRadius.circular(8),
        boxShadow: [
          BoxShadow(
            color: FluentDesignTokens.of(
              context,
            ).shadow.withValues(alpha: 0.32),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: const SizedBox(
        width: 28,
        height: 28,
        child: Icon(Icons.label_outline, color: Colors.white, size: 18),
      ),
    );
  }
}

class _NavigationToggleButton extends StatelessWidget {
  const _NavigationToggleButton({
    required this.isCollapsed,
    required this.onPressed,
  });

  final bool isCollapsed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: isCollapsed ? '展开导航' : '折叠导航',
      child: IconButton(
        icon: Icon(isCollapsed ? Icons.menu : Icons.menu_open, size: 18),
        onPressed: onPressed,
      ),
    );
  }
}
