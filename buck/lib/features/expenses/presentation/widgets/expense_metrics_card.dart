import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/buck_glass_card.dart';

/// Figma "Card / Metrics" (2254:260): Wallet left · Total tracked · Average.
class ExpenseMetricsCard extends StatelessWidget {
  final String walletLeft;
  final String totalTracked;
  final String average;

  const ExpenseMetricsCard({
    super.key,
    required this.walletLeft,
    required this.totalTracked,
    required this.average,
  });

  @override
  Widget build(BuildContext context) {
    return BuckGlassCard(
      height: 96,
      radius: 20,
      glowBlur: 28,
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 15),
      child: Row(
        children: [
          Expanded(
            child: _Metric(
              icon: 'assets/icons/metric_wallet.svg',
              label: 'Wallet left',
              value: walletLeft,
            ),
          ),
          const _Divider(),
          Expanded(
            child: _Metric(
              icon: 'assets/icons/metric_expenses.svg',
              label: 'Total tracked',
              value: totalTracked,
            ),
          ),
          const _Divider(),
          Expanded(
            child: _Metric(
              icon: 'assets/icons/trending_up.svg',
              label: 'Average',
              value: average,
              gap: 4,
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String icon;
  final String label;
  final String value;
  final double gap;

  const _Metric({
    required this.icon,
    required this.label,
    required this.value,
    this.gap = 6,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 6,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: gap,
            children: [
              SvgPicture.asset(icon),
              Text(
                label,
                maxLines: 1,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(value, style: AppTextStyles.metricValue),
        ),
      ],
    );
  }
}

class _Divider extends StatelessWidget {
  const _Divider();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 1,
      height: 64,
      margin: const EdgeInsets.symmetric(horizontal: 15),
      color: AppColors.subtleDivider,
    );
  }
}
