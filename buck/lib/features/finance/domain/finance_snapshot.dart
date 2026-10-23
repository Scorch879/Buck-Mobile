import '../data/finance_models.dart';
import '../data/finance_repository.dart';

/// Dashboard / expenses figures derived from raw [FinanceData].
/// Calculations mirror the Buck web app so both show the same numbers.
class FinanceSnapshot {
  final DateTime now;
  final String? displayName;
  final List<Wallet> wallets;
  final Wallet? activeWallet;

  /// Share of the active wallet still left (0–100), like the web
  /// "remaining of initial capacity". `null` without an active wallet.
  final int? walletRemainingPercent;

  final double weekTotal;
  final double lastWeekTotal;

  /// Spend per day this week, Monday first.
  final List<double> weekDaily;

  final double totalTracked;
  final double averageExpense;

  final double monthExpenses;
  final double lastMonthExpenses;

  /// `null` when income tracking is not available yet.
  final double? monthIncome;
  final double? lastMonthIncome;

  /// This month's expenses, newest first.
  final List<ExpenseRecord> monthExpenseList;

  /// All tracked expenses across all time.
  final List<ExpenseRecord> allExpenses;

  /// All tracked incomes.
  final List<IncomeRecord> allIncomes;
  final List<String> insights;

  const FinanceSnapshot({
    required this.now,
    required this.displayName,
    required this.wallets,
    required this.activeWallet,
    required this.walletRemainingPercent,
    required this.weekTotal,
    required this.lastWeekTotal,
    required this.weekDaily,
    required this.totalTracked,
    required this.averageExpense,
    required this.monthExpenses,
    required this.lastMonthExpenses,
    required this.monthIncome,
    required this.lastMonthIncome,
    required this.monthExpenseList,
    this.allExpenses = const [],
    this.allIncomes = const [],
    required this.insights,
  });

  double get walletBalance => activeWallet?.balance ?? 0;

  /// Sum of all wallet balances.
  double get totalNetWorth =>
      wallets.fold(0.0, (sum, w) => sum + w.balance);

  bool get incomeTracked => monthIncome != null;

  /// Week-over-week spending change in %, `null` when last week had none.
  double? get weekChangePercent => lastWeekTotal > 0
      ? (weekTotal - lastWeekTotal) / lastWeekTotal * 100
      : null;

  double? get netSavings =>
      monthIncome == null ? null : monthIncome! - monthExpenses;

  /// Share of this month's income saved (0–1); 0 without income.
  double get savedRatio {
    final income = monthIncome ?? 0;
    if (income <= 0) return 0;
    return ((income - monthExpenses) / income).clamp(0.0, 1.0);
  }

  static DateTime startOfWeek(DateTime d) {
    // Calendar arithmetic (not Duration) so DST shifts never skew the day.
    return DateTime(d.year, d.month, d.day - (d.weekday - DateTime.monday));
  }

  static bool _inRange(DateTime d, DateTime start, DateTime endExclusive) =>
      !d.isBefore(start) && d.isBefore(endExclusive);

  factory FinanceSnapshot.fromData(FinanceData data, {required DateTime now}) {
    // Active wallet: the profile's choice, or the only wallet (web behaviour).
    Wallet? active;
    for (final w in data.wallets) {
      if (w.id == data.activeWalletId) active = w;
    }
    if (active == null && data.wallets.length == 1) active = data.wallets.first;

    final expenses = data.expenses;
    double sum(Iterable<ExpenseRecord> items) =>
        items.fold(0, (total, e) => total + e.amount);

    int? remainingPercent;
    if (active != null) {
      final spent = sum(expenses.where((e) => e.walletId == active!.id));
      final capacity = active.balance + spent;
      remainingPercent = capacity > 0
          ? (active.balance / capacity * 100).round().clamp(0, 100)
          : 0;
    }

    final weekStart = startOfWeek(now);
    final nextWeek = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day + 7,
    );
    final lastWeekStart = DateTime(
      weekStart.year,
      weekStart.month,
      weekStart.day - 7,
    );
    final weekDaily = List<double>.filled(7, 0);
    var lastWeek = 0.0;
    for (final e in expenses) {
      if (_inRange(e.spentOn, weekStart, nextWeek)) {
        weekDaily[e.spentOn.weekday - DateTime.monday] += e.amount;
      } else if (_inRange(e.spentOn, lastWeekStart, weekStart)) {
        lastWeek += e.amount;
      }
    }

    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final monthList = expenses
        .where((e) => _inRange(e.spentOn, monthStart, nextMonth))
        .toList();
    final lastMonthTotal = sum(
      expenses.where((e) => _inRange(e.spentOn, lastMonthStart, monthStart)),
    );

    double? monthIncome;
    double? lastMonthIncome;
    final incomes = data.incomes;
    if (incomes != null) {
      monthIncome = 0;
      lastMonthIncome = 0;
      for (final i in incomes) {
        if (_inRange(i.receivedOn, monthStart, nextMonth)) {
          monthIncome = monthIncome! + i.amount;
        } else if (_inRange(i.receivedOn, lastMonthStart, monthStart)) {
          lastMonthIncome = lastMonthIncome! + i.amount;
        }
      }
    }

    final total = sum(expenses);
    final name = data.profileName;

    return FinanceSnapshot(
      now: now,
      displayName: (name != null && name.isNotEmpty) ? name : null,
      wallets: data.wallets,
      activeWallet: active,
      walletRemainingPercent: remainingPercent,
      weekTotal: weekDaily.fold(0, (a, b) => a + b),
      lastWeekTotal: lastWeek,
      weekDaily: weekDaily,
      totalTracked: total,
      averageExpense: expenses.isEmpty ? 0 : total / expenses.length,
      monthExpenses: sum(monthList),
      lastMonthExpenses: lastMonthTotal,
      monthIncome: monthIncome,
      lastMonthIncome: lastMonthIncome,
      monthExpenseList: monthList,
      allExpenses: expenses,
      allIncomes: incomes ?? const [],
      insights: data.advisories.map((a) => a.text).toList(),
    );
  }
}
