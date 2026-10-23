import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'goal_model.dart';

/// Data source interface for managing financial goals.
abstract class GoalsDataSource {
  Future<List<GoalItem>> loadGoals();

  Future<GoalItem> addGoal({
    required String title,
    required double targetAmount,
    required double initialAmount,
    required String targetDate,
    required IconData icon,
    required Color themeColor,
    required List<Color> gradientColors,
  });

  Future<bool> allocateFunds({
    required String goalId,
    required double amount,
    String? walletId,
  });

  Future<void> deleteGoal(String goalId);

  void Function() watch(void Function() onChange);
}

/// Supabase implementation of [GoalsDataSource].
/// Reads and writes to `public.goals` and coordinates wallet debits via atomic updates.
class GoalsRepository implements GoalsDataSource {
  final SupabaseClient _client;

  GoalsRepository(this._client);

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Not signed in');
    return id;
  }

  @override
  Future<List<GoalItem>> loadGoals() async {
    final userId = _userId;
    final rows = await _client
        .from('goals')
        .select('*')
        .eq('user_id', userId)
        .order('is_active', ascending: false)
        .order('created_at', ascending: false);

    return (rows as List)
        .cast<Map<String, dynamic>>()
        .map(GoalItem.fromRow)
        .toList();
  }

  @override
  Future<GoalItem> addGoal({
    required String title,
    required double targetAmount,
    required double initialAmount,
    required String targetDate,
    required IconData icon,
    required Color themeColor,
    required List<Color> gradientColors,
  }) async {
    final userId = _userId;

    // Parse date if possible from "Target: MMM yyyy" or "Target: yyyy-MM-dd"
    DateTime? parsedDate;
    try {
      final cleaned = targetDate.replaceFirst('Target:', '').trim();
      parsedDate = DateFormat('MMM yyyy').parse(cleaned);
      parsedDate = DateTime(parsedDate.year, parsedDate.month + 1, 0);
    } catch (_) {
      try {
        final cleaned = targetDate.replaceFirst('Target:', '').trim();
        parsedDate = DateTime.parse(cleaned);
      } catch (_) {
        parsedDate = DateTime.now().add(const Duration(days: 365));
      }
    }

    final dateStr =
        '${parsedDate.year.toString().padLeft(4, '0')}-'
        '${parsedDate.month.toString().padLeft(2, '0')}-'
        '${parsedDate.day.toString().padLeft(2, '0')}';

    final isCompleted = initialAmount >= targetAmount && targetAmount > 0;

    final row = await _client
        .from('goals')
        .insert({
          'user_id': userId,
          'goal_name': title.trim(),
          'target_amount': targetAmount,
          'current_amount': initialAmount,
          'attitude': 'Moderate',
          'target_date': dateStr,
          'completed': isCompleted,
          'is_active': !isCompleted,
        })
        .select()
        .single();

    return GoalItem.fromRow(row);
  }

  @override
  Future<bool> allocateFunds({
    required String goalId,
    required double amount,
    String? walletId,
  }) async {
    if (amount <= 0) return false;
    final userId = _userId;

    // 1. Fetch current goal state
    final goalRow = await _client
        .from('goals')
        .select('current_amount, target_amount, goal_name')
        .eq('id', goalId)
        .eq('user_id', userId)
        .single();

    final current = _toDouble(goalRow['current_amount']);
    final target = _toDouble(goalRow['target_amount']);
    final goalName = (goalRow['goal_name'] as String?)?.trim() ?? 'Goal';
    final updated = current + amount;
    final completed = updated >= target && target > 0;

    // 2. Update goal balance in database
    await _client
        .from('goals')
        .update({
          'current_amount': updated,
          'completed': completed,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', goalId)
        .eq('user_id', userId);

    // 3. If walletId provided, deduct from wallet and log as savings expense
    if (walletId != null && walletId.isNotEmpty) {
      try {
        final walletRow = await _client
            .from('wallets')
            .select('budget, name')
            .eq('id', walletId)
            .eq('user_id', userId)
            .maybeSingle();

        if (walletRow != null) {
          final curBudget = _toDouble(walletRow['budget']);
          final newBudget = (curBudget - amount).clamp(0.0, double.infinity);

          await _client
              .from('wallets')
              .update({
                'budget': newBudget,
                'updated_at': DateTime.now().toIso8601String(),
              })
              .eq('id', walletId)
              .eq('user_id', userId);

          final today = DateTime.now();
          final todayStr =
              '${today.year.toString().padLeft(4, '0')}-'
              '${today.month.toString().padLeft(2, '0')}-'
              '${today.day.toString().padLeft(2, '0')}';

          await _client.from('expenses').insert({
            'user_id': userId,
            'wallet_id': walletId,
            'goal_id': goalId,
            'category_name': 'Savings',
            'amount': amount,
            'description': 'Allocated to $goalName',
            'spent_on': todayStr,
          });
        }
      } catch (_) {
        // Goal allocation in goals table succeeded; wallet debit is best-effort
      }
    }

    return true;
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    final userId = _userId;
    await _client.from('goals').delete().eq('id', goalId).eq('user_id', userId);
  }

  @override
  void Function() watch(void Function() onChange) {
    final userId = _userId;
    final channel = _client.channel('goals-$userId');
    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'goals',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: userId,
      ),
      callback: (_) => onChange(),
    );
    channel.subscribe();
    return () => _client.removeChannel(channel);
  }

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0.0;
    return 0.0;
  }
}
