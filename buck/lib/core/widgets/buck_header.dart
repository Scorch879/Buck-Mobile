import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_layout.dart';
import '../theme/app_text_styles.dart';

/// Figma "Header / Mobile" (2236:452): menu button + welcome title.
///
/// Extends seamlessly behind the system status bar / display notch as a single
/// unified surface so there is no detached black bar or shadow seam at the top.
class BuckHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuTap;
  final VoidCallback? onSwipeOpenMenu;

  const BuckHeader({
    super.key,
    required this.title,
    this.onMenuTap,
    this.onSwipeOpenMenu,
  });

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
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
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            Color(0xFF2B1309),
            Color(0xB8261108),
            Color(0x66220F07),
          ],
          stops: [0.0, 0.65, 1.0],
        ),
        border: Border(
          bottom: BorderSide(color: Color(0x18E66820), width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: Color(0x14FF6A13),
            blurRadius: 18,
            offset: Offset(0, 4),
          ),
        ],
      ),
      padding: EdgeInsets.only(top: topInset, left: 12, right: 16),
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
                child: SvgPicture.asset('assets/icons/menu.svg'),
              ),
            ),
          ),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              title,
              style: AppTextStyles.headerTitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
      ),
    );
  }
}
