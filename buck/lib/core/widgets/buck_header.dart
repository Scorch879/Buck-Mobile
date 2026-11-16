import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_layout.dart';
import '../theme/app_text_styles.dart';

/// Figma "Header / Mobile" (2236:452): menu button + welcome title.
///
/// Always stays pinned at the top edge behind the status bar / notch with a
/// clean separator line at its bottom border so scrolling or reloading never
/// scrolls away or hides the header.
class BuckHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuTap;
  final VoidCallback? onSwipeOpenMenu;

  /// Retained for backward API compatibility; the header stays pinned so it
  /// never disappears during scrolling or pull-to-refresh reloading.
  final double collapseProgress;

  const BuckHeader({
    super.key,
    required this.title,
    this.onMenuTap,
    this.onSwipeOpenMenu,
    this.collapseProgress = 0.0,
  });

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    final topInset = AppLayout.topSafeInset(context);

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onHorizontalDragEnd: onSwipeOpenMenu == null
          ? null
          : (details) {
              if ((details.primaryVelocity ?? 0) > 220) {
                onSwipeOpenMenu!();
              }
            },
      child: Container(
        height: topInset + height,
        clipBehavior: Clip.hardEdge,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: palette.headerGradientColors,
            stops: const [0.0, 0.65, 1.0],
          ),
          border: Border(
            bottom: BorderSide(color: palette.headerDivider, width: 1),
          ),
          boxShadow: [
            BoxShadow(
              color: palette.glassCardGlow,
              blurRadius: 14,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        padding: EdgeInsets.only(top: topInset, left: 12, right: 16),
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onMenuTap,
                  child: Semantics(
                    button: true,
                    label: 'Menu',
                    child: SvgPicture.asset(
                      'assets/icons/menu.svg',
                      colorFilter: palette.isLight
                          ? const ColorFilter.mode(
                              Color(0xFFC85314),
                              BlendMode.srcIn,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: AppTextStyles.headerTitle.copyWith(
                    color: palette.headerText,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
