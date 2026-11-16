import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/utils/currency.dart';
import '../../domain/stats_data.dart';

/// Spending Trend Card matching Figma node #2462:577 ("Line Graph Card").
///
/// Features dynamic data points, Y-axis scale, horizontal guide lines,
/// smooth curved gradient area, category-based accent coloring, and touch scrubbing.
class SpendingTrendCard extends StatefulWidget {
  final SpendingTrendData trendData;
  final StatsPeriod selectedPeriod;
  final ValueChanged<StatsPeriod> onPeriodChanged;
  final String? selectedCategoryId;
  final StatsCategory? selectedCategory;
  final VoidCallback? onClearCategory;

  const SpendingTrendCard({
    super.key,
    required this.trendData,
    required this.selectedPeriod,
    required this.onPeriodChanged,
    this.selectedCategoryId,
    this.selectedCategory,
    this.onClearCategory,
  });

  @override
  State<SpendingTrendCard> createState() => _SpendingTrendCardState();
}

class _SpendingTrendCardState extends State<SpendingTrendCard> {
  int? _hoveredIndex;

  @override
  Widget build(BuildContext context) {
    final lineColor = StatsCalculator.trendColor(widget.selectedCategoryId);

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
          // 1. Header (Title + Category Badge + Time Filters - Figma: #2462:562, #2462:569)
          _buildHeader(lineColor),
          const SizedBox(height: 14),

          // 2. Interactive Line Chart with Y-Axis and X-Axis
          SizedBox(
            height: 175,
            child: _buildChart(lineColor),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(Color lineColor) {
    final cat = widget.selectedCategory;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title Row
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                'Spending Trend',
                style: GoogleFonts.manrope(
                  fontSize: 22,
                  fontWeight: FontWeight.w700,
                  letterSpacing: -0.2,
                  color: const Color(0xFFD5E2F5),
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (cat != null)
              GestureDetector(
                onTap: widget.onClearCategory,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(
                    color: cat.color.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: cat.color.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: cat.color,
                        ),
                      ),
                      const SizedBox(width: 5),
                      Text(
                        cat.name,
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          color: cat.color,
                        ),
                      ),
                      const SizedBox(width: 4),
                      Icon(
                        Icons.close,
                        size: 11,
                        color: cat.color,
                      ),
                    ],
                  ),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),

        // Time Filters Row (Figma: #2462:569)
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

  Widget _buildChart(Color lineColor) {
    final points = widget.trendData.points;
    final maxAmount = widget.trendData.maxAmount;

    // Determine scale ceiling for Y-axis (4 levels: 100%, 75%, 50%, 25%)
    final double scaleCeiling;
    if (maxAmount <= 0) {
      scaleCeiling = 300000;
    } else if (maxAmount < 1000) {
      scaleCeiling = 1000;
    } else if (maxAmount < 10000) {
      scaleCeiling = (math.max(1.0, maxAmount / 2500).ceil() * 2500).toDouble();
    } else if (maxAmount < 100000) {
      scaleCeiling = (math.max(1.0, maxAmount / 25000).ceil() * 25000).toDouble();
    } else {
      scaleCeiling = (math.max(1.0, maxAmount / 75000).ceil() * 75000).toDouble();
    }

    final yLabels = [
      _formatYLabel(scaleCeiling),
      _formatYLabel(scaleCeiling * 0.75),
      _formatYLabel(scaleCeiling * 0.50),
      _formatYLabel(scaleCeiling * 0.25),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        const yAxisWidth = 36.0;
        const chartBottomPadding = 24.0;
        final chartWidth = math.max(10.0, constraints.maxWidth - yAxisWidth);
        final chartHeight = math.max(10.0, constraints.maxHeight - chartBottomPadding);

        return GestureDetector(
          onHorizontalDragUpdate: (details) {
            _updateHover(details.localPosition.dx - yAxisWidth, chartWidth, points.length);
          },
          onTapDown: (details) {
            _updateHover(details.localPosition.dx - yAxisWidth, chartWidth, points.length);
          },
          onHorizontalDragEnd: (_) {
            Future.delayed(const Duration(seconds: 2), () {
              if (mounted) setState(() => _hoveredIndex = null);
            });
          },
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // 1. Left Y-Axis labels (Figma: #2469:581-584)
              Positioned(
                left: 0,
                top: 0,
                bottom: chartBottomPadding,
                width: yAxisWidth,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final label in yLabels)
                      Text(
                        label,
                        style: GoogleFonts.manrope(
                          fontSize: 9,
                          fontWeight: FontWeight.w500,
                          color: const Color(0xD9C6B5AB),
                        ),
                      ),
                  ],
                ),
              ),

              // 2. Custom Painted Chart (Grid lines, Baseline, Smooth curve, Area gradient)
              Positioned(
                left: yAxisWidth,
                top: 0,
                width: chartWidth,
                height: chartHeight,
                child: CustomPaint(
                  size: Size(chartWidth, chartHeight),
                  painter: _SpendingTrendPainter(
                    points: points,
                    scaleCeiling: scaleCeiling,
                    lineColor: lineColor,
                    hoveredIndex: _hoveredIndex,
                  ),
                ),
              ),

              // 3. Bottom X-Axis labels (Figma: #2469:586-588)
              Positioned(
                left: yAxisWidth,
                bottom: 0,
                width: chartWidth,
                height: chartBottomPadding,
                child: _buildXAxisLabels(points),
              ),

              // 4. Interactive Scrubber Tooltip when tapping or dragging
              if (_hoveredIndex != null && _hoveredIndex! >= 0 && _hoveredIndex! < points.length)
                _buildScrubberTooltip(
                  index: _hoveredIndex!,
                  points: points,
                  chartWidth: chartWidth,
                  chartHeight: chartHeight,
                  yAxisWidth: yAxisWidth,
                  scaleCeiling: scaleCeiling,
                  lineColor: lineColor,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildXAxisLabels(List<SpendingTrendPoint> points) {
    if (points.isEmpty) return const SizedBox.shrink();

    // Show evenly spaced labels to prevent crowding
    final step = (points.length / 4).ceil().clamp(1, points.length);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        for (var i = 0; i < points.length; i++)
          if (i == 0 || i == points.length - 1 || i % step == 0)
            Text(
              points[i].label,
              style: GoogleFonts.manrope(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: const Color(0xD9C6B5AB),
              ),
            ),
      ],
    );
  }

  Widget _buildScrubberTooltip({
    required int index,
    required List<SpendingTrendPoint> points,
    required double chartWidth,
    required double chartHeight,
    required double yAxisWidth,
    required double scaleCeiling,
    required Color lineColor,
  }) {
    final pt = points[index];
    final count = points.length;
    final xRatio = count <= 1 ? 0.5 : index / (count - 1);
    final xPos = yAxisWidth + (chartWidth * xRatio);

    final ratio = scaleCeiling <= 0 ? 0.0 : (pt.amount / scaleCeiling).clamp(0.0, 1.0);
    final yPos = chartHeight * (1.0 - ratio);

    return Positioned(
      left: (xPos - 55).clamp(yAxisWidth, yAxisWidth + chartWidth - 110),
      top: math.max(0, yPos - 38),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFF1D0B06),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: lineColor, width: 1),
          boxShadow: const [
            BoxShadow(
              color: Colors.black54,
              blurRadius: 8,
              offset: Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              pt.label,
              style: GoogleFonts.inter(
                fontSize: 9,
                fontWeight: FontWeight.w500,
                color: const Color(0xFFC6B5AB),
              ),
            ),
            Text(
              formatPeso(pt.amount),
              style: GoogleFonts.manrope(
                fontSize: 11,
                fontWeight: FontWeight.w800,
                color: const Color(0xFFFFF7EE),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _updateHover(double localX, double width, int pointCount) {
    if (pointCount <= 1 || width <= 0) return;
    final clampedX = localX.clamp(0.0, width);
    final idx = ((clampedX / width) * (pointCount - 1)).round().clamp(0, pointCount - 1);
    if (_hoveredIndex != idx) {
      setState(() => _hoveredIndex = idx);
    }
  }

  String _formatYLabel(double amount) {
    if (amount >= 1000000) {
      return '${(amount / 1000000).toStringAsFixed(1)}M';
    }
    if (amount >= 1000) {
      final k = amount / 1000;
      return k == k.roundToDouble() ? '${k.round()}k' : '${k.toStringAsFixed(1)}k';
    }
    return amount.round().toString();
  }
}

class _SpendingTrendPainter extends CustomPainter {
  final List<SpendingTrendPoint> points;
  final double scaleCeiling;
  final Color lineColor;
  final int? hoveredIndex;

  _SpendingTrendPainter({
    required this.points,
    required this.scaleCeiling,
    required this.lineColor,
    required this.hoveredIndex,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final width = size.width;
    final height = size.height;

    // 1. Horizontal grid lines (4 lines matching Figma: #2467:574-576, #2469:585)
    final gridPaint = Paint()
      ..color = const Color(0x24C7BDB2) // rgba(199, 189, 178, 0.14)
      ..strokeWidth = 0.5;

    for (var i = 0; i < 4; i++) {
      final y = (height / 4) * i;
      canvas.drawLine(Offset(0, y), Offset(width, y), gridPaint);
    }

    // 2. Baseline at bottom of chart (Figma: #2467:577)
    final baselinePaint = Paint()
      ..color = const Color(0x42C7BDB2) // rgba(199, 189, 178, 0.26)
      ..strokeWidth = 0.5;
    canvas.drawLine(Offset(0, height), Offset(width, height), baselinePaint);

    if (points.isEmpty) return;

    // 3. Compute (x, y) coordinates for all points
    final coordinates = <Offset>[];
    final count = points.length;

    for (var i = 0; i < count; i++) {
      final x = count <= 1 ? width / 2 : (width * i / (count - 1));
      final ratio = scaleCeiling <= 0
          ? 0.0
          : (points[i].amount / scaleCeiling).clamp(0.0, 1.0);
      final y = height * (1.0 - ratio);
      coordinates.add(Offset(x, y));
    }

    if (coordinates.length < 2) {
      final pt = coordinates.first;
      canvas.drawCircle(pt, 4, Paint()..color = lineColor);
      return;
    }

    // 4. Construct smooth cubic spline path
    final linePath = Path()..moveTo(coordinates[0].dx, coordinates[0].dy);

    for (var i = 0; i < coordinates.length - 1; i++) {
      final current = coordinates[i];
      final next = coordinates[i + 1];

      final controlX1 = current.dx + (next.dx - current.dx) / 2;
      final controlY1 = current.dy;
      final controlX2 = current.dx + (next.dx - current.dx) / 2;
      final controlY2 = next.dy;

      linePath.cubicTo(controlX1, controlY1, controlX2, controlY2, next.dx, next.dy);
    }

    // 5. Area path with gradient fill below line (Figma: #2462:567)
    final areaPath = Path.from(linePath)
      ..lineTo(coordinates.last.dx, height)
      ..lineTo(coordinates.first.dx, height)
      ..close();

    final areaGradient = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [
        lineColor.withValues(alpha: 0.16),
        lineColor.withValues(alpha: 0.0),
      ],
    );

    canvas.drawPath(
      areaPath,
      Paint()
        ..shader = areaGradient.createShader(Offset.zero & size)
        ..style = PaintingStyle.fill,
    );

    // 6. Draw line stroke (Figma: #2462:568)
    final linePaint = Paint()
      ..color = lineColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    canvas.drawPath(linePath, linePaint);

    // 7. Latest / active point indicator circle dot (Figma: #2467:578)
    final activePt = hoveredIndex != null && hoveredIndex! < coordinates.length
        ? coordinates[hoveredIndex!]
        : coordinates.last;

    // Glowing halo
    canvas.drawCircle(
      activePt,
      5.5,
      Paint()
        ..color = lineColor.withValues(alpha: 0.3)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );

    // Solid inner dot
    canvas.drawCircle(
      activePt,
      3.5,
      Paint()
        ..color = lineColor
        ..style = PaintingStyle.fill,
    );

    // If hovered, draw subtle vertical indicator line
    if (hoveredIndex != null) {
      final guidePaint = Paint()
        ..color = lineColor.withValues(alpha: 0.4)
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(activePt.dx, 0),
        Offset(activePt.dx, height),
        guidePaint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpendingTrendPainter oldDelegate) {
    return oldDelegate.points != points ||
        oldDelegate.scaleCeiling != scaleCeiling ||
        oldDelegate.lineColor != lineColor ||
        oldDelegate.hoveredIndex != hoveredIndex;
  }
}
