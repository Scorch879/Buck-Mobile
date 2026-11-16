import 'package:buck/features/ai/data/models/ai_insight_response.dart';
import 'package:buck/features/finance/data/finance_models.dart';
import 'package:buck/features/finance/data/finance_repository.dart';
import 'package:buck/features/goals/data/goal_model.dart';
import 'package:flutter/material.dart';

/// Sample goal items used only in widget tests.
const List<GoalItem> sampleSeedGoals = [
  GoalItem(
    id: 'emergency-fund',
    title: 'Emergency Fund',
    targetDate: 'Target: Dec 2025',
    status: GoalStatus.onTrack,
    currentAmount: 45200,
    targetAmount: 100000,
    icon: Icons.shield_outlined,
    themeColor: Color(0xFFFF8E5D),
    gradientColors: [Color(0xFFFF8E5D), Color(0xFFFF6A13)],
  ),
  GoalItem(
    id: 'vacation-fund',
    title: 'Vacation Fund',
    targetDate: 'Target: Aug 2026',
    status: GoalStatus.inProgress,
    currentAmount: 12000,
    targetAmount: 50000,
    icon: Icons.location_on_outlined,
    themeColor: Color(0xFF9B72F2),
    gradientColors: [Color(0xFF9B72F2), Color(0xFF7C3AED)],
  ),
  GoalItem(
    id: 'laptop-fund',
    title: 'New Laptop',
    targetDate: 'Target: Mar 2026',
    status: GoalStatus.inProgress,
    currentAmount: 18500,
    targetAmount: 65000,
    icon: Icons.laptop_mac_outlined,
    themeColor: Color(0xFF35B9D3),
    gradientColors: [Color(0xFF35B9D3), Color(0xFF00CCFF)],
  ),
];

/// Pre-populated in-memory finance source for automated tests.
class DevFinanceSource implements FinanceDataSource {
  static AiInsightResponse mockInsight({bool refreshed = false}) {
    final now = DateTime.now();
    return AiInsightResponse(
      id: 'dev-insight-001',
      title: 'Steady Weekly Pacing',
      suggestion:
          'Keep daily spending under ₱1,200.00 to stay on track for your Emergency Fund goal.',
      advice:
          'Your simulated monthly spending is ₱14,850.00 against ₱45,000.00 in tracked income.',
      financialHealthScore: 84,
      priority: 'low',
      focus: 'savings',
      walletAdvice:
          'Use your Main Wallet for everyday expenses while keeping your Savings wallet untouched as your goal buffer.',
      period: AiPeriod(
        asOf:
            '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        monthStart: '${now.year}-${now.month.toString().padLeft(2, '0')}-01',
      ),
      generatedWith: 'dev-preview',
      createdAt: now.toIso8601String(),
      cached: !refreshed,
      stale: false,
    );
  }

  FinanceData _data = FinanceData(
    profileName: 'Admin',
    activeWalletId: 'wallet-main',
    wallets: const [
      Wallet(id: 'wallet-main', name: 'Main Wallet', balance: 24500.00),
      Wallet(id: 'wallet-savings', name: 'Savings', balance: 50000.00),
      Wallet(id: 'wallet-emergency', name: 'Emergency Fund', balance: 15000.00),
    ],
    expenses: [
      ExpenseRecord(
        id: 'exp-1',
        walletId: 'wallet-main',
        categoryName: 'Food',
        amount: 320.00,
        description: 'Lunch at Bistro',
        spentOn: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ExpenseRecord(
        id: 'exp-2',
        walletId: 'wallet-main',
        categoryName: 'Transportation',
        amount: 150.00,
        description: 'Grab ride to office',
        spentOn: DateTime.now().subtract(const Duration(days: 1)),
      ),
    ],
    incomes: [
      IncomeRecord(
        id: 'inc-1',
        walletId: 'wallet-main',
        source: 'Salary',
        amount: 45000.00,
        receivedOn: DateTime(DateTime.now().year, DateTime.now().month, 15),
      ),
    ],
    advisories: const [
      AiAdvisory(
        id: 'adv-1',
        title: 'Spending Pattern Analysis',
        suggestion: 'You spent 12% less on dining this week. Keep it up!',
        advice: 'Allocating the surplus ₱1,200 will help reach your goal faster.',
      ),
    ],
  );

  final List<void Function()> _listeners = [];

  @override
  Future<FinanceData> load({required DateTime now}) async => _data;

  @override
  Future<void> addIncome({
    required String walletId,
    required double amount,
    required String source,
    required String description,
    required DateTime receivedOn,
  }) async {
    _data = FinanceData(
      profileName: _data.profileName,
      activeWalletId: _data.activeWalletId,
      wallets: [
        for (final w in _data.wallets)
          w.id == walletId
              ? Wallet(id: w.id, name: w.name, balance: w.balance + amount)
              : w,
      ],
      expenses: _data.expenses,
      incomes: [
        IncomeRecord(
          id: 'inc-${DateTime.now().millisecondsSinceEpoch}',
          walletId: walletId,
          source: source,
          amount: amount,
          receivedOn: receivedOn,
        ),
        ...?_data.incomes,
      ],
      advisories: _data.advisories,
    );
    for (final cb in _listeners) {
      cb();
    }
  }

  @override
  Future<void> addExpense({
    required String walletId,
    required double amount,
    required String categoryName,
    required String description,
    required DateTime spentOn,
  }) async {
    _data = FinanceData(
      profileName: _data.profileName,
      activeWalletId: _data.activeWalletId,
      wallets: [
        for (final w in _data.wallets)
          w.id == walletId
              ? Wallet(
                  id: w.id,
                  name: w.name,
                  balance: (w.balance - amount).clamp(0.0, double.infinity),
                )
              : w,
      ],
      expenses: [
        ExpenseRecord(
          id: 'exp-${DateTime.now().millisecondsSinceEpoch}',
          walletId: walletId,
          categoryName: categoryName,
          amount: amount,
          description: description,
          spentOn: spentOn,
        ),
        ..._data.expenses,
      ],
      incomes: _data.incomes,
      advisories: _data.advisories,
    );
    for (final cb in _listeners) {
      cb();
    }
  }

  @override
  Future<void> createWallet({
    required String name,
    required double initialBalance,
  }) async {
    final newId = 'wallet-${DateTime.now().millisecondsSinceEpoch}';
    final newWallet = Wallet(id: newId, name: name, balance: initialBalance);
    _data = FinanceData(
      profileName: _data.profileName,
      activeWalletId: _data.activeWalletId ?? newId,
      wallets: [..._data.wallets, newWallet],
      expenses: _data.expenses,
      incomes: _data.incomes,
      advisories: _data.advisories,
    );
    for (final cb in _listeners) {
      cb();
    }
  }

  @override
  Future<void> setActiveWallet(String walletId) async {
    _data = FinanceData(
      profileName: _data.profileName,
      activeWalletId: walletId,
      wallets: _data.wallets,
      expenses: _data.expenses,
      incomes: _data.incomes,
      advisories: _data.advisories,
    );
    for (final cb in _listeners) {
      cb();
    }
  }

  @override
  void Function() watch(void Function() onChange) {
    _listeners.add(onChange);
    return () => _listeners.remove(onChange);
  }
}
