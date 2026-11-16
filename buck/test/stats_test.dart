import 'package:buck/features/finance/data/finance_models.dart';
import 'package:buck/features/finance/domain/finance_snapshot.dart';
import 'package:buck/features/stats/domain/stats_data.dart';
import 'package:buck/features/stats/presentation/screens/stats_screen.dart';
import 'package:buck/features/stats/presentation/widgets/category_breakdown_card.dart';
import 'package:buck/features/stats/presentation/widgets/spending_trend_card.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final now = DateTime(2026, 10, 23, 14, 0); // Friday of week starting Oct 19

  final sampleExpenses = [
    ExpenseRecord(
      id: 'e1',
      walletId: 'w1',
      categoryName: 'Shopping',
      amount: 1000,
      description: 'Groceries',
      spentOn: DateTime(2026, 10, 22), // This week & this month
    ),
    ExpenseRecord(
      id: 'e2',
      walletId: 'w1',
      categoryName: 'Bills & Utilities',
      amount: 2000,
      description: 'Electricity',
      spentOn: DateTime(2026, 10, 20), // This week & this month
    ),
    ExpenseRecord(
      id: 'e3',
      walletId: 'w1',
      categoryName: 'Food & Dining',
      amount: 500,
      description: 'Lunch',
      spentOn: DateTime(2026, 10, 5), // This month, but not this week
    ),
    ExpenseRecord(
      id: 'e4',
      walletId: 'w1',
      categoryName: 'Transportation',
      amount: 1500,
      description: 'Grab',
      spentOn: DateTime(2026, 9, 15), // Last month (only All Time)
    ),
  ];

  group('StatsCalculator', () {
    test('calculates correct totals and percentages for All Time', () {
      final summary = StatsCalculator.calculate(
        expenses: sampleExpenses,
        period: StatsPeriod.allTime,
        now: now,
      );

      // Total = 1000 + 2000 + 500 + 1500 = 5000
      expect(summary.totalAmount, 5000);
      expect(summary.filteredExpenses.length, 4);

      final shopping = summary.findById('shopping')!;
      expect(shopping.amount, 1000);
      expect(shopping.percentage, 20.0);
      expect(shopping.formattedPercent, '20%');

      final bills = summary.findById('bills')!;
      expect(bills.amount, 2000);
      expect(bills.percentage, 40.0);
      expect(bills.formattedPercent, '40%');

      final food = summary.findById('food')!;
      expect(food.amount, 500);
      expect(food.percentage, 10.0);

      final transport = summary.findById('transport')!;
      expect(transport.amount, 1500);
      expect(transport.percentage, 30.0);
    });

    test('filters correctly for This Month', () {
      final summary = StatsCalculator.calculate(
        expenses: sampleExpenses,
        period: StatsPeriod.thisMonth,
        now: now,
      );

      // Oct expenses: e1 (1000), e2 (2000), e3 (500) = 3500
      expect(summary.totalAmount, 3500);
      expect(summary.filteredExpenses.length, 3);
      expect(summary.findById('transport')!.amount, 0);
    });

    test('filters correctly for This Week', () {
      final summary = StatsCalculator.calculate(
        expenses: sampleExpenses,
        period: StatsPeriod.thisWeek,
        now: now,
      );

      // Oct 19-25 expenses: e1 (1000), e2 (2000) = 3000
      expect(summary.totalAmount, 3000);
      expect(summary.filteredExpenses.length, 2);
    });

    test('handles empty expenses list safely', () {
      final summary = StatsCalculator.calculate(
        expenses: const [],
        period: StatsPeriod.allTime,
        now: now,
      );

      expect(summary.totalAmount, 0);
      expect(summary.filteredExpenses, isEmpty);
      for (final cat in summary.categories) {
        expect(cat.amount, 0);
        expect(cat.percentage, 0);
      }
    });

    test('calculates spending trend data correctly', () {
      final trendAllTime = StatsCalculator.calculateTrend(
        expenses: sampleExpenses,
        period: StatsPeriod.allTime,
        now: now,
      );

      expect(trendAllTime.points.length, 10);
      expect(trendAllTime.maxAmount, greaterThanOrEqualTo(1000));

      final trendThisMonth = StatsCalculator.calculateTrend(
        expenses: sampleExpenses,
        period: StatsPeriod.thisMonth,
        now: now,
      );
      expect(trendThisMonth.points.length, 5); // 5 weeks in Oct 2026

      final trendCategory = StatsCalculator.calculateTrend(
        expenses: sampleExpenses,
        period: StatsPeriod.allTime,
        categoryId: 'shopping',
        now: now,
      );
      expect(trendCategory.points.any((p) => p.amount == 1000), isTrue);
      expect(trendCategory.points.any((p) => p.amount == 2000), isFalse);

      expect(StatsCalculator.trendColor(null), const Color(0xFF2C93B8));
      expect(StatsCalculator.trendColor('shopping'), const Color(0xFF9B72F2));
    });
  });

  group('StatsScreen Widget', () {
    testWidgets('renders category breakdown card and spending trend card with non-static dynamic values', (tester) async {
      final snapshot = FinanceSnapshot(
        now: now,
        displayName: 'Tester',
        wallets: const [Wallet(id: 'w1', name: 'Main', balance: 10000)],
        activeWallet: const Wallet(id: 'w1', name: 'Main', balance: 10000),
        walletRemainingPercent: 50,
        weekTotal: 3000,
        lastWeekTotal: 0,
        weekDaily: const [0, 2000, 0, 1000, 0, 0, 0],
        totalTracked: 5000,
        averageExpense: 1250,
        monthExpenses: 3500,
        lastMonthExpenses: 1500,
        monthIncome: 20000,
        lastMonthIncome: 20000,
        monthExpenseList: sampleExpenses.take(3).toList(),
        allExpenses: sampleExpenses,
        insights: const [],
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatsScreen(
              snapshot: snapshot,
              onRefresh: () async {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Card 1: Eyebrow and Title
      expect(find.text('CATEGORY SPENDING'), findsOneWidget);
      expect(find.text('Category Breakdown'), findsOneWidget);

      // Card 2: Spending Trend Card (Figma #2462:577)
      expect(find.byType(SpendingTrendCard), findsOneWidget);
      expect(find.text('Spending Trend'), findsOneWidget);

      // Card 1 Period Pills
      final card1PillAllTime = find.descendant(
        of: find.byType(CategoryBreakdownCard),
        matching: find.text('All Time'),
      );
      final card1PillThisMonth = find.descendant(
        of: find.byType(CategoryBreakdownCard),
        matching: find.text('This Month'),
      );
      final card1PillThisWeek = find.descendant(
        of: find.byType(CategoryBreakdownCard),
        matching: find.text('This Week'),
      );

      expect(card1PillAllTime, findsOneWidget);
      expect(card1PillThisMonth, findsOneWidget);
      expect(card1PillThisWeek, findsOneWidget);

      // Side Categories labels in Card 1
      expect(find.text('All'), findsWidgets);
      expect(find.text('Shopping'), findsWidgets);
      expect(find.text('Bills'), findsWidgets);
      expect(find.text('Food'), findsWidgets);
      expect(find.text('Transport'), findsWidgets);
      expect(find.text('Others'), findsWidgets);

      // Total amount for All Time is ₱5,000.00
      expect(find.text('₱5,000.00'), findsOneWidget);
      expect(find.text('TOTAL ALL-TIME'), findsOneWidget);

      // Tap "This Month" filter on Card 1
      await tester.tap(card1PillThisMonth);
      await tester.pumpAndSettle();

      // Total amount should update dynamically to ₱3,500.00!
      expect(find.text('₱3,500.00'), findsOneWidget);
      expect(find.text('TOTAL THIS MONTH'), findsOneWidget);

      // Tap "This Week" filter on Card 1
      await tester.tap(card1PillThisWeek);
      await tester.pumpAndSettle();

      // Total amount should update dynamically to ₱3,000.00!
      expect(find.text('₱3,000.00'), findsOneWidget);
      expect(find.text('TOTAL THIS WEEK'), findsOneWidget);
    });

    testWidgets('expands and collapses category detail breakdown', (tester) async {
      final summary = StatsCalculator.calculate(
        expenses: sampleExpenses,
        period: StatsPeriod.allTime,
        now: now,
      );

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: CategoryBreakdownCard(
                summary: summary,
                selectedPeriod: StatsPeriod.allTime,
                onPeriodChanged: (_) {},
                selectedCategoryId: null,
                onCategoryChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // In collapsed state, "CATEGORIES" header is not yet visible
      expect(find.text('CATEGORIES'), findsNothing);

      // Tap expand button (the animated pill indicator)
      await tester.tap(find.byKey(const Key('expand_button')));
      await tester.pumpAndSettle();

      // Expanded state shows "CATEGORIES" and hint
      expect(find.text('CATEGORIES'), findsOneWidget);
      expect(find.text('Tap a slice to filter by category'), findsOneWidget);
      expect(find.text('₱1,000.00'), findsOneWidget); // Shopping
      expect(find.text('₱2,000.00'), findsOneWidget); // Bills
    });
  });
}
