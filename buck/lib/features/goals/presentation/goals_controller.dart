import 'package:flutter/material.dart';
import '../data/goal_model.dart';
import '../data/goals_repository.dart';

class GoalsController extends ChangeNotifier {
  final GoalsDataSource? _repository;
  List<GoalItem> _goals;
  bool _isLoading = false;
  String? _error;
  void Function()? _stopWatching;

  GoalsController({
    GoalsDataSource? repository,
    List<GoalItem>? initialGoals,
  })  : _repository = repository,
        _goals = initialGoals != null
            ? List<GoalItem>.from(initialGoals)
            : List<GoalItem>.from(_defaultInitialGoals);

  static const List<GoalItem> _defaultInitialGoals = [
    GoalItem(
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
    GoalItem(
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
    GoalItem(
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
  bool get isLoading => _isLoading;
  String? get error => _error;

  /// Starts live database sync and real-time subscription.
  void start() {
    if (_repository == null) return;
    refresh();
    _stopWatching?.call();
    try {
      _stopWatching = _repository.watch(refresh);
    } catch (_) {
      // Realtime subscription is best-effort
    }
  }

  /// Reloads goals from Supabase (or data source).
  Future<void> refresh() async {
    if (_repository == null) return;
    try {
      _isLoading = true;
      _error = null;
      notifyListeners();

      final loaded = await _repository.loadGoals();
      // If user has saved goals in database, use them; if empty, keep default demo goals
      if (loaded.isNotEmpty) {
        _goals = loaded;
      }
    } catch (e) {
      _error = e.toString();
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  /// Add a brand new goal (persists to Supabase if repository available).
  Future<GoalItem> addGoal({
    required String title,
    required double targetAmount,
    required double initialAmount,
    required String targetDate,
    required IconData icon,
    required Color themeColor,
    required List<Color> gradientColors,
  }) async {
    if (_repository != null) {
      try {
        final saved = await _repository.addGoal(
          title: title,
          targetAmount: targetAmount,
          initialAmount: initialAmount,
          targetDate: targetDate,
          icon: icon,
          themeColor: themeColor,
          gradientColors: gradientColors,
        );
        _goals = [saved, ..._goals];
        notifyListeners();
        return saved;
      } catch (_) {
        // Fallback to in-memory on error
      }
    }

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
    return newGoal;
  }

  /// Allocate dynamic funds to a goal from a wallet.
  Future<bool> allocateFunds(
    String goalId,
    double amount, {
    String? walletId,
  }) async {
    if (amount <= 0) return false;

    if (_repository != null) {
      try {
        await _repository.allocateFunds(
          goalId: goalId,
          amount: amount,
          walletId: walletId,
        );
      } catch (_) {
        // Continue to update local state so UI responds immediately
      }
    }

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

  /// Delete a goal.
  Future<void> deleteGoal(String goalId) async {
    if (_repository != null) {
      try {
        await _repository.deleteGoal(goalId);
      } catch (_) {
        // Local removal fallback
      }
    }
    _goals.removeWhere((g) => g.id == goalId);
    notifyListeners();
  }

  @override
  void dispose() {
    _stopWatching?.call();
    super.dispose();
  }
}
