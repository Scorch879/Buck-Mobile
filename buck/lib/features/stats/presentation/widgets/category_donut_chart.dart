import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/utils/currency.dart';
import '../../domain/stats_data.dart';

/// Donut chart rendering category breakdown with Figma-exact segment colors (#2402:655).
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
    this.size = 150,
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
        // 1. Donut Chart Canvas
        GestureDetector(
          onTapUp: (details) => _handleTap(details.localPosition),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(
              size: Size(size, size),
              painter: _DonutChartPainter(
                summary: summary,
                selectedCategoryId: selectedCategoryId,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),

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

    // Donut radius is size/2 * 0.9. Check if tap is inside the ring or outer circle.
    final outerRadius = size / 2;
    if (distance > outerRadius + 8) return;

    if (summary.totalAmount <= 0) {
      onSelectCategory(null);
      return;
    }

    // Calculate angle in radians normalized to [0, 2*pi), starting from top (-pi/2)
    var angle = math.atan2(dy, dx);
    // Convert so 0 is at -pi/2 (12 o'clock)
    angle = (angle + math.pi / 2) % (2 * math.pi);
    if (angle < 0) angle += 2 * math.pi;

    var currentAngle = 0.0;
    for (final cat in summary.categories) {
      if (cat.percentage <= 0) continue;
      final sweep = (cat.percentage / 100.0) * 2 * math.pi;
      if (angle >= currentAngle && angle <= currentAngle + sweep) {
        if (selectedCategoryId == cat.id) {
          // Deselect if already selected
          onSelectCategory(null);
        } else {
          onSelectCategory(cat.id);
        }
        return;
      }
      currentAngle += sweep;
    }

    // Tapped hollow center or empty gap -> reset selection
    onSelectCategory(null);
  }
}

class _DonutChartPainter extends CustomPainter {
  final StatsSummary summary;
  final String? selectedCategoryId;

  _DonutChartPainter({
    required this.summary,
    required this.selectedCategoryId,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final outerRadius = (size.width / 2) * 0.94;
    const strokeWidth = 22.0;
    final ringRadius = outerRadius - (strokeWidth / 2);

    final bgPaint = Paint()
      ..color = const Color(0x1FFFF7EE)
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth;

    // Background track ring
    canvas.drawCircle(center, ringRadius, bgPaint);

    if (summary.totalAmount <= 0) {
      // Empty state dashed or faint ring
      return;
    }

    // Filter categories with non-zero percentage
    final activeCategories = summary.categories.where((c) => c.percentage > 0).toList();
    if (activeCategories.isEmpty) return;

    var startAngle = -math.pi / 2; // Start from 12 o'clock
    const gapAngle = 0.04; // ~2.3 degrees visual gap between segments

    final totalGaps = activeCategories.length > 1 ? activeCategories.length * gapAngle : 0.0;
    final availableAngle = (2 * math.pi) - totalGaps;

    final textPainters = <_ArcLabel>[];

    for (final cat in activeCategories) {
      final sweepAngle = (cat.percentage / 100.0) * availableAngle;
      final isSelected = selectedCategoryId == cat.id;
      final hasSelection = selectedCategoryId != null;

      final paint = Paint()
        ..color = hasSelection
            ? (isSelected ? cat.color : cat.color.withValues(alpha: 0.35))
            : cat.color
        ..style = PaintingStyle.stroke
        ..strokeWidth = isSelected ? strokeWidth + 4.0 : strokeWidth
        ..strokeCap = StrokeCap.round;

      // Draw segment arc
      final arcRect = Rect.fromCircle(
        center: center,
        radius: isSelected ? ringRadius + 1.0 : ringRadius,
      );
      canvas.drawArc(arcRect, startAngle, sweepAngle, false, paint);

      // Prepare percentage label if the arc is wide enough (> 12% or > 0.45 rad)
      if (cat.percentage >= 8.0) {
        final midAngle = startAngle + (sweepAngle / 2);
        final labelRadius = ringRadius;
        final labelX = center.dx + labelRadius * math.cos(midAngle);
        final labelY = center.dy + labelRadius * math.sin(midAngle);

        final span = TextSpan(
          text: '${cat.percentage.round()}%',
          style: GoogleFonts.manrope(
            fontSize: 10,
            fontWeight: FontWeight.w700,
            color: isSelected
                ? const Color(0xFFFFF7EE)
                : const Color(0xFFD5E2F5),
          ),
        );
        final tp = TextPainter(
          text: span,
          textAlign: TextAlign.center,
          textDirection: TextDirection.ltr,
        )..layout();

        textPainters.add(_ArcLabel(tp: tp, offset: Offset(labelX - tp.width / 2, labelY - tp.height / 2)));
      }

      startAngle += sweepAngle + (activeCategories.length > 1 ? gapAngle : 0.0);
    }

    // Paint all percentage labels on top of segments
    for (final label in textPainters) {
      label.tp.paint(canvas, label.offset);
    }
  }

  @override
  bool shouldRepaint(covariant _DonutChartPainter oldDelegate) {
    return oldDelegate.summary != summary ||
        oldDelegate.selectedCategoryId != selectedCategoryId;
  }
}

class _ArcLabel {
  final TextPainter tp;
  final Offset offset;
  _ArcLabel({required this.tp, required this.offset});
}
