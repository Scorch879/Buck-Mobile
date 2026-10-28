import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';

import '../theme/app_colors.dart';
import '../theme/app_text_styles.dart';

/// Figma "Header / Mobile" (2236:452): menu button + welcome title.
///
/// Extends seamlessly behind the system status bar / display notch as a single
/// unified surface so there is no detached black bar or shadow seam at the top.
class BuckHeader extends StatelessWidget {
  final String title;
  final VoidCallback? onMenuTap;

  const BuckHeader({super.key, required this.title, this.onMenuTap});

  static const double height = 56;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.viewPaddingOf(context).top;

    return Container(
      height: topInset + height,
      decoration: const BoxDecoration(
        color: AppColors.navBarBg,
        border: Border(
          bottom: BorderSide(color: AppColors.headerBorder, width: 1),
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.glassCardGlow,
            blurRadius: 24,
            offset: Offset(0, 6),
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
    );
  }
}
