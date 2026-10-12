import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Figma "Header / Mobile" (2236:452): menu button + welcome title.
class BuckHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuTap;

  const BuckHeader({super.key, required this.title, this.onMenuTap});

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: height,
      decoration: const BoxDecoration(
        color: AppColors.navBarBg,
        border: Border(
          bottom: BorderSide(color: AppColors.headerBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(color: AppColors.glassCardGlow, blurRadius: 28),
          BoxShadow(color: AppColors.glassCardGlow, blurRadius: 28),
        ],
      ),
      padding: const EdgeInsets.only(left: 12, right: 16),
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
    );
  }
}
