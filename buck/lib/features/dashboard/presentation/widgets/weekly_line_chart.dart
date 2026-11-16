import 'package:flutter/material.dart';

/// Daily spend line with a fading cyan area, styled after the Figma
/// "line graph" (2306:344): #2C93B8 1.5px stroke over #00CCFF @26% fill.
class WeeklyLineChart extends StatelessWidget {
  /// One value per day, Monday first.
  final List<double> values;
  final double height;

  const WeeklyLineChart({super.key, required this.values, this.height = 62});

  @override
  Widget build(BuildContext context) {
    final total = values.fold<double>(0, (a, b) => a + b);
    return Semantics(
      label: 'Spending by day this week',
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0.0, end: 1.0),
          duration: const Duration(milliseconds: 650),
          curve: Curves.easeOutCubic,
          builder: (context, progress, child) {
            return CustomPaint(
              painter: _LinePainter(
                values,
                empty: total <= 0,
                progress: progress,
              ),
            );
          },
        ),
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> values;
  final bool empty;
  final double progress;

  _LinePainter(this.values, {required this.empty, required this.progress});

  static const _stroke = Color(0xFF2C93B8);
  static const _fill = Color(0xFF00CCFF);

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    const inset = 0.75; // keep the stroke inside the box
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final usableHeight = size.height - inset * 2;

    Offset point(int i) {
      final x = size.width * i / (values.length - 1);
      final ratio = empty || maxValue <= 0
          ? 0.0
          : (values[i] / maxValue) * progress;
      return Offset(x, inset + usableHeight * (1 - ratio));
    }

    final line = Path()..moveTo(point(0).dx, point(0).dy);
    for (var i = 1; i < values.length; i++) {
      line.lineTo(point(i).dx, point(i).dy);
    }

    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          stops: const [0.2, 1],
          colors: [_fill.withValues(alpha: 0.26), _fill.withValues(alpha: 0)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawPath(
      line,
      Paint()
        ..color = _stroke
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5
        ..strokeJoin = StrokeJoin.round,
    );
  }

  @override
  bool shouldRepaint(_LinePainter old) =>
      old.empty != empty ||
      old.progress != progress ||
      !_listEquals(old.values, values);

  static bool _listEquals(List<double> a, List<double> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}
