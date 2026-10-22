import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/utils/currency.dart';
import '../../../../core/widgets/buck_glass_card.dart';
import '../../../finance/data/finance_models.dart';
import '../../data/expense_entry.dart';

/// Figma "Card / Recent Expenses" (2310:522): scrollable list with a
/// pinned "Total Spending" footer.
class RecentExpensesCard extends StatefulWidget {
  /// Expenses to list, newest first.
  final List<ExpenseRecord> expenses;
  final VoidCallback? onAdd;
  final ValueChanged<ExpenseRecord>? onTapExpense;

  const RecentExpensesCard({
    super.key,
    required this.expenses,
    this.onAdd,
    this.onTapExpense,
  });

  static final _dateFormat = DateFormat('MMM dd, yyyy');

  static String formatAmount(double amount) => formatPesoCents(-amount);

  @override
  State<RecentExpensesCard> createState() => _RecentExpensesCardState();
}

class _RecentExpensesCardState extends State<RecentExpensesCard> {
  final _scrollController = ScrollController();

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.expenses.fold<double>(0, (sum, e) => sum + e.amount);

    return BuckGlassCard(
      height: 300,
      radius: 20,
      glowBlur: 28,
      // Figma stacks black @20% over black @70%.
      background: const Color(0xC2000000),
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(19),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _ListHeader(onAdd: widget.onAdd),
            const Padding(
              padding: EdgeInsets.fromLTRB(15, 13, 16, 15),
              child: ColoredBox(
                color: AppColors.subtleDivider,
                child: SizedBox(height: 1),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(left: 15, right: 1, bottom: 2),
                child: RawScrollbar(
                  controller: _scrollController,
                  thumbVisibility: true,
                  trackVisibility: true,
                  thickness: 4,
                  radius: const Radius.circular(2),
                  trackRadius: const Radius.circular(2),
                  thumbColor: AppColors.textAccent,
                  trackColor: AppColors.inputBg,
                  trackBorderColor: Colors.transparent,
                  child: widget.expenses.isEmpty
                      ? const _EmptyList()
                      : ListView.separated(
                          controller: _scrollController,
                          padding: const EdgeInsets.only(right: 16),
                          itemCount: widget.expenses.length,
                          separatorBuilder: (_, __) => const ColoredBox(
                            color: AppColors.inputBg,
                            child: SizedBox(height: 1),
                          ),
                          itemBuilder: (context, i) => _ExpenseRow(
                            entry: widget.expenses[i],
                            onTap: widget.onTapExpense == null
                                ? null
                                : () =>
                                      widget.onTapExpense!(widget.expenses[i]),
                          ),
                        ),
                ),
              ),
            ),
            Container(
              height: 44,
              color: AppColors.listFooterBg,
              padding: const EdgeInsets.only(left: 16, right: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'TOTAL SPENDING',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.6,
                      color: AppColors.textAccent,
                    ),
                  ),
                  Text(
                    RecentExpensesCard.formatAmount(total),
                    style: AppTextStyles.amountSmall,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ListHeader extends StatelessWidget {
  final VoidCallback? onAdd;

  const _ListHeader({this.onAdd});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(15, 13, 17, 0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 2,
              children: [
                Text(
                  'RECENT',
                  style: GoogleFonts.inter(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
                    color: AppColors.textAccent,
                  ),
                ),
                Text(
                  'Added Expenses',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
          _PlusButton(onTap: onAdd),
        ],
      ),
    );
  }
}

class _PlusButton extends StatefulWidget {
  final VoidCallback? onTap;

  const _PlusButton({this.onTap});

  @override
  State<_PlusButton> createState() => _PlusButtonState();
}

class _PlusButtonState extends State<_PlusButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: 'Add expense',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = true),
        onTapUp: widget.onTap == null
            ? null
            : (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _pressed ? 0.88 : 1.0,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOutCubic,
          child: Container(
            width: 25,
            height: 25,
            alignment: Alignment.center,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: [
                  AppColors.gradientOrangeStart,
                  Color(0xFFF48648),
                  AppColors.gradientOrangeEnd,
                ],
                stops: [0, 0.2562, 0.6532],
              ),
              boxShadow: [
                BoxShadow(
                  color: Color(0x40000000),
                  offset: Offset(0, 2),
                  blurRadius: 3,
                ),
              ],
            ),
            child: SvgPicture.asset('assets/icons/plus.svg'),
          ),
        ),
      ),
    );
  }
}

class _ExpenseRow extends StatefulWidget {
  final ExpenseRecord entry;
  final VoidCallback? onTap;

  const _ExpenseRow({required this.entry, this.onTap});

  @override
  State<_ExpenseRow> createState() => _ExpenseRowState();
}

class _ExpenseRowState extends State<_ExpenseRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = true),
      onTapUp: widget.onTap == null
          ? null
          : (_) => setState(() => _pressed = false),
      onTapCancel: () => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.7 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: SizedBox(
          height: 44,
          child: Row(
            spacing: 10,
            children: [
              Container(
                width: 36,
                height: 36,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.inputBg,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: _CategoryIcon(widget.entry.categoryName),
              ),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: 3,
                  children: [
                    Text(
                      widget.entry.categoryName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    Text(
                      RecentExpensesCard._dateFormat.format(widget.entry.spentOn),
                      style: AppTextStyles.caption,
                    ),
                  ],
                ),
              ),
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerRight,
                  child: Text(
                    RecentExpensesCard.formatAmount(widget.entry.amount),
                    style: AppTextStyles.amountSmall,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CategoryIcon extends StatelessWidget {
  final String categoryName;

  const _CategoryIcon(this.categoryName);

  @override
  Widget build(BuildContext context) {
    final asset = expenseCategoryIcon(categoryName);
    if (asset != null) return SvgPicture.asset(asset);
    return const Icon(
      Icons.receipt_long_outlined,
      size: 18,
      color: AppColors.navBarIcon,
    );
  }
}

class _EmptyList extends StatelessWidget {
  const _EmptyList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.only(right: 16),
        child: Text(
          'No expenses this month yet.',
          textAlign: TextAlign.center,
          style: AppTextStyles.caption.copyWith(fontSize: 13),
        ),
      ),
    );
  }
}
