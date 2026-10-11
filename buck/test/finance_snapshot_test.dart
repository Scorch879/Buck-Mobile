import 'package:buck/features/finance/data/finance_models.dart';
import 'package:buck/features/finance/data/finance_repository.dart';
import 'package:buck/features/finance/domain/finance_snapshot.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_finance_source.dart';

void main() {
  // Wednesday 14 Oct 2026; week runs Monday 12 – Sunday 18 Oct.
  final now = DateTime(2026, 10, 14, 14);

  FinanceData data({
    List<Wallet> wallets = const [],
    String? activeWalletId,
    List<ExpenseRecord> expenses = const [],
    List<IncomeRecord>? incomes,
  }) => FinanceData(
    profileName: 'Jo',
    activeWalletId: activeWalletId,
    wallets: wallets,
    expenses: expenses,
    incomes: incomes,
    advisories: const [
      AiAdvisory(id: 'a', title: 'T', suggestion: '', advice: 'Save more'),
    ],
  );

  test('uses the only wallet as active and computes % left like web', () {
    final s = FinanceSnapshot.fromData(
      data(
        wallets: const [Wallet(id: 'w1', name: 'Cash', balance: 600)],
        expenses: [expense('e1', 400, DateTime(2026, 9, 1))],
      ),
      now: now,
    );
    expect(s.activeWallet?.id, 'w1');
    expect(s.walletBalance, 600);
    expect(s.walletRemainingPercent, 60); // 600 / (600 + 400)
  });

  test('profile active wallet wins over the first wallet', () {
    final s = FinanceSnapshot.fromData(
      data(
        wallets: const [
          Wallet(id: 'w1', name: 'Cash', balance: 10),
          Wallet(id: 'w2', name: 'Bank', balance: 90),
        ],
        activeWalletId: 'w2',
      ),
      now: now,
    );
    expect(s.activeWallet?.name, 'Bank');
  });

  test('no active wallet when several exist and none is chosen', () {
    final s = FinanceSnapshot.fromData(
      data(
        wallets: const [
          Wallet(id: 'w1', name: 'Cash', balance: 10),
          Wallet(id: 'w2', name: 'Bank', balance: 90),
        ],
      ),
      now: now,
    );
    expect(s.activeWallet, isNull);
    expect(s.walletRemainingPercent, isNull);
  });

  test('weekly totals, daily buckets and week-over-week change', () {
    final s = FinanceSnapshot.fromData(
      data(
        expenses: [
          expense('mon', 100, DateTime(2026, 10, 12)),
          expense('wed', 50, DateTime(2026, 10, 14)),
          expense('sun', 30, DateTime(2026, 10, 18)),
          expense('lastweek', 120, DateTime(2026, 10, 8)),
          expense('old', 999, DateTime(2026, 9, 1)),
        ],
      ),
      now: now,
    );
    expect(s.weekTotal, 180);
    expect(s.weekDaily, [100, 0, 50, 0, 0, 0, 30]);
    expect(s.lastWeekTotal, 120);
    expect(s.weekChangePercent, closeTo(50, 0.001));
  });

  test('total tracked and average cover all expenses', () {
    final s = FinanceSnapshot.fromData(
      data(
        expenses: [
          expense('a', 100, DateTime(2026, 10, 1)),
          expense('b', 300, DateTime(2025, 1, 1)),
        ],
      ),
      now: now,
    );
    expect(s.totalTracked, 400);
    expect(s.averageExpense, 200);
  });

  test('monthly expenses vs last month and this month list', () {
    final s = FinanceSnapshot.fromData(
      data(
        expenses: [
          expense('oct1', 200, DateTime(2026, 10, 2)),
          expense('oct2', 100, DateTime(2026, 10, 14)),
          expense('sep', 500, DateTime(2026, 9, 30)),
        ],
      ),
      now: now,
    );
    expect(s.monthExpenses, 300);
    expect(s.lastMonthExpenses, 500);
    expect(s.monthExpenseList.map((e) => e.id), ['oct1', 'oct2']);
  });

  test('income untracked when the incomes table is unavailable', () {
    final s = FinanceSnapshot.fromData(data(), now: now);
    expect(s.incomeTracked, isFalse);
    expect(s.netSavings, isNull);
    expect(s.savedRatio, 0);
  });

  test('income, net savings and saved ratio', () {
    final s = FinanceSnapshot.fromData(
      data(
        expenses: [expense('e', 250, DateTime(2026, 10, 3))],
        incomes: [
          IncomeRecord(
            id: 'i1',
            walletId: 'w1',
            source: 'Salary',
            amount: 1000,
            receivedOn: DateTime(2026, 10, 1),
          ),
          IncomeRecord(
            id: 'i0',
            walletId: 'w1',
            source: 'Salary',
            amount: 800,
            receivedOn: DateTime(2026, 9, 1),
          ),
        ],
      ),
      now: now,
    );
    expect(s.monthIncome, 1000);
    expect(s.lastMonthIncome, 800);
    expect(s.netSavings, 750);
    expect(s.savedRatio, closeTo(0.75, 0.0001));
  });

  test('advisory text falls back from suggestion to advice', () {
    final s = FinanceSnapshot.fromData(data(), now: now);
    expect(s.insights, ['Save more']);
  });
}
