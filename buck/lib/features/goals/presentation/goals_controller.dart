import 'package:flutter/material.dart';
import '../data/goal_model.dart';

class GoalsController extends ChangeNotifier {
  List<GoalItem> _goals;

  GoalsController({List<GoalItem>? initialGoals})
      : _goals = initialGoals ??
            [
              const GoalItem(
                id: 'emergency-fund',
                title: 'Emergency Fund',
                targetDate: 'Target: Dec 2025',
                status: GoalStatus.onTrack,
                currentAmount: 45200,
                targetAmount: 100000,
                icon: Icons.shield_outlined,
                themeColor: Color(0xFFFF8E5D),
                gradientColors: [Color(0xFFFF8E5D), Color(0xFFFF6A13)],
              ),
              const GoalItem(
                id: 'vacation-fund',
                title: 'Vacation Fund',
                targetDate: 'Target: Jun 2025',
                status: GoalStatus.completed,
                currentAmount: 30000,
                targetAmount: 30000,
                icon: Icons.location_on_outlined,
                themeColor: Color(0xFF9B72F2),
                gradientColors: [Color(0xFF9B72F2), Color(0xFF7C3AED)],
              ),
              const GoalItem(
                id: 'new-laptop',
                title: 'New Laptop',
                targetDate: 'Target: Mar 2026',
                status: GoalStatus.inProgress,
                currentAmount: 18500,
                targetAmount: 65000,
                icon: Icons.laptop_mac_outlined,
                themeColor: Color(0xFF35B9D3),
                gradientColors: [Color(0xFF35B9D3), Color(0xFF00CCFF)],
              ),
            ];

  List<GoalItem> get goals => List.unmodifiable(_goals);

  /// Add a brand new non-static goal created by the user.
  void addGoal({
    required String title,
    required double targetAmount,
    required double initialAmount,
    required String targetDate,
    required IconData icon,
    required Color themeColor,
    required List<Color> gradientColors,
  }) {
    final status = initialAmount >= targetAmount
        ? GoalStatus.completed
        : GoalStatus.inProgress;

    final newGoal = GoalItem(
      id: 'goal-${DateTime.now().millisecondsSinceEpoch}',
      title: title.trim(),
      targetDate: targetDate,
      status: status,
      currentAmount: initialAmount,
      targetAmount: targetAmount,
      icon: icon,
      themeColor: themeColor,
      gradientColors: gradientColors,
    );

    _goals = [newGoal, ..._goals];
    notifyListeners();
  }

  /// Allocate dynamic funds to a goal from a wallet.
  bool allocateFunds(String goalId, double amount) {
    if (amount <= 0) return false;

    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return false;

    final current = _goals[index];
    final updatedCurrent = current.currentAmount + amount;

    _goals[index] = current.copyWith(
      currentAmount: updatedCurrent,
    );

    notifyListeners();
    return true;
  }

  /// Delete a goal if needed.
  void deleteGoal(String goalId) {
    _goals.removeWhere((g) => g.id == goalId);
    notifyListeners();
  }
}
