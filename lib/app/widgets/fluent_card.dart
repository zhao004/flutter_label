import 'package:flutter/material.dart';

import '../theme/fluent_design_tokens.dart';

/// 复用设计稿白色卡片外观，避免各页面重复声明边框和圆角。
class FluentCard extends StatelessWidget {
  const FluentCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = FluentDesignTokens.cardBackground,
    this.borderColor = FluentDesignTokens.border,
    this.radius = FluentDesignTokens.cardRadius,
    super.key,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color color;
  final Color borderColor;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: color,
        border: Border.all(color: borderColor),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Padding(padding: padding, child: child),
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
                Text(title, style: Theme.of(context).textTheme.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  description,
                  style: const TextStyle(
                    color: FluentDesignTokens.textSecondary,
                    fontSize: 14,
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
