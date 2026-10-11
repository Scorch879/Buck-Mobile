import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/buck_glass_card.dart';

/// Figma "AI Advisory Banner" (2284:288) with Collapsed / Expanded states.
/// Tapping the header toggles between the two.
class AiAdvisoryBanner extends StatefulWidget {
  final List<String> insights;
  final VoidCallback? onOpenReport;
  final bool initiallyExpanded;

  const AiAdvisoryBanner({
    super.key,
    required this.insights,
    this.onOpenReport,
    this.initiallyExpanded = false,
  });

  @override
  State<AiAdvisoryBanner> createState() => _AiAdvisoryBannerState();
}

class _AiAdvisoryBannerState extends State<AiAdvisoryBanner> {
  late bool _expanded = widget.initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    return BuckGlassCard(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
        alignment: Alignment.topCenter,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          spacing: 10,
          children: [
            Semantics(
              button: true,
              expanded: _expanded,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => setState(() => _expanded = !_expanded),
                child: _header(),
              ),
            ),
            if (_expanded) ..._body(),
          ],
        ),
      ),
    );
  }

  Widget _header() {
    return Row(
      spacing: 10,
      children: [
        Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: const LinearGradient(
              colors: [
                AppColors.gradientOrangeStart,
                AppColors.gradientOrangeEnd,
              ],
            ),
          ),
          child: SvgPicture.asset('assets/icons/sparkles.svg'),
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 2,
            children: [
              Text(
                'AI INSIGHT',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.55,
                  color: AppColors.textAccent,
                ),
              ),
              Text(
                'Powered by Buck AI',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: _expanded
              ? Container(
                  key: const ValueKey('expanded-dot'),
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: AppColors.savingsGreen,
                    borderRadius: BorderRadius.circular(3),
                    boxShadow: const [
                      BoxShadow(
                        color: Color(0x664ADE80),
                        blurRadius: 4,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                )
              : SvgPicture.asset(
                  'assets/icons/caret_down.svg',
                  key: const ValueKey('collapsed-caret'),
                ),
        ),
      ],
    );
  }

  List<Widget> _body() {
    final bodyStyle = GoogleFonts.inter(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      height: 22 / 14,
      color: AppColors.textPrimary,
    );
    return [
      if (widget.insights.isEmpty)
        Text(
          'No insights yet. Generate them in the Financial Advisor on Buck web.',
          style: bodyStyle.copyWith(color: AppColors.textSecondary),
        ),
      for (final insight in widget.insights) Text(insight, style: bodyStyle),
      GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onOpenReport,
        child: Row(
          spacing: 8,
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.navBarIcon,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            Flexible(
              child: Text(
                'Tap for full financial report',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    ];
  }
}
