import 'dart:async';

import 'package:flutter/material.dart';
import '../data/goal_model.dart';
import '../data/goals_repository.dart';

class GoalsController extends ChangeNotifier {
  final GoalsDataSource? _repository;
  List<GoalItem> _goals;
  bool _isLoading = false;
  String? _error;
  void Function()? _stopWatching;
  Timer? _debounce;
  bool _disposed = false;

  GoalsController({
    GoalsDataSource? repository,
    List<GoalItem>? initialGoals,
  })  : _repository = repository,
        _goals = initialGoals != null
            ? List<GoalItem>.from(initialGoals)
            : <GoalItem>[];

  bool get hasRepository => _repository != null;
  List<GoalItem> get goals => List.unmodifiable(_goals);
  bool get isLoading => _isLoading;
  String? get error => _error;

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  /// Starts live database sync and real-time subscription.
  void start() {
    if (_repository == null) return;
    refresh();
    _stopWatching?.call();
    try {
      _stopWatching = _repository.watch(_scheduleRefresh);
    } catch (e) {
      debugPrint('Goals realtime unavailable: $e');
    }
  }

  void _scheduleRefresh() {
    if (_disposed) return;
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), refresh);
  }

  /// Reloads goals from Supabase (or data source).
  Future<void> refresh() async {
    if (_repository == null || _disposed) return;
    try {
      _isLoading = true;
      _error = null;
      _notify();

      final loaded = await _repository.loadGoals();
      if (_disposed) return;
      _goals = loaded;
    } catch (e) {
      if (_disposed) return;
      _error = e.toString();
    } finally {
      _isLoading = false;
      _notify();
    }
  }

  /// Add a brand new goal (persists atomically via Supabase if available).
  Future<GoalItem> addGoal({
    required String title,
    required double targetAmount,
    required double initialAmount,
    required String targetDate,
    required IconData icon,
    required Color themeColor,
    required List<Color> gradientColors,
    String? walletId,
  }) async {
    if (_repository != null) {
      final saved = await _repository.addGoal(
        title: title,
        targetAmount: targetAmount,
        initialAmount: initialAmount,
        targetDate: targetDate,
        icon: icon,
        themeColor: themeColor,
        gradientColors: gradientColors,
        walletId: walletId,
      );
      if (!_disposed) {
        _goals = [saved, ..._goals];
        _notify();
      }
      return saved;
    }

    final status = initialAmount >= targetAmount && targetAmount > 0
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

    if (!_disposed) {
      _goals = [newGoal, ..._goals];
      _notify();
    }
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
      final ok = await _repository.allocateFunds(
        goalId: goalId,
        amount: amount,
        walletId: walletId,
      );
      if (!ok || _disposed) return ok;
    }

    final index = _goals.indexWhere((g) => g.id == goalId);
    if (index == -1) return false;

    final current = _goals[index];
    final updatedCurrent = current.currentAmount + amount;

    _goals[index] = current.copyWith(currentAmount: updatedCurrent);
    _notify();
    return true;
  }

  /// Delete a goal cleanly, rethrowing persistence failures instead of hiding them.
  Future<void> deleteGoal(String goalId) async {
    if (_repository != null) {
      await _repository.deleteGoal(goalId);
    }
    if (_disposed) return;
    _goals.removeWhere((g) => g.id == goalId);
    _notify();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _stopWatching?.call();
    super.dispose();
  }
}
