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
}
