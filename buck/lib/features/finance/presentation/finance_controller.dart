import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/finance_repository.dart';
import '../domain/finance_snapshot.dart';

/// Loads the signed-in user's finance data and keeps it live via
/// Supabase Realtime. Screens listen to this and rebuild on change.
class FinanceController extends ChangeNotifier {
  final FinanceDataSource _repository;
  final DateTime Function() _clock;

  FinanceController(this._repository, {DateTime Function()? clock})
    : _clock = clock ?? DateTime.now;

  FinanceSnapshot? _snapshot;
  FinanceSnapshot? get snapshot => _snapshot;

  bool _loading = false;
  bool get isLoading => _loading;

  String? _error;
  String? get error => _error;

  void Function()? _stopWatching;
  Timer? _debounce;
  bool _disposed = false;

  /// First load + start listening for changes.
  Future<void> start() async {
    await refresh();
    if (_disposed) return;
    try {
      _stopWatching = _repository.watch(_scheduleRefresh);
    } catch (e) {
      debugPrint('Finance realtime unavailable: $e');
    }
  }

  Future<void> refresh() async {
    _loading = true;
    _notify();
    try {
      final data = await _repository.load(now: _clock());
      _snapshot = FinanceSnapshot.fromData(data, now: _clock());
      _error = null;
    } catch (e) {
      _error = _describe(e);
    } finally {
      _loading = false;
      _notify();
    }
  }

  /// Records an income on [walletId] and reloads.
  /// Throws a readable [String] message on failure.
  Future<void> addIncome({
    required String walletId,
    required double amount,
    required String source,
    required String description,
    required DateTime receivedOn,
  }) async {
    try {
      await _repository.addIncome(
        walletId: walletId,
        amount: amount,
        source: source,
        description: description,
        receivedOn: receivedOn,
      );
    } on PostgrestException catch (e) {
      if (FinanceRepository.isMissingIncomesTable(e)) {
        throw 'Income tracking is not enabled on the server yet.';
      }
      throw e.message;
    }
    await refresh();
  }

  /// Records an expense on [walletId] and reloads.
  /// Throws a readable [String] message on failure.
  Future<void> addExpense({
    required String walletId,
    required double amount,
    required String categoryName,
    required String description,
    required DateTime spentOn,
  }) async {
    try {
      await _repository.addExpense(
        walletId: walletId,
        amount: amount,
        categoryName: categoryName,
        description: description,
        spentOn: spentOn,
      );
    } on PostgrestException catch (e) {
      throw e.message;
    } catch (e) {
      throw e is String ? e : 'Could not save expense. Please try again.';
    }
    await refresh();
  }

  // Coalesce bursts of realtime events (e.g. expense + wallet update).
  void _scheduleRefresh() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 400), refresh);
  }

  static String _describe(Object e) {
    if (e is PostgrestException) return e.message;
    if (e is AuthException) return e.message;
    return 'Could not load your data. Check your connection and try again.';
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _debounce?.cancel();
    _stopWatching?.call();
    super.dispose();
  }
}
