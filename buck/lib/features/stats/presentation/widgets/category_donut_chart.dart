import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/currency.dart';
import '../../domain/stats_data.dart';

/// Pie Chart rendering category breakdown with Figma-exact solid slices (#2402:656).
class CategoryDonutChart extends StatelessWidget {
  final StatsSummary summary;
  final String? selectedCategoryId;
  final ValueChanged<String?> onSelectCategory;
  final double size;

  const CategoryDonutChart({
    super.key,
    required this.summary,
    required this.selectedCategoryId,
    required this.onSelectCategory,
    this.size = 148,
  });

  @override
  Widget build(BuildContext context) {
    final selectedCategory = selectedCategoryId != null
        ? summary.findById(selectedCategoryId!)
        : null;

    final displayAmount = selectedCategory != null
        ? selectedCategory.amount
        : summary.totalAmount;

    final displaySubtitle = selectedCategory != null
        ? '${selectedCategory.name.toUpperCase()} TOTAL'
        : summary.period.subtitle.toUpperCase();

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        // 1. Solid Pie Chart Canvas with direct percentage labels
        GestureDetector(
          onTapUp: (details) => _handleTap(details.localPosition),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              size: Size(size, size),
              painter: _PieChartPainter(
                summary: summary,
                selectedCategoryId: selectedCategoryId,
              ),
            ),
          ),
        ),
        const SizedBox(height: 10),

        // 2. Amount Text & Period Subtitle (Figma: #2402:651)
        Text(
          formatPesoCents(displayAmount),
          style: GoogleFonts.manrope(
            fontSize: 18,
            fontWeight: FontWeight.w800,
            color: const Color(0xFFFFF7EE),
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 2),
        Text(
          displaySubtitle,
          style: GoogleFonts.inter(
            fontSize: 10,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: const Color(0xFFC6B5AB),
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  void _handleTap(Offset localPos) {
    final center = Offset(size / 2, size / 2);
    final dx = localPos.dx - center.dx;
    final dy = localPos.dy - center.dy;
    final distance = math.sqrt(dx * dx + dy * dy);

    final outerRadius = size / 2;
    if (distance > outerRadius + 8) return;

    if (summary.totalAmount <= 0) {
      onSelectCategory(null);
      return;
    }

    // Calculate angle in radians normalized to [0, 2*pi), starting from top (-pi/2)
    var angle = math.atan2(dy, dx);
    angle = (angle + math.pi / 2) % (2 * math.pi);
    if (angle < 0) angle += 2 * math.pi;

    var currentAngle = 0.0;
    for (final cat in summary.categories) {
      if (cat.percentage <= 0) continue;
      final sweep = (cat.percentage / 100.0) * 2 * math.pi;
      if (angle >= currentAngle && angle <= currentAngle + sweep) {
        if (selectedCategoryId == cat.id) {
          onSelectCategory(null);
        } else {
          onSelectCategory(cat.id);
        }
        return;
      }
      currentAngle += sweep;
    }

    onSelectCategory(null);
  }
}

class _PieChartPainter extends CustomPainter {
  final StatsSummary summary;
  final String? selectedCategoryId;

  _PieChartPainter({
    required this.summary,
    required this.selectedCategoryId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = (size.width / 2) * 0.96;

    if (summary.totalAmount <= 0) {
      // Empty state circular backdrop
      final emptyPaint = Paint()
        ..color = const Color(0xFF3A2218)
        ..style = PaintingStyle.fill;
      canvas.drawCircle(center, radius, emptyPaint);

      final emptyBorder = Paint()
        ..color = const Color(0x33FF994A)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5;
      canvas.drawCircle(center, radius, emptyBorder);

      final tp = TextPainter(
        text: TextSpan(
          text: 'No data',
          style: GoogleFonts.inter(
            fontSize: 11,
            color: const Color(0xFFC6B5AB),
            fontWeight: FontWeight.w500,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy - tp.height / 2));
      return;
    }

    var startAngle = -math.pi / 2; // 12 o'clock

    // Filter categories with positive amounts
    final activeCategories = summary.categories.where((c) => c.percentage > 0).toList();

    for (final cat in activeCategories) {
      final sweepAngle = (cat.percentage / 100.0) * 2 * math.pi;
      final isSelected = selectedCategoryId == cat.id;

      // Slight outwards offset for selected category slice
      final midAngle = startAngle + (sweepAngle / 2);
      final offsetDist = isSelected ? 6.0 : 0.0;
      final sliceOffset = Offset(
        math.cos(midAngle) * offsetDist,
        math.sin(midAngle) * offsetDist,
      );

      final sliceCenter = center + sliceOffset;
      final sectorRect = Rect.fromCircle(center: sliceCenter, radius: radius);

      // 1. Draw solid sector slice
      final fillPaint = Paint()
        ..color = cat.color
        ..style = PaintingStyle.fill;
      canvas.drawArc(sectorRect, startAngle, sweepAngle, true, fillPaint);

      // 2. Draw border between slices for clean Figma-accurate delineation
      final borderPaint = Paint()
        ..color = isSelected ? const Color(0xFFFF994A) : const Color(0xFF160905)
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? 2.5 : 1.5;
      canvas.drawArc(sectorRect, startAngle, sweepAngle, true, borderPaint);

      // 3. Draw percentage label directly inside the slice (matching Figma #2402:646-650)
      if (cat.percentage >= 6.0) {
        final labelRadius = radius * 0.62;
        final labelPos = Offset(
          sliceCenter.dx + math.cos(midAngle) * labelRadius,
          sliceCenter.dy + math.sin(midAngle) * labelRadius,
        );

        final labelPainter = TextPainter(
          text: TextSpan(
            text: '${cat.percentage.round()}%',
            style: GoogleFonts.manrope(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFFFF7EE),
              shadows: const [
                Shadow(
                  color: Color(0xCC000000),
                  blurRadius: 3,
                  offset: Offset(0, 1),
                ),
              ],
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();

        labelPainter.paint(
          canvas,
          Offset(
            labelPos.dx - labelPainter.width / 2,
            labelPos.dy - labelPainter.height / 2,
          ),
        );
      }

      startAngle += sweepAngle;
    }
  }

  @override
  bool shouldRepaint(_PieChartPainter oldDelegate) {
    return oldDelegate.summary != summary ||
        oldDelegate.selectedCategoryId != selectedCategoryId;
  }
}
