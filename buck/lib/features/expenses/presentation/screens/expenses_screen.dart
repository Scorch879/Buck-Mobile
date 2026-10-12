import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/utils/currency.dart';
import '../../../finance/domain/finance_snapshot.dart';
import '../widgets/expense_metrics_card.dart';
import '../widgets/monthly_cash_flow_card.dart';
import '../widgets/recent_expenses_card.dart';

/// Figma "Screen / Expenses" (2245:504) — scrollable body only.
/// Header, footer and backdrop come from the app shell.
class ExpensesScreen extends StatelessWidget {
  final FinanceSnapshot snapshot;
  final Future<void> Function() onRefresh;
  final VoidCallback? onAddExpense;
  final EdgeInsets bottomInset;

  const ExpensesScreen({
    super.key,
    required this.snapshot,
    required this.onRefresh,
    this.onAddExpense,
    this.bottomInset = EdgeInsets.zero,
  });

  static final _monthFormat = DateFormat('MMMM yyyy');

  @override
  Widget build(BuildContext context) {
    final margin = AppLayout.pageMargin(context);
    final s = snapshot;
    final income = s.monthIncome;
    final net = s.netSavings;

    return RefreshIndicator(
      onRefresh: onRefresh,
      color: AppColors.primaryOrange,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        // Figma: content starts 24px under the header.
        padding: EdgeInsets.fromLTRB(
          margin,
          24,
          margin,
          120 + bottomInset.bottom,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.contentMaxWidth,
              ),
              child: Column(
                spacing: 13,
                children: [
                  ExpenseMetricsCard(
                    walletLeft: formatPeso(s.walletBalance),
                    totalTracked: formatPeso(s.totalTracked),
                    average: formatPeso(s.averageExpense),
                  ),
                  MonthlyCashFlowCard(
                    monthLabel: _monthFormat.format(s.now),
                    income: formatPeso(income ?? 0),
                    incomeDelta: income == null
                        ? 'Not tracked yet'
                        : '${formatPesoDelta(income - (s.lastMonthIncome ?? 0))} vs last mo.',
                    expenses: formatPeso(s.monthExpenses),
                    expensesDelta:
                        '${formatPesoDelta(s.monthExpenses - s.lastMonthExpenses)} vs last mo.',
                    netSavings: net == null ? '—' : formatPeso(net),
                    savedRatio: s.savedRatio,
                    incomeTracked: s.incomeTracked,
                  ),
                  RecentExpensesCard(
                    expenses: s.monthExpenseList,
                    onAdd: onAddExpense,
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
