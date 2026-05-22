import 'dart:ui';

import 'package:fluent_ui/fluent_ui.dart';

import '../theme/fluent_design_tokens.dart';

/// Fluent 风格玻璃卡片，统一圆角、描边、轻阴影和悬停反馈。
class FluentCard extends StatefulWidget {
  const FluentCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
    this.borderColor,
    this.radius = FluentDesignTokens.cardRadius,
    this.hoverable = false,
    this.blurSigma = 14,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  final Color? borderColor;
  final double radius;
  final bool hoverable;
  final double blurSigma;

  @override
  State<FluentCard> createState() => _FluentCardState();
}

class _FluentCardState extends State<FluentCard> {
  var _hovered = false;

  @override
  Widget build(BuildContext context) {
    final palette = FluentDesignTokens.of(context);
    final theme = FluentTheme.of(context);
    final radius = BorderRadius.circular(widget.radius);
    final baseColor = widget.color ?? palette.glassFill;
    final hoverColor = widget.color ?? palette.glassStrongFill;
    final borderColor = widget.borderColor ?? palette.border;
    final scale = widget.hoverable && _hovered ? 1.01 : 1.0;

    final card = AnimatedScale(
      duration: theme.fasterAnimationDuration,
      curve: theme.animationCurve,
      scale: scale,
      child: AnimatedContainer(
        duration: theme.fastAnimationDuration,
        curve: theme.animationCurve,
        decoration: BoxDecoration(
          color: _hovered ? hoverColor : baseColor,
          border: Border.all(color: borderColor.withValues(alpha: 0.82)),
          borderRadius: radius,
          boxShadow: [
            BoxShadow(
              color: palette.shadow.withValues(alpha: _hovered ? 0.38 : 0.24),
              blurRadius: _hovered ? 24 : 16,
              offset: Offset(0, _hovered ? 8 : 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: radius,
          child: BackdropFilter(
            filter: ImageFilter.blur(
              sigmaX: widget.blurSigma,
              sigmaY: widget.blurSigma,
            ),
            child: Padding(padding: widget.padding, child: widget.child),
          ),
        ),
      ),
    );

    if (!widget.hoverable) {
      return card;
    }
    return MouseRegion(
      onEnter: (_) => setState(() => _hovered = true),
      onExit: (_) => setState(() => _hovered = false),
      child: card,
    );
  }
}

/// 页面顶部标题区，统一实现标题、说明和右侧主操作。
class FluentPageHeader extends StatelessWidget {
  const FluentPageHeader({
    required this.title,
    required this.description,
    this.action,
    super.key,
  });

  final String title;
  final String description;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final theme = FluentTheme.of(context);
    final palette = FluentDesignTokens.of(context);
    return ConstrainedBox(
      constraints: const BoxConstraints(minHeight: 78),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.typography.title?.copyWith(
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: theme.typography.body?.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (action != null) ...[const SizedBox(width: 16), action!],
        ],
      ),
    );
  }
}
