import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/utils/currency.dart';
import '../../../finance/domain/finance_snapshot.dart';
import '../widgets/ai_advisory_banner.dart';
import '../widgets/financial_overview_cards.dart';
import '../widgets/quick_actions_card.dart';

/// Figma "Screen / Home Dashboard" (2172:34) — scrollable body only.
/// Header, footer and backdrop come from the app shell.
class HomeDashboardScreen extends StatelessWidget {
  final FinanceSnapshot snapshot;
  final ValueChanged<QuickAction> onQuickAction;
  final Future<void> Function() onRefresh;
  final VoidCallback? onOpenReport;
  final EdgeInsets bottomInset;

  const HomeDashboardScreen({
    super.key,
    required this.snapshot,
    required this.onQuickAction,
    required this.onRefresh,
    this.onOpenReport,
    this.bottomInset = EdgeInsets.zero,
  });

  /// Wallet bar colours from Figma, cycled per wallet.
  static const _walletColors = [
    AppColors.walletPurple,
    AppColors.walletGreen,
    AppColors.walletOrange,
    AppColors.walletTeal,
  ];

  @override
  Widget build(BuildContext context) {
    final margin = AppLayout.pageMargin(context);
    final s = snapshot;
    final weekChange = s.weekChangePercent;
    final positiveTotal = s.wallets.fold<double>(
      0,
      (sum, w) => sum + (w.balance > 0 ? w.balance : 0),
    );

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primaryOrange,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Figma: content starts 20px under the header; 120px scroll bottom padding.
        padding: EdgeInsets.fromLTRB(
          margin,
          20,
          margin,
          85 + bottomInset.bottom,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.contentMaxWidth,
              ),
              child: Column(
                spacing: 15,
                children: [
                  QuickActionsCard(onAction: onQuickAction),
                  FinancialOverviewRow(
                    walletBalance: formatPeso(s.walletBalance),
                    walletChange: s.walletRemainingPercent == null
                        ? null
                        : '${s.walletRemainingPercent}% left',
                    allocations: [
                      for (final (i, w) in s.wallets.indexed)
                        if (w.balance > 0)
                          WalletAllocation(
                            _walletColors[i % _walletColors.length],
                            // Share of all wallet funds, in percent.
                            w.balance / positiveTotal * 100,
                          ),
                    ],
                    lastSynced: DateFormat.jm().format(s.now),
                    weeklySpending: formatPeso(s.weekTotal),
                    weeklyChange: weekChange == null
                        ? null
                        : formatPercentChange(weekChange),
                    weeklyDaily: s.weekDaily,
                    onAddIncome: () => onQuickAction(QuickAction.addIncome),
                    onAddExpense: () => onQuickAction(QuickAction.addExpense),
                  ),
                  AiAdvisoryBanner(
                    insights: s.insights,
                    onOpenReport: onOpenReport,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
