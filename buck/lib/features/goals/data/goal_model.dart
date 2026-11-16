import 'package:flutter/material.dart';

enum GoalStatus { onTrack, inProgress, completed }

class GoalItem {
  final String id;
  final String title;
  final String targetDate;
  final GoalStatus status;
  final double currentAmount;
  final double targetAmount;
  final IconData icon;
  final Color themeColor;
  final List<Color> gradientColors;

  const GoalItem({
    required this.id,
    required this.title,
    required this.targetDate,
    required this.status,
    required this.currentAmount,
    required this.targetAmount,
    required this.icon,
    required this.themeColor,
    required this.gradientColors,
  });

  double get progress =>
      targetAmount <= 0 ? 1.0 : (currentAmount / targetAmount).clamp(0.0, 1.0);

  double get remaining =>
      (targetAmount - currentAmount).clamp(0.0, double.infinity);

  double get percentage => progress * 100;

  GoalItem copyWith({
    String? title,
    String? targetDate,
    GoalStatus? status,
    double? currentAmount,
    double? targetAmount,
    IconData? icon,
    Color? themeColor,
    List<Color>? gradientColors,
  }) {
    final newCurrent = currentAmount ?? this.currentAmount;
    final newTarget = targetAmount ?? this.targetAmount;
    GoalStatus computedStatus = status ?? this.status;

    if (newCurrent >= newTarget && newTarget > 0) {
      computedStatus = GoalStatus.completed;
    } else if (computedStatus == GoalStatus.completed && newCurrent < newTarget) {
      computedStatus = GoalStatus.inProgress;
    }

    return GoalItem(
      id: id,
      title: title ?? this.title,
      targetDate: targetDate ?? this.targetDate,
      status: computedStatus,
      currentAmount: newCurrent,
      targetAmount: newTarget,
      icon: icon ?? this.icon,
      themeColor: themeColor ?? this.themeColor,
      gradientColors: gradientColors ?? this.gradientColors,
    );
  }

  factory GoalItem.fromRow(Map<String, dynamic> row) {
    final title = (row['goal_name'] as String?)?.trim() ?? 'Untitled Goal';
    final targetAmount = _toDouble(row['target_amount']);
    final currentAmount = _toDouble(row['current_amount']);
    final isExplicitCompleted = (row['completed'] as bool?) ?? false;
    final isCompleted = isExplicitCompleted || (currentAmount >= targetAmount && targetAmount > 0);
    final isActive = (row['is_active'] as bool?) ?? false;

    final rawDate = row['target_date'];
    String formattedDate = '';
    if (rawDate != null) {
      try {
        final parsed = DateTime.parse(rawDate.toString());
        const months = [
          'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
          'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
        ];
        formattedDate = 'Target: ${months[parsed.month - 1]} ${parsed.year}';
      } catch (_) {
        formattedDate = 'Target: $rawDate';
      }
    }

    final visuals = visualsForTitle(title, row['attitude'] as String?);

    final status = isCompleted
        ? GoalStatus.completed
        : (isActive ? GoalStatus.onTrack : GoalStatus.inProgress);

    return GoalItem(
      id: row['id'] as String,
      title: title,
      targetDate: formattedDate.isEmpty ? 'No target date' : formattedDate,
      status: status,
      currentAmount: currentAmount,
      targetAmount: targetAmount,
      icon: visuals.$1,
      themeColor: visuals.$2,
      gradientColors: visuals.$3,
    );
  }

  static (IconData, Color, List<Color>) visualsForTitle(
    String title, [
    String? attitude,
  ]) {
    final lower = title.toLowerCase();
    if (lower.contains('emergency') ||
        lower.contains('buffer') ||
        lower.contains('shield')) {
      return (
        Icons.shield_outlined,
        const Color(0xFFFF8E5D),
        const [Color(0xFFFF8E5D), Color(0xFFFF6A13)],
      );
    }
    if (lower.contains('vacation') ||
        lower.contains('travel') ||
        lower.contains('trip') ||
        lower.contains('flight') ||
        lower.contains('holiday')) {
      return (
        Icons.location_on_outlined,
        const Color(0xFF9B72F2),
        const [Color(0xFF9B72F2), Color(0xFF7C3AED)],
      );
    }
    if (lower.contains('laptop') ||
        lower.contains('tech') ||
        lower.contains('pc') ||
        lower.contains('gadget') ||
        lower.contains('phone') ||
        lower.contains('macbook') ||
        lower.contains('computer')) {
      return (
        Icons.laptop_mac_outlined,
        const Color(0xFF35B9D3),
        const [Color(0xFF35B9D3), Color(0xFF00CCFF)],
      );
    }
    if (lower.contains('car') ||
        lower.contains('vehicle') ||
        lower.contains('bike') ||
        lower.contains('motor')) {
      return (
        Icons.directions_car_outlined,
        const Color(0xFFF59E0B),
        const [Color(0xFFF59E0B), Color(0xFFD97706)],
      );
    }
    if (lower.contains('home') ||
        lower.contains('house') ||
        lower.contains('rent') ||
        lower.contains('apartment')) {
      return (
        Icons.home_outlined,
        const Color(0xFF4ADE80),
        const [Color(0xFF4ADE80), Color(0xFF22C55E)],
      );
    }
    if (attitude?.toLowerCase() == 'aggressive') {
      return (
        Icons.trending_up,
        const Color(0xFF35B9D3),
        const [Color(0xFF35B9D3), Color(0xFF00CCFF)],
      );
    }
    return (
      Icons.savings_outlined,
      const Color(0xFFFF8E5D),
      const [Color(0xFFFF8E5D), Color(0xFFFF6A13)],
    );
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
