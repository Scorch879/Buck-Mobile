import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/buck_glass_card.dart';
import 'weekly_line_chart.dart';

/// One slice of the wallet allocation bar.
class WalletAllocation {
  final Color color;
  final double weight;

  const WalletAllocation(this.color, this.weight);
}

/// Figma "Financial Overview" row (2306:278): compact wallet + weekly cards.
class FinancialOverviewRow extends StatelessWidget {
  final String walletBalance;

  /// Badge under the balance (e.g. "64% left"); hidden when null.
  final String? walletChange;
  final List<WalletAllocation> allocations;
  final String lastSynced;
  final String weeklySpending;

  /// Week-over-week badge (e.g. "+12%"); hidden when null.
  final String? weeklyChange;

  /// Spend per day this week, Monday first.
  final List<double> weeklyDaily;
  final VoidCallback? onAddIncome;
  final VoidCallback? onAddExpense;
  final VoidCallback? onViewNetWorth;

  const FinancialOverviewRow({
    super.key,
    required this.walletBalance,
    required this.walletChange,
    required this.allocations,
    required this.lastSynced,
    required this.weeklySpending,
    required this.weeklyChange,
    required this.weeklyDaily,
    this.onAddIncome,
    this.onAddExpense,
    this.onViewNetWorth,
  });

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: 15,
        children: [
          Expanded(
            child: WalletCompactCard(
              balance: walletBalance,
              change: walletChange,
              allocations: allocations,
              lastSynced: lastSynced,
              onAddIncome: onAddIncome,
              onAddExpense: onAddExpense,
              onViewNetWorth: onViewNetWorth,
            ),
          ),
          Expanded(
            child: WeeklySpendingCompactCard(
              amount: weeklySpending,
              change: weeklyChange,
              daily: weeklyDaily,
            ),
          ),
        ],
      ),
    );
  }
}

/// Header block shared by both compact cards: title, big amount, trend badge.
class _CompactCardHeader extends StatelessWidget {
  final String title;
  final String amount;
  final String? change;

  const _CompactCardHeader({
    required this.title,
    required this.amount,
    required this.change,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: 4,
      children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(title, maxLines: 1, style: AppTextStyles.cardTitle),
        ),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(amount, style: AppTextStyles.amountLarge),
        ),
        if (change != null) BuckTrendBadge(text: change!),
      ],
    );
  }
}

/// Figma "Content / Financial Card" — View=Wallet, Size=Compact (2306:347).
class WalletCompactCard extends StatelessWidget {
  final String balance;
  final String? change;
  final List<WalletAllocation> allocations;
  final String lastSynced;
  final VoidCallback? onAddIncome;
  final VoidCallback? onAddExpense;
  final VoidCallback? onViewNetWorth;

  const WalletCompactCard({
    super.key,
    required this.balance,
    required this.change,
    required this.allocations,
    required this.lastSynced,
    this.onAddIncome,
    this.onAddExpense,
    this.onViewNetWorth,
  });

  @override
  Widget build(BuildContext context) {
    return BuckGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 10,
        children: [
          _CompactCardHeader(
            title: 'My Wallet',
            amount: balance,
            change: change,
          ),
          // Wallet Bars
          Row(
            spacing: 2,
            children: [
              if (allocations.isEmpty)
                Expanded(
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: AppColors.trackBrown,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
              for (final slice in allocations)
                Expanded(
                  flex: (slice.weight * 100).round().clamp(1, 1 << 30),
                  child: Container(
                    height: 12,
                    decoration: BoxDecoration(
                      color: slice.color,
                      borderRadius: BorderRadius.circular(5),
                    ),
                  ),
                ),
            ],
          ),
          // Wallet Actions
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 12,
            children: [
              _TapTarget(
                label: 'Add income',
                onTap: onAddIncome,
                child: SvgPicture.asset(
                  'assets/icons/wallet_add_income_button.svg',
                ),
              ),
              _TapTarget(
                label: 'Add expense',
                onTap: onAddExpense,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      colors: [
                        AppColors.gradientOrangeStart,
                        AppColors.gradientOrangeEnd,
                      ],
                    ),
                  ),
                  child: SvgPicture.asset('assets/icons/pay_money.svg'),
                ),
              ),
            ],
          ),
          // Wallet Footer
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 5,
            children: [
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'Last synced: $lastSynced',
                  maxLines: 1,
                  style: AppTextStyles.caption,
                ),
              ),
              _TapTarget(
                label: 'View Net Worth',
                onTap: onViewNetWorth,
                child: Text(
                  'View Net Worth →',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.navBarIcon,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Figma "Weekly Spending / Compact" (2306:400).
class WeeklySpendingCompactCard extends StatelessWidget {
  final String amount;
  final String? change;
  final List<double> daily;

  const WeeklySpendingCompactCard({
    super.key,
    required this.amount,
    required this.change,
    required this.daily,
  });

  @override
  Widget build(BuildContext context) {
    return BuckGlassCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 16,
        children: [
          _CompactCardHeader(
            title: 'Weekly Spending',
            amount: amount,
            change: change,
          ),
          WeeklyLineChart(values: daily),
        ],
      ),
    );
  }
}

class _TapTarget extends StatefulWidget {
  final String label;
  final VoidCallback? onTap;
  final Widget child;

  const _TapTarget({
    required this.label,
    required this.onTap,
    required this.child,
  });

  @override
  State<_TapTarget> createState() => _TapTargetState();
}

class _TapTargetState extends State<_TapTarget> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: widget.label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null ? null : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null ? null : (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.90 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: widget.child,
        ),
      ),
    );
  }
}
