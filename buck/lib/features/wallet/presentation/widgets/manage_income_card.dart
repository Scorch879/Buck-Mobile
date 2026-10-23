import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../../finance/data/finance_models.dart';

enum IncomeSortOption {
  newest('Newest'),
  highestAmount('Highest Amount'),
  source('Source');

  final String label;
  const IncomeSortOption(this.label);
}

/// Income management card shown when the Income tab is selected in the Wallet screen.
class ManageIncomeCard extends StatefulWidget {
  final List<IncomeRecord> incomes;
  final VoidCallback onAddIncome;

  const ManageIncomeCard({
    super.key,
    required this.incomes,
    required this.onAddIncome,
  });

  @override
  State<ManageIncomeCard> createState() => _ManageIncomeCardState();
}

class _ManageIncomeCardState extends State<ManageIncomeCard> {
  String _searchQuery = '';
  IncomeSortOption _sortOption = IncomeSortOption.newest;
  static final _dateFormat = DateFormat('MMM d, yyyy');

  @override
  Widget build(BuildContext context) {
    // 1. Filter by search query
    final filtered = widget.incomes.where((i) {
      if (_searchQuery.isEmpty) return true;
      return i.source.toLowerCase().contains(_searchQuery.toLowerCase());
    }).toList();

    // 2. Sort
    filtered.sort((a, b) {
      switch (_sortOption) {
        case IncomeSortOption.newest:
          return b.receivedOn.compareTo(a.receivedOn);
        case IncomeSortOption.highestAmount:
          return b.amount.compareTo(a.amount);
        case IncomeSortOption.source:
          return a.source.toLowerCase().compareTo(b.source.toLowerCase());
      }
    });

    return Container(
      decoration: BoxDecoration(
        color: const Color(0xCC080503),
        borderRadius: BorderRadius.circular(26),
        border: Border.all(
          color: const Color(0xFFFF994A),
          width: 1,
        ),
        boxShadow: const [
          BoxShadow(
            color: Color(0x2EFF6A13),
            blurRadius: 28,
            offset: Offset(0, 0),
          ),
        ],
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Section Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Manage your income',
                  style: GoogleFonts.manrope(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFD5E2F5),
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '${widget.incomes.length} incomes',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w400,
                  color: const Color(0xFFC6B5AB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Search and Refine Controls
          Row(
            children: [
              Expanded(
                child: Container(
                  height: 36,
                  decoration: BoxDecoration(
                    color: const Color(0xFF24170F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0x70785B4C),
                      width: 1,
                    ),
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.search,
                        size: 16,
                        color: Color(0xFFC6B5AB),
                      ),
                      const SizedBox(width: 6),
                      Expanded(
                        child: TextField(
                          onChanged: (val) => setState(() => _searchQuery = val.trim()),
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            color: const Color(0xFFFFF7EE),
                          ),
                          decoration: InputDecoration(
                            hintText: 'Search income...',
                            hintStyle: GoogleFonts.inter(
                              fontSize: 11,
                              color: const Color(0xFFC6B5AB),
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

              PopupMenuButton<IncomeSortOption>(
                onSelected: (opt) => setState(() => _sortOption = opt),
                color: const Color(0xFF24170F),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: const BorderSide(color: Color(0x70785B4C)),
                ),
                itemBuilder: (ctx) => [
                  for (final opt in IncomeSortOption.values)
                    PopupMenuItem(
                      value: opt,
                      child: Text(
                        opt.label,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          color: _sortOption == opt
                              ? AppColors.primaryOrange
                              : const Color(0xFFFFF7EE),
                          fontWeight: _sortOption == opt ? FontWeight.w700 : FontWeight.w400,
                        ),
                      ),
                    ),
                ],
                child: Container(
                  height: 36,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF24170F),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: const Color(0x70785B4C),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _sortOption.label,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFFFF7EE),
                        ),
                      ),
                      const SizedBox(width: 5),
                      const Icon(
                        Icons.keyboard_arrow_down,
                        size: 14,
                        color: Color(0xFFC6B5AB),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Incomes List or Empty State
          if (filtered.isEmpty)
            Padding(
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
                    child: const Icon(
                      Icons.arrow_downward,
                      size: 26,
                      color: Color(0xFF56D3C7),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'No income recorded yet',
                          style: GoogleFonts.manrope(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: const Color(0xFFFFF7EE),
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Add an income deposit to start tracking inflows.',
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            color: const Color(0xFFC6B5AB),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            )
          else
            ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: filtered.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (context, index) {
                final income = filtered[index];

                return Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF19100B),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: const Color(0x33785B4C),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 42,
                        height: 42,
                        decoration: BoxDecoration(
                          color: const Color(0x2456D3C7),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: const Color(0x5556D3C7),
                            width: 1,
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_downward,
                          size: 20,
                          color: Color(0xFF56D3C7),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              income.source,
                              style: GoogleFonts.manrope(
                                fontSize: 14,
                                fontWeight: FontWeight.w700,
                                color: const Color(0xFFFFF7EE),
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _dateFormat.format(income.receivedOn),
                              style: GoogleFonts.inter(
                                fontSize: 11,
                                color: const Color(0xFFC6B5AB),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '+${formatPesoCents(income.amount)}',
                        style: GoogleFonts.manrope(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: const Color(0xFF56D3C7),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          const SizedBox(height: 12),

          // "+ Add Income" Button
          GestureDetector(
            onTap: widget.onAddIncome,
            behavior: HitTestBehavior.opaque,
            child: Container(
              height: 36,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  colors: [
                    Color(0xFFE57136),
                    Color(0xFFF48648),
                    Color(0xFFFF8D43),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                '+ Add Income',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D110C),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
