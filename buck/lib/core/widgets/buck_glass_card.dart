import 'package:flutter/material.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Translucent black card with orange stroke and soft orange glow,
/// shared by the dashboard / expenses cards in Figma.
class BuckGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;

  /// Figma glow blur in px (14 for drop-shadow cards, 28 for box-shadow cards).
  final double glowBlur;
  final Color background;
  final double? height;
  final double? minHeight;

  const BuckGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = 28,
    this.glowBlur = 14,
    this.background = AppColors.glassCardBg,
    this.height,
    this.minHeight,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      constraints:
          minHeight != null ? BoxConstraints(minHeight: minHeight!) : null,
      padding: padding,
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.glassCardBorder, width: 1),
        boxShadow: [
          BoxShadow(color: AppColors.glassCardGlow, blurRadius: glowBlur),
        ],
      ),
      child: child,
    );
  }
}

/// Small rounded "+99%" style pill on dark cyan.
class BuckTrendBadge extends StatelessWidget {
  final String text;

  const BuckTrendBadge({super.key, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.badgeCyanBgSoft,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(text, style: AppTextStyles.badgeSoft),
    );
  }
}
