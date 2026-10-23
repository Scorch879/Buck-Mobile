import 'package:flutter/material.dart';

import '../../finance/data/finance_models.dart';
import '../../finance/domain/finance_snapshot.dart';

/// Time filter periods matching the Figma "Category Breakdown Card" tabs (#2402:1560).
enum StatsPeriod {
  allTime('All Time', 'Total All-Time'),
  thisMonth('This Month', 'Total This Month'),
  thisWeek('This Week', 'Total This Week');

  final String label;
  final String subtitle;

  const StatsPeriod(this.label, this.subtitle);
}

/// Category metadata and computed totals matching the Figma side list and donut segments.
class StatsCategory {
  final String id;
  final String name;
  final Color color;
  final double amount;
  final double percentage;

  const StatsCategory({
    required this.id,
    required this.name,
    required this.color,
    required this.amount,
    required this.percentage,
  });

  String get formattedPercent => '${percentage.round()}%';
}

/// Computed statistics summary for the selected period.
class StatsSummary {
  final StatsPeriod period;
  final double totalAmount;
  final List<StatsCategory> categories;
  final List<ExpenseRecord> filteredExpenses;

  const StatsSummary({
    required this.period,
    required this.totalAmount,
    required this.categories,
    required this.filteredExpenses,
  });

  StatsCategory? findById(String id) {
    for (final c in categories) {
      if (c.id == id) return c;
    }
    return null;
  }
}

/// Pure computation helper to derive category breakdowns from expense records.
class StatsCalculator {
  // Category colors strictly matching Figma node #2402:1560 and #2402:1330
  static const Color colorShopping = Color(0xFF9B72F2);
  static const Color colorBills = Color(0xFF2F9E7C);
  static const Color colorFood = Color(0xFFFF8E5D);
  static const Color colorTransport = Color(0xFF35B9D3);
  static const Color colorOthers = Color(0xFFB5927A);

  static StatsSummary calculate({
    required List<ExpenseRecord> expenses,
    required StatsPeriod period,
    required DateTime now,
  }) {
    // 1. Filter expenses according to the selected period
    final weekStart = FinanceSnapshot.startOfWeek(now);
    final nextWeek = DateTime(weekStart.year, weekStart.month, weekStart.day + 7);
    final monthStart = DateTime(now.year, now.month, 1);
    final nextMonth = DateTime(now.year, now.month + 1, 1);

    final filtered = expenses.where((e) {
      final d = e.spentOn;
      switch (period) {
        case StatsPeriod.allTime:
          return true;
        case StatsPeriod.thisMonth:
          return !d.isBefore(monthStart) && d.isBefore(nextMonth);
        case StatsPeriod.thisWeek:
          return !d.isBefore(weekStart) && d.isBefore(nextWeek);
      }
    }).toList();

    // 2. Aggregate into the 5 core Figma categories
    var sumShopping = 0.0;
    var sumBills = 0.0;
    var sumFood = 0.0;
    var sumTransport = 0.0;
    var sumOthers = 0.0;

    for (final e in filtered) {
      final cat = mapCategory(e.categoryName);
      switch (cat) {
        case 'shopping':
          sumShopping += e.amount;
        case 'bills':
          sumBills += e.amount;
        case 'food':
          sumFood += e.amount;
        case 'transport':
          sumTransport += e.amount;
        case 'others':
        default:
          sumOthers += e.amount;
      }
    }

    final total = sumShopping + sumBills + sumFood + sumTransport + sumOthers;

    double calcPercent(double amt) {
      if (total <= 0) return 0.0;
      return (amt / total) * 100.0;
    }

    final categories = [
      StatsCategory(
        id: 'shopping',
        name: 'Shopping',
        color: colorShopping,
        amount: sumShopping,
        percentage: calcPercent(sumShopping),
      ),
      StatsCategory(
        id: 'bills',
        name: 'Bills',
        color: colorBills,
        amount: sumBills,
        percentage: calcPercent(sumBills),
      ),
      StatsCategory(
        id: 'food',
        name: 'Food',
        color: colorFood,
        amount: sumFood,
        percentage: calcPercent(sumFood),
      ),
      StatsCategory(
        id: 'transport',
        name: 'Transport',
        color: colorTransport,
        amount: sumTransport,
        percentage: calcPercent(sumTransport),
      ),
      StatsCategory(
        id: 'others',
        name: 'Others',
        color: colorOthers,
        amount: sumOthers,
        percentage: calcPercent(sumOthers),
      ),
    ];

    return StatsSummary(
      period: period,
      totalAmount: total,
      categories: categories,
      filteredExpenses: filtered,
    );
  }

  /// Maps any category name string into one of the 5 Figma category keys.
  static String mapCategory(String rawName) {
    final lower = rawName.toLowerCase().trim();
    if (lower.contains('shop') ||
        lower.contains('grocer') ||
        lower.contains('cloth') ||
        lower.contains('market') ||
        lower.contains('retail')) {
      return 'shopping';
    }
    if (lower.contains('bill') ||
        lower.contains('util') ||
        lower.contains('electr') ||
        lower.contains('water') ||
        lower.contains('power') ||
        lower.contains('internet') ||
        lower.contains('wifi') ||
        lower.contains('rent') ||
        lower.contains('insurance')) {
      return 'bills';
    }
    if (lower.contains('food') ||
        lower.contains('din') ||
        lower.contains('lunch') ||
        lower.contains('dinner') ||
        lower.contains('breakf') ||
        lower.contains('cafe') ||
        lower.contains('coffee') ||
        lower.contains('snack') ||
        lower.contains('restaur') ||
        lower.contains('bistro')) {
      return 'food';
    }
    if (lower.contains('trans') ||
        lower.contains('ride') ||
        lower.contains('grab') ||
        lower.contains('taxi') ||
        lower.contains('gas') ||
        lower.contains('fuel') ||
        lower.contains('commute') ||
        lower.contains('fare') ||
        lower.contains('mrt') ||
        lower.contains('bus') ||
        lower.contains('train')) {
      return 'transport';
    }
    return 'others';
  }
}
