import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../finance/data/finance_models.dart';
import '../../../stats/domain/stats_data.dart';

enum HistoryFilter {
  all('All'),
  income('Income'),
  expenses('Expenses');

  final String label;
  const HistoryFilter(this.label);
}

class _WalletActivityItem {
  final String id;
  final String title;
  final double amount;
  final bool isIncome;
  final DateTime date;
  final String categoryKey;

  const _WalletActivityItem({
    required this.id,
    required this.title,
    required this.amount,
    required this.isIncome,
    required this.date,
    required this.categoryKey,
  });
}

/// Figma "Wallet history" (#2426:1630)
/// Displays combined chronological activities (inflows & outflows) with search and filter.
class WalletHistoryCard extends StatefulWidget {
  final List<ExpenseRecord> expenses;
  final List<IncomeRecord> incomes;
  final String? activeWalletId;

  const WalletHistoryCard({
    super.key,
    required this.expenses,
    required this.incomes,
    required this.activeWalletId,
  });

  @override
  State<WalletHistoryCard> createState() => _WalletHistoryCardState();
}

class _WalletHistoryCardState extends State<WalletHistoryCard> {
  static const int _initialDisplayLimit = 10;
  String _searchQuery = '';
  HistoryFilter _filter = HistoryFilter.all;
  bool _showAll = false;
  static final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    // 1. Combine into uniform activities
    final activities = <_WalletActivityItem>[];

    // Filter by active wallet if specified, otherwise include all
    final targetExpenses = widget.activeWalletId == null
        ? widget.expenses
        : widget.expenses.where((e) => e.walletId == null || e.walletId == widget.activeWalletId);

    final targetIncomes = widget.activeWalletId == null
        ? widget.incomes
        : widget.incomes.where((i) => i.walletId == null || i.walletId == widget.activeWalletId);

    if (_filter == HistoryFilter.all || _filter == HistoryFilter.expenses) {
      for (final e in targetExpenses) {
        activities.add(_WalletActivityItem(
          id: e.id,
          title: e.description.isNotEmpty ? e.description : e.categoryName,
          amount: e.amount,
          isIncome: false,
          date: e.spentOn,
          categoryKey: StatsCalculator.mapCategory(e.categoryName),
        ));
      }
    }

    if (_filter == HistoryFilter.all || _filter == HistoryFilter.income) {
      for (final i in targetIncomes) {
        activities.add(_WalletActivityItem(
          id: i.id,
          title: i.source,
          amount: i.amount,
          isIncome: true,
          date: i.receivedOn,
          categoryKey: 'income',
        ));
      }
    }

    // Sort newest first
    activities.sort((a, b) => b.date.compareTo(a.date));

    // Filter by search query
    final filtered = activities.where((a) {
      if (_searchQuery.isEmpty) return true;
      return a.title.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    final palette = BuckPalette.of(context);
    final controlBg =
        palette.isLight ? palette.surfaceElevated : const Color(0xFF24170F);
    final controlBorder =
        palette.isLight ? palette.border : const Color(0x70785B4C);
    final incomeAccent =
        palette.isLight ? const Color(0xFF00796B) : const Color(0xFF56D3C7);
    final expenseAccent =
        palette.isLight ? const Color(0xFFC62828) : const Color(0xFFFF6B6B);

    return Container(
      decoration: BoxDecoration(
        color: palette.isLight
            ? palette.glassCardBg
            : const Color(0xCC080503), // rgba(8, 5, 3, 0.8)
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: palette.glassCardBorder,
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.glassCardGlow,
            blurRadius: 28,
            offset: const Offset(0, 0),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Section Header (Figma: #2426:1631)
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Wallet history',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: palette.cardTitle,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${filtered.length} activities',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: palette.textSecondary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 2. Search and Refine Controls (Figma: #2426:1634)
          Row(
            children: [
              // Search input
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: controlBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: controlBorder,
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      Icon(
                        Icons.search,
                        size: 16,
                        color: palette.textSecondary,
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: palette.textPrimary,
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search history...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 11,
                              color: palette.textSecondary,
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: EdgeInsets.zero,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 8),

              // Filter dropdown button (Figma: #2426:1639)
              PopupMenuButton<HistoryFilter>(
                onSelected: (filter) => setState(() => _filter = filter),
                color: controlBg,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(color: controlBorder),
                ),
                itemBuilder: (ctx) => [
                  for (final opt in HistoryFilter.values)
                    PopupMenuItem(
                      value: opt,
                      child: Text(
                        opt.label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _filter == opt
                              ? AppColors.primaryOrange
                              : palette.textPrimary,
                          fontWeight: _filter == opt ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: controlBg,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: controlBorder,
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _filter.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: palette.textPrimary,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: palette.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // 3. Activity Items or Empty State (Figma: #2426:1643)
          if (filtered.isEmpty)
            _buildEmptyState(palette)
          else ...[
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: _showAll || _searchQuery.isNotEmpty
                  ? filtered.length
                  : (filtered.length > _initialDisplayLimit
                      ? _initialDisplayLimit
                      : filtered.length),
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final item = filtered[index];
                final iconColor = item.isIncome
                    ? incomeAccent
                    : _categoryColor(item.categoryKey);

                return RepaintBoundary(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: palette.isLight
                          ? palette.surfaceElevated
                          : const Color(0xFF19100B),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: palette.subtleBorder,
                        width: 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        // Activity Symbol Container (Figma: #2426:1644)
                        Container(
                          width: 42,
                          height: 42,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: iconColor.withValues(alpha: 0.35),
                              width: 1,
                            ),
                          ),
                          child: Icon(
                            item.isIncome
                                ? Icons.arrow_downward
                                : _categoryIcon(item.categoryKey),
                            size: 20,
                            color: iconColor,
                          ),
                        ),
                        const SizedBox(width: 12),

                        // Title & Date
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.title,
                                style: GoogleFonts.manrope(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w700,
                                  color: palette.textPrimary,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                              const SizedBox(height: 2),
                              Text(
                                _dateFormat.format(item.date),
                                style: GoogleFonts.inter(
                                  fontSize: 11,
                                  color: palette.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),

                        // Amount (Green + for income, Red - for expense)
                        Text(
                          '${item.isIncome ? '+' : '-'}${formatPesoCents(item.amount)}',
                          style: GoogleFonts.manrope(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: item.isIncome ? incomeAccent : expenseAccent,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
            if (_searchQuery.isEmpty && filtered.length > _initialDisplayLimit) ...[
              const SizedBox(height: 10),
              Center(
                child: TextButton(
                  onPressed: () => setState(() => _showAll = !_showAll),
                  child: Text(
                    _showAll
                        ? 'Show recent $_initialDisplayLimit'
                        : 'Show all ${filtered.length} activities',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primaryOrange,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuckPalette palette) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Row(
        children: [
          Container(
            width: 50,
            height: 50,
            decoration: BoxDecoration(
              color: const Color(0x17FF994A),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: const Color(0x33FF994A),
                width: 1,
              ),
            ),
            child: Icon(
              Icons.receipt_long_outlined,
              size: 26,
              color: palette.isLight ? palette.textAccent : const Color(0xFFFF8E5D),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No wallet history found',
                  style: GoogleFonts.manrope(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  'Your wallet activity will appear here.',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    color: palette.textSecondary,
                  ),
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
