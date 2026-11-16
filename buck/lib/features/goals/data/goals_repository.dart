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
    String? walletId,
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
/// Reads `public.goals` (excluding soft-deleted rows) and uses transactional
/// Postgres RPCs for atomic goal creation, wallet debits, and fund allocation.
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
        .isFilter('deleted_at', null)
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
    String? walletId,
  }) async {
    final dateStr = _formatTargetDate(targetDate);
    final row = await _client.rpc(
      'create_goal_atomic',
      params: {
        'p_goal_name': title.trim(),
        'p_target_amount': targetAmount,
        'p_initial_amount': initialAmount,
        'p_target_date': dateStr,
        'p_wallet_id':
            (initialAmount > 0 && walletId != null && walletId.isNotEmpty)
                ? walletId
                : null,
        'p_attitude': 'Moderate',
      },
    );

    if (row is! Map<String, dynamic>) {
      throw StateError('Unexpected create_goal_atomic response');
    }
    return GoalItem.fromRow(row);
  }

  @override
  Future<bool> allocateFunds({
    required String goalId,
    required double amount,
    String? walletId,
  }) async {
    if (amount <= 0) return false;
    await _client.rpc(
      'allocate_goal_funds_atomic',
      params: {
        'p_goal_id': goalId,
        'p_amount': amount,
        'p_wallet_id':
            (walletId != null && walletId.isNotEmpty) ? walletId : null,
      },
    );
    return true;
  }

  @override
  Future<void> deleteGoal(String goalId) async {
    final userId = _userId;
    // Soft-delete aligns with `check_goal_deletion` (which preserves ledger
    // integrity by blocking hard deletes on goals with allocated funds).
    await _client
        .from('goals')
        .update({
          'deleted_at': DateTime.now().toUtc().toIso8601String(),
          'is_active': false,
        })
        .eq('id', goalId)
        .eq('user_id', userId);
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

  static String _formatTargetDate(String targetDate) {
    final cleaned = targetDate.replaceFirst('Target:', '').trim();
    DateTime? parsedDate;
    try {
      final monthYear = DateFormat('MMM yyyy').parseStrict(cleaned);
      parsedDate = DateTime(monthYear.year, monthYear.month + 1, 0);
    } on FormatException {
      parsedDate = DateTime.tryParse(cleaned);
    }
    parsedDate ??= DateTime.now().add(const Duration(days: 365));
    return '${parsedDate.year.toString().padLeft(4, '0')}-'
        '${parsedDate.month.toString().padLeft(2, '0')}-'
        '${parsedDate.day.toString().padLeft(2, '0')}';
  }
}
