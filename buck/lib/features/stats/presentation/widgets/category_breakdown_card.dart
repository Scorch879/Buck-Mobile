import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../domain/stats_data.dart';
import 'category_donut_chart.dart';

/// Category Breakdown Card matching Figma node #2402:1560 and #2402:1330 (Default & Expanded Variant 2).
class CategoryBreakdownCard extends StatefulWidget {
  final StatsSummary summary;
  final StatsPeriod selectedPeriod;
  final ValueChanged<StatsPeriod> onPeriodChanged;
  final String? selectedCategoryId;
  final ValueChanged<String?> onCategoryChanged;

  const CategoryBreakdownCard({
    super.key,
    required this.summary,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    required this.selectedCategoryId,
    required this.onCategoryChanged,
  });

  @override
  State<CategoryBreakdownCard> createState() => _CategoryBreakdownCardState();
}

class _CategoryBreakdownCardState extends State<CategoryBreakdownCard> {
  bool _expanded = false;

  void _toggleExpanded() {
    setState(() => _expanded = !_expanded);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.glassCardBg,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: AppColors.glassCardBorder,
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
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // 1. Header (Eyebrow, Title, Period Filter Pills - Figma: #2404:542)
          _buildHeader(),
          const SizedBox(height: 16),

          // 2. Body (Side Categories + Donut Chart - Figma: #2404:553)
          _buildBody(),
          const SizedBox(height: 14),

          // 3. Expandable Section (Figma Variant 2: Categories breakdown list & hint)
          AnimatedSize(
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeInOutCubic,
            child: _expanded ? _buildExpandedSection() : const SizedBox.shrink(),
          ),

          // 4. Expand Handle / Indicator (Figma: #2402:1421)
          _buildExpandButton(),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'CATEGORY SPENDING',
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
            color: const Color(0xFFD98B5C),
          ),
        ),
        const SizedBox(height: 4),
        // Frame #2404:544: Column with Title and Filter Pills
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Category Breakdown',
              style: GoogleFonts.manrope(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFD5E2F5),
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 8),
            // Period Filter Pills row with wrap (Figma: #2404:546)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final period in StatsPeriod.values)
                  _buildPeriodPill(
                    period: period,
                    isActive: widget.selectedPeriod == period,
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildPeriodPill({
    required StatsPeriod period,
    required bool isActive,
  }) {
    return GestureDetector(
      onTap: () => widget.onPeriodChanged(period),
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: isActive
            ? const EdgeInsets.symmetric(horizontal: 12, vertical: 5)
            : const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: isActive
              ? const LinearGradient(
                  colors: [Color(0xFFE57136), Color(0xFFFF8D43)],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                )
              : null,
          color: isActive ? null : const Color(0xFF3A2218),
        ),
        child: Text(
          period.label,
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
            color: isActive ? const Color(0xFF1D110C) : const Color(0xFFC6B5AB),
          ),
        ),
      ),
    );
  }

  Widget _buildBody() {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // Left: Side Categories List (Figma: #2402:1288)
        SizedBox(
          width: 135,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: 8,
            children: [
              // "All" item
              _buildAllCategoryItem(),

              // Core Categories from Figma
              for (final cat in widget.summary.categories)
                _buildCategoryItem(cat),
            ],
          ),
        ),

        // Right: Donut / Piegraph Frame (Figma: #2402:1313)
        Expanded(
          child: Center(
            child: CategoryDonutChart(
              summary: widget.summary,
              selectedCategoryId: widget.selectedCategoryId,
              onSelectCategory: widget.onCategoryChanged,
              size: 140,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildAllCategoryItem() {
    final isSelected = widget.selectedCategoryId == null;

    if (isSelected) {
      return GestureDetector(
        onTap: () => widget.onCategoryChanged(null),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          decoration: BoxDecoration(
            gradient: const LinearGradient(
              colors: [Color(0xFFE57136), Color(0xFFFF8D43)],
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  color: Color(0xFF1D110C),
                ),
              ),
              const SizedBox(width: 6),
              Text(
                'All',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFF1D110C),
                ),
              ),
            ],
          ),
        ),
      );
    }

    return GestureDetector(
      onTap: () => widget.onCategoryChanged(null),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                color: Color(0xFFFF8D43),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'All',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFC6B5AB),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryItem(StatsCategory cat) {
    final isSelected = widget.selectedCategoryId == cat.id;

    return GestureDetector(
      onTap: () {
        if (isSelected) {
          widget.onCategoryChanged(null);
        } else {
          widget.onCategoryChanged(cat.id);
        }
      },
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
        decoration: isSelected
            ? BoxDecoration(
                color: cat.color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: cat.color.withValues(alpha: 0.4),
                  width: 1,
                ),
              )
            : null,
        child: Row(
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: cat.color,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                cat.name,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                  color: isSelected ? const Color(0xFFFFF7EE) : const Color(0xFFC6B5AB),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 4),
            Text(
              cat.formattedPercent,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: cat.color,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildExpandedSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        // Divider (Figma: #2402:1346)
        Container(
          height: 1,
          color: const Color(0x33FF994A), // rgba(255, 153, 74, 0.2)
        ),
        const SizedBox(height: 16),

        // Subheading (Figma: #2402:1388)
        Text(
          'CATEGORIES',
          style: GoogleFonts.inter(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.4,
            color: const Color(0xFFD98B5C),
          ),
        ),
        const SizedBox(height: 10),

        // Category Detail Breakdown Rows (Figma: #2402:1389 - #2402:1413)
        for (final cat in widget.summary.categories)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: cat.color,
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      cat.name,
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                        color: const Color(0xFFD5E2F5),
                      ),
                    ),
                  ],
                ),
                Text(
                  formatPesoCents(cat.amount),
                  style: GoogleFonts.manrope(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFFF7EE),
                  ),
                ),
              ],
            ),
          ),

        const SizedBox(height: 12),
        // Bottom Hint (Figma: #2402:1347 - #2402:1349)
        Row(
          children: [
            Container(
              width: 4,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFFF8E5D),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(width: 6),
            Text(
              'Tap a slice to filter by category',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFC6B5AB),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }

  Widget _buildExpandButton() {
    return GestureDetector(
      key: const Key('expand_button'),
      onTap: _toggleExpanded,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.only(top: 8, bottom: 2),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _expanded ? 23 : 37,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xEBFF994A), // rgba(255, 153, 74, 0.92)
                borderRadius: _expanded
                    ? const BorderRadius.vertical(top: Radius.circular(3))
                    : const BorderRadius.vertical(bottom: Radius.circular(3)),
              ),
            ),
            const SizedBox(height: 6),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: _expanded ? 37 : 23,
              height: 3,
              decoration: BoxDecoration(
                color: const Color(0xEBFF994A), // rgba(255, 153, 74, 0.92)
                borderRadius: _expanded
                    ? const BorderRadius.vertical(top: Radius.circular(3))
                    : const BorderRadius.vertical(bottom: Radius.circular(3)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
