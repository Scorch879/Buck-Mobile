import 'package:supabase_flutter/supabase_flutter.dart';

import 'finance_models.dart';

/// Everything the dashboard / expenses screens read for one user.
class FinanceData {
  final String? profileName;
  final String? activeWalletId;
  final List<Wallet> wallets;
  final List<ExpenseRecord> expenses;

  /// `null` when the `incomes` table is not available yet.
  final List<IncomeRecord>? incomes;
  final List<AiAdvisory> advisories;

  const FinanceData({
    required this.profileName,
    required this.activeWalletId,
    required this.wallets,
    required this.expenses,
    required this.incomes,
    required this.advisories,
  });
}

/// Source of finance data for [FinanceController]; faked in tests.
abstract class FinanceDataSource {
  Future<FinanceData> load({required DateTime now});

  Future<void> addIncome({
    required String walletId,
    required double amount,
    required String source,
    required String description,
    required DateTime receivedOn,
  });

  Future<void> addExpense({
    required String walletId,
    required double amount,
    required String categoryName,
    required String description,
    required DateTime spentOn,
  });

  Future<void> createWallet({
    required String name,
    required double initialBalance,
  });

  Future<void> setActiveWallet(String walletId);

  /// Calls [onChange] whenever the user's data changes.
  /// Returns a function that stops listening.
  void Function() watch(void Function() onChange);
}

/// Reads and writes Buck finance data in the shared Supabase project.
/// Row Level Security limits every query to the signed-in user's rows.
class FinanceRepository implements FinanceDataSource {
  final SupabaseClient _client;

  FinanceRepository(this._client);

  static const _pageSize = 1000;

  String get _userId {
    final id = _client.auth.currentUser?.id;
    if (id == null) throw const AuthException('Not signed in');
    return id;
  }

  @override
  Future<FinanceData> load({required DateTime now}) async {
    final userId = _userId;
    // Incomes from the start of last month cover "this month vs last month".
    final incomesSince = DateTime(now.year, now.month - 1, 1);

    final results = await Future.wait<Object?>([
      _client
          .from('profiles')
          .select('username, active_wallet_id')
          .eq('id', userId)
          .maybeSingle(),
      _client
          .from('wallets')
          .select('id, name, budget')
          .eq('user_id', userId)
          .isFilter('deleted_at', null)
          .order('created_at', ascending: false),
      _loadExpenses(userId),
      _loadIncomes(userId, since: incomesSince),
      _client
          .from('ai_advisories')
          .select('id, title, suggestion, advice')
          .eq('user_id', userId)
          .eq('is_dismissed', false)
          .order('created_at', ascending: false)
          .limit(3),
    ]);

    final profile = results[0] as Map<String, dynamic>?;
    final wallets = (results[1] as List)
        .cast<Map<String, dynamic>>()
        .map(Wallet.fromRow)
        .toList();

    return FinanceData(
      profileName: (profile?['username'] as String?)?.trim(),
      activeWalletId: profile?['active_wallet_id'] as String?,
      wallets: wallets,
      expenses: results[2] as List<ExpenseRecord>,
      incomes: results[3] as List<IncomeRecord>?,
      advisories: (results[4] as List)
          .cast<Map<String, dynamic>>()
          .map(AiAdvisory.fromRow)
          .where((a) => a.text.isNotEmpty)
          .toList(),
    );
  }

  /// All of the user's expenses, newest first (paged past the 1000-row cap).
  Future<List<ExpenseRecord>> _loadExpenses(String userId) async {
    final all = <ExpenseRecord>[];
    for (var from = 0; ; from += _pageSize) {
      final page = await _client
          .from('expenses')
          .select('id, wallet_id, category_name, amount, description, spent_on')
          .eq('user_id', userId)
          .order('spent_on', ascending: false)
          .order('created_at', ascending: false)
          .range(from, from + _pageSize - 1);
      all.addAll(page.map(ExpenseRecord.fromRow));
      if (page.length < _pageSize) return all;
    }
  }

  Future<List<IncomeRecord>?> _loadIncomes(
    String userId, {
    required DateTime since,
  }) async {
    try {
      final rows = await _client
          .from('incomes')
          .select('id, wallet_id, source, amount, received_on')
          .eq('user_id', userId)
          .gte('received_on', _dateOnly(since))
          .order('received_on', ascending: false);
      return rows.map(IncomeRecord.fromRow).toList();
    } on PostgrestException catch (e) {
      if (isMissingIncomesTable(e)) return null;
      rethrow;
    }
  }

  /// Records an income and credits the wallet in one transaction.
  @override
  Future<void> addIncome({
    required String walletId,
    required double amount,
    required String source,
    required String description,
    required DateTime receivedOn,
  }) async {
    await _client.rpc(
      'add_income_atomic',
      params: {
        'p_wallet_id': walletId,
        'p_amount': amount,
        'p_source': source,
        'p_description': description,
        'p_received_on': _dateOnly(receivedOn),
      },
    );
  }

  /// Records an expense and debits the wallet balance.
  @override
  Future<void> addExpense({
    required String walletId,
    required double amount,
    required String categoryName,
    required String description,
    required DateTime spentOn,
  }) async {
    final userId = _userId;
    String? categoryId;
    try {
      final cat = await _client
          .from('categories')
          .select('id')
          .eq('user_id', userId)
          .eq('kind', 'expense')
          .ilike('name', categoryName.trim())
          .maybeSingle();
      if (cat != null) {
        categoryId = cat['id'] as String?;
      }
    } catch (_) {}

    await _client.from('expenses').insert({
      'user_id': userId,
      'wallet_id': walletId,
      'category_id': categoryId,
      'category_name': categoryName,
      'amount': amount,
      'description': description,
      'spent_on': _dateOnly(spentOn),
    });

    try {
      final wallet = await _client
          .from('wallets')
          .select('budget')
          .eq('id', walletId)
          .eq('user_id', userId)
          .maybeSingle();
      if (wallet != null) {
        final current = _toDouble(wallet['budget']);
        final newBudget = (current - amount).clamp(0.0, double.infinity);
        await _client
            .from('wallets')
            .update({'budget': newBudget})
            .eq('id', walletId)
            .eq('user_id', userId);
      }
    } catch (_) {
      // Wallet balance update fallback
    }
  }

  @override
  Future<void> createWallet({
    required String name,
    required double initialBalance,
  }) async {
    final userId = _userId;
    final res = await _client
        .from('wallets')
        .insert({
          'user_id': userId,
          'name': name,
          'budget': initialBalance,
        })
        .select('id')
        .maybeSingle();

    try {
      final profile = await _client
          .from('profiles')
          .select('active_wallet_id')
          .eq('id', userId)
          .maybeSingle();
      if (profile != null && profile['active_wallet_id'] == null && res != null) {
        await setActiveWallet(res['id'] as String);
      }
    } catch (_) {}
  }

  @override
  Future<void> setActiveWallet(String walletId) async {
    final userId = _userId;
    await _client.from('profiles').update({
      'active_wallet_id': walletId,
    }).eq('id', userId);
  }

  /// Subscribes to Realtime changes on the user's finance tables.
  @override
  void Function() watch(void Function() onChange) {
    final userId = _userId;
    final channel = _client.channel('finance-$userId');
    for (final table in ['wallets', 'expenses', 'incomes', 'ai_advisories']) {
      channel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: table,
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'user_id',
          value: userId,
        ),
        callback: (_) => onChange(),
      );
    }
    channel.subscribe();
    return () => _client.removeChannel(channel);
  }

  /// True when the `incomes` table / `add_income_atomic` RPC is not deployed.
  static bool isMissingIncomesTable(PostgrestException e) =>
      e.code == 'PGRST205' || // table not in schema cache
      e.code == 'PGRST202' || // function not found
      e.code == '42P01'; // undefined table

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static double _toDouble(Object? value) {
    if (value is num) return value.toDouble();
    if (value is String) return double.tryParse(value) ?? 0;
    return 0;
  }
}
