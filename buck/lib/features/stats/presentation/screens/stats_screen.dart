import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/utils/currency.dart';
import '../../../finance/domain/finance_snapshot.dart';
import '../../domain/stats_data.dart';
import '../widgets/category_breakdown_card.dart';
import '../widgets/spending_trend_card.dart';

/// Figma "Screen / Statistics" (#2368:641) with updated Figma design:
/// - Hero Card 1: Category Breakdown Card with solid Pie Chart (#2402:1560)
/// - Hero Card 2: Spending Trend Line Graph Card (#2462:577)
/// - Activity Section: Dynamic transaction entries from database
class StatsScreen extends StatefulWidget {
  final FinanceSnapshot snapshot;
  final Future<void> Function() onRefresh;
  final EdgeInsets bottomInset;

  const StatsScreen({
    super.key,
    required this.snapshot,
    required this.onRefresh,
    this.bottomInset = EdgeInsets.zero,
  });

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen> {
  StatsPeriod _selectedPeriod = StatsPeriod.allTime;
  String? _selectedCategoryId;
  bool _activityExpanded = false;

  static final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    final margin = AppLayout.pageMargin(context);
    final s = widget.snapshot;

    // Use all tracked expenses; fallback to monthExpenseList if allExpenses is empty
    final sourceExpenses = s.allExpenses.isNotEmpty ? s.allExpenses : s.monthExpenseList;

    // 1. Dynamic category summary for Card 1
    final summary = StatsCalculator.calculate(
      expenses: sourceExpenses,
      period: _selectedPeriod,
      now: s.now,
    );

    // 2. Dynamic spending trend data for Card 2
    final trendData = StatsCalculator.calculateTrend(
      expenses: sourceExpenses,
      period: _selectedPeriod,
      now: s.now,
      categoryId: _selectedCategoryId,
    );

    // 3. Filter transaction list below card if a specific category is selected
    final visibleExpenses = _selectedCategoryId == null
        ? summary.filteredExpenses
        : summary.filteredExpenses.where((e) {
            return StatsCalculator.mapCategory(e.categoryName) == _selectedCategoryId;
          }).toList();

    final selectedCat = _selectedCategoryId != null
        ? summary.findById(_selectedCategoryId!)
        : null;

    return RefreshIndicator(
      onRefresh: widget.onRefresh,
      color: AppColors.primaryOrange,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: EdgeInsets.fromLTRB(
          margin,
          20,
          margin,
          85 + widget.bottomInset.bottom,
        ),
        children: [
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                maxWidth: AppLayout.contentMaxWidth,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                spacing: 16,
                children: [
                  // 1. Figma Category Breakdown Card (#2402:1560)
                  CategoryBreakdownCard(
                    summary: summary,
                    selectedPeriod: _selectedPeriod,
                    onPeriodChanged: (period) {
                      setState(() {
                        _selectedPeriod = period;
                      });
                    },
                    selectedCategoryId: _selectedCategoryId,
                    onCategoryChanged: (catId) {
                      setState(() {
                        _selectedCategoryId = catId;
                      });
                    },
                  ),

                  // 2. Figma Spending Trend Line Graph Card (#2462:577)
                  SpendingTrendCard(
                    trendData: trendData,
                    selectedPeriod: _selectedPeriod,
                    onPeriodChanged: (period) {
                      setState(() {
                        _selectedPeriod = period;
                      });
                    },
                    selectedCategoryId: _selectedCategoryId,
                    selectedCategory: selectedCat,
                    onClearCategory: () {
                      setState(() {
                        _selectedCategoryId = null;
                      });
                    },
                  ),

                  // 3. Collapsible Activity Dropdown Card (latest 5 entries)
                  _buildActivityCard(visibleExpenses, selectedCat),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActivityCard(
    List dynamicExpenses,
    StatsCategory? selectedCategory,
  ) {
    final palette = BuckPalette.of(context);
    final title = selectedCategory != null
        ? '${selectedCategory.name} Expenses'
        : '${_selectedPeriod.label} Activity';

    final latestFive = List.of(dynamicExpenses)
      ..sort((a, b) => b.spentOn.compareTo(a.spentOn));
    final displayed = latestFive.take(5).toList();
    final countLabel = dynamicExpenses.length > 5
        ? 'Latest 5 of ${dynamicExpenses.length}'
        : '${dynamicExpenses.length} ${dynamicExpenses.length == 1 ? 'entry' : 'entries'}';

    return Container(
      decoration: BoxDecoration(
        color: palette.glassCardBg,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: palette.glassCardBorder.withValues(alpha: 0.65),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(color: palette.glassCardGlow, blurRadius: 18),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const Key('stats_activity_dropdown_toggle'),
            borderRadius: BorderRadius.circular(14),
            onTap: () => setState(() => _activityExpanded = !_activityExpanded),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 0.5,
                            color:
                                selectedCategory?.color ?? palette.textAccent,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Recent Activity',
                          style: GoogleFonts.manrope(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: palette.cardTitle,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: palette.surfaceElevated,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: palette.subtleBorder,
                        width: 1,
                      ),
                    ),
                    child: Text(
                      countLabel,
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: palette.textSecondary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  AnimatedRotation(
                    turns: _activityExpanded ? 0.5 : 0.0,
                    duration: const Duration(milliseconds: 200),
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      color: palette.textAccent,
                      size: 22,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 240),
            curve: Curves.easeOutCubic,
            child: !_activityExpanded
                ? const SizedBox.shrink()
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const SizedBox(height: 12),
                      if (displayed.isEmpty)
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Center(
                            child: Text(
                              'No expenses recorded for this selection.',
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                color: palette.textSecondary,
                              ),
                            ),
                          ),
                        )
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: displayed.length,
                          separatorBuilder: (_, __) => Divider(
                            color: palette.divider,
                            height: 16,
                          ),
                          itemBuilder: (context, index) {
                            final expense = displayed[index];
                            final catKey =
                                StatsCalculator.mapCategory(expense.categoryName);
                            final catColor = _categoryColor(catKey);

                            return Row(
                              children: [
                                Container(
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: catColor.withValues(alpha: 0.16),
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: catColor.withValues(alpha: 0.4),
                                      width: 1,
                                    ),
                                  ),
                                  child: Icon(
                                    _categoryIcon(catKey),
                                    color: catColor,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        expense.description.isNotEmpty
                                            ? expense.description
                                            : expense.categoryName,
                                        style: GoogleFonts.inter(
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: palette.textPrimary,
                                        ),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        _dateFormat.format(expense.spentOn),
                                        style: GoogleFonts.inter(
                                          fontSize: 11,
                                          color: palette.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '-${formatPeso(expense.amount)}',
                                  style: GoogleFonts.manrope(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                    color: const Color(0xFFFF6B6B),
                                  ),
                                ),
                              ],
                            );
                          },
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Color _categoryColor(String key) {
    switch (key) {
      case 'shopping':
        return StatsCalculator.colorShopping;
      case 'bills':
        return StatsCalculator.colorBills;
      case 'food':
        return StatsCalculator.colorFood;
      case 'transport':
        return StatsCalculator.colorTransport;
      case 'others':
      default:
        return StatsCalculator.colorOthers;
    }
  }

  IconData _categoryIcon(String key) {
    switch (key) {
      case 'shopping':
        return Icons.shopping_bag_outlined;
      case 'bills':
        return Icons.receipt_long_outlined;
      case 'food':
        return Icons.restaurant_outlined;
      case 'transport':
        return Icons.directions_car_outlined;
      case 'others':
      default:
        return Icons.category_outlined;
    }
  }
}
