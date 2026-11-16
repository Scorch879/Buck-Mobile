import '../../../core/services/supabase_service.dart';
import '../../finance/data/finance_repository.dart';
import '../../finance/presentation/finance_controller.dart';
import '../../goals/data/goals_repository.dart';
import '../../goals/presentation/goals_controller.dart';

/// Builds live Supabase-backed controllers for [MainShell].
class BuckShellDependencies {
  const BuckShellDependencies._();

  static FinanceController createFinanceController() {
    if (!SupabaseService.isInitialized) {
      return FinanceController(_UnavailableFinanceSource());
    }
    return FinanceController(FinanceRepository(SupabaseService.client));
  }

  static GoalsController createGoalsController() {
    if (!SupabaseService.isInitialized) {
      return GoalsController();
    }
    return GoalsController(
      repository: GoalsRepository(SupabaseService.client),
    );
  }
}

class _UnavailableFinanceSource implements FinanceDataSource {
  @override
  Future<FinanceData> load({required DateTime now}) {
    return Future<FinanceData>.error(
      StateError('Supabase is not initialized. Check connection and retry.'),
    );
  }

  @override
  Future<void> addIncome({
    required String walletId,
    required double amount,
    required String source,
    required String description,
    required DateTime receivedOn,
  }) async {
    throw StateError('Supabase is not initialized.');
  }

  @override
  Future<void> addExpense({
    required String walletId,
    required double amount,
    required String categoryName,
    required String description,
    required DateTime spentOn,
  }) async {
    throw StateError('Supabase is not initialized.');
  }

  @override
  Future<void> createWallet({
    required String name,
    required double initialBalance,
  }) async {
    throw StateError('Supabase is not initialized.');
  }

  @override
  Future<void> setActiveWallet(String walletId) async {
    throw StateError('Supabase is not initialized.');
  }

  @override
  void Function() watch(void Function() onChange) => () {};
}
