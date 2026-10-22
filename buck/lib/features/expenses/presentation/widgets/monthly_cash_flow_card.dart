import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/widgets/buck_glass_card.dart';

/// Figma "Monthly Cash Flow Card" (2277:364).
class MonthlyCashFlowCard extends StatelessWidget {
  final String monthLabel;
  final String income;
  final String incomeDelta;
  final String expenses;
  final String expensesDelta;
  final String netSavings;

  /// Share of income saved, 0–1. Drives the split bar and percent labels.
  final double savedRatio;

  /// False until income is recorded server-side; the savings bar then
  /// shows a neutral track and a hint instead of percentages.
  final bool incomeTracked;

  const MonthlyCashFlowCard({
    super.key,
    required this.monthLabel,
    required this.income,
    required this.incomeDelta,
    required this.expenses,
    required this.expensesDelta,
    required this.netSavings,
    required this.savedRatio,
    this.incomeTracked = true,
  });

  @override
  Widget build(BuildContext context) {
    final saved = savedRatio.clamp(0.0, 1.0);
    final savedPct = (saved * 100).toStringAsFixed(1);
    final spentPct = ((1 - saved) * 100).toStringAsFixed(1);
    final savingsColor = !incomeTracked
        ? AppColors.textSecondary
        : netSavings.startsWith('-')
        ? AppColors.expensePink
        : AppColors.savingsGreen;
    final small = GoogleFonts.inter(
      fontSize: 10,
      fontWeight: FontWeight.w400,
      color: AppColors.textSecondary,
    );

    final screenWidth = MediaQuery.sizeOf(context).width;
    final isCompact = screenWidth < 380;

    return BuckGlassCard(
      padding: EdgeInsets.symmetric(horizontal: isCompact ? 16 : 24, vertical: isCompact ? 18 : 22),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Monthly Cash Flow',
                    style: GoogleFonts.manrope(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: AppColors.cardTitle,
                    ),
                  ),
                ),
              ),
              Text(
                monthLabel,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: AppColors.navBarIcon,
                ),
              ),
            ],
          ),
          Row(
            spacing: 12,
            children: [
              Expanded(
                child: _FlowTile(
                  label: 'Income',
                  amount: income,
                  delta: incomeDelta,
                  accent: AppColors.incomeGreen,
                  background: AppColors.incomeTileBg,
                  border: AppColors.incomeTileBorder,
                ),
              ),
              Expanded(
                child: _FlowTile(
                  label: 'Expenses',
                  amount: expenses,
                  delta: expensesDelta,
                  accent: AppColors.expensePink,
                  background: AppColors.expenseTileBg,
                  border: AppColors.expenseTileBorder,
                ),
              ),
            ],
          ),
          Column(
            spacing: 8,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Net Savings',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    netSavings,
                    style: GoogleFonts.manrope(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: savingsColor,
                    ),
                  ),
                ],
              ),
              SizedBox(
                height: 10,
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(
                    begin: 0.0,
                    end: incomeTracked ? saved : 0.0,
                  ),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (context, animatedRatio, child) {
                    final animatedSavedFlex = (animatedRatio * 1000).round();
                    final animatedSpentFlex = 1000 - animatedSavedFlex;
                    return Row(
                      spacing: 2,
                      children: [
                        if (!incomeTracked)
                          Expanded(
                            child: Container(
                              decoration: BoxDecoration(
                                color: AppColors.trackBrown,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          )
                        else ...[
                          if (animatedSavedFlex > 0)
                            Expanded(
                              flex: animatedSavedFlex,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.incomeGreen,
                                  borderRadius: BorderRadius.horizontal(
                                    left: const Radius.circular(5),
                                    right: animatedSpentFlex <= 0
                                        ? const Radius.circular(5)
                                        : Radius.zero,
                                  ),
                                ),
                              ),
                            ),
                          if (animatedSpentFlex > 0)
                            Expanded(
                              flex: animatedSpentFlex,
                              child: Container(
                                decoration: BoxDecoration(
                                  color: AppColors.expensePink,
                                  borderRadius: BorderRadius.horizontal(
                                    right: const Radius.circular(5),
                                    left: animatedSavedFlex <= 0
                                        ? const Radius.circular(5)
                                        : Radius.zero,
                                  ),
                                ),
                              ),
                            ),
                        ],
                      ],
                    );
                  },
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: incomeTracked
                    ? [
                        Text('$savedPct% saved', style: small),
                        Text('$spentPct% spent', style: small),
                      ]
                    : [
                        Flexible(
                          child: Text(
                            'Log income to see your savings rate',
                            style: small,
                          ),
                        ),
                      ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _FlowTile extends StatelessWidget {
  final String label;
  final String amount;
  final String delta;
  final Color accent;
  final Color background;
  final Color border;

  const _FlowTile({
    required this.label,
    required this.amount,
    required this.delta,
    required this.accent,
    required this.background,
    required this.border,
  });

  @override
  Widget build(BuildContext context) {
    final isCompact = MediaQuery.sizeOf(context).width < 380;
    return Container(
      padding: EdgeInsets.all(isCompact ? 10 : 14),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: border, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Row(
            spacing: 6,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
              Text(
                label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: accent,
                ),
              ),
            ],
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              amount,
              style: GoogleFonts.manrope(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              delta,
              maxLines: 1,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: AppColors.textSecondary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
