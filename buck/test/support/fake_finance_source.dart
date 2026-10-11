import 'package:buck/features/finance/data/finance_models.dart';
import 'package:buck/features/finance/data/finance_repository.dart';

/// In-memory [FinanceDataSource] for widget tests.
class FakeFinanceSource implements FinanceDataSource {
  FinanceData data;
  final List<Map<String, Object>> addedIncomes = [];
  final List<Map<String, Object>> addedExpenses = [];

  FakeFinanceSource(this.data);

  @override
  Future<FinanceData> load({required DateTime now}) async => data;

  @override
  Future<void> addIncome({
    required String walletId,
    required double amount,
    required String source,
    required String description,
    required DateTime receivedOn,
  }) async {
    addedIncomes.add({
      'walletId': walletId,
      'amount': amount,
      'source': source,
    });
    data = FinanceData(
      profileName: data.profileName,
      activeWalletId: data.activeWalletId,
      wallets: [
        for (final w in data.wallets)
          w.id == walletId
              ? Wallet(id: w.id, name: w.name, balance: w.balance + amount)
              : w,
      ],
      expenses: data.expenses,
      incomes: [
        ...?data.incomes,
        IncomeRecord(
          id: 'income-${addedIncomes.length}',
          walletId: walletId,
          source: source,
          amount: amount,
          receivedOn: receivedOn,
        ),
      ],
      advisories: data.advisories,
    );
  }

  @override
  Future<void> addExpense({
    required String walletId,
    required double amount,
    required String categoryName,
    required String description,
    required DateTime spentOn,
  }) async {
    addedExpenses.add({
      'walletId': walletId,
      'amount': amount,
      'categoryName': categoryName,
    });
    data = FinanceData(
      profileName: data.profileName,
      activeWalletId: data.activeWalletId,
      wallets: [
        for (final w in data.wallets)
          w.id == walletId
              ? Wallet(
                  id: w.id,
                  name: w.name,
                  balance: (w.balance - amount).clamp(0.0, double.infinity),
                )
              : w,
      ],
      expenses: [
        ExpenseRecord(
          id: 'expense-${addedExpenses.length}',
          walletId: walletId,
          categoryName: categoryName,
          amount: amount,
          description: description,
          spentOn: spentOn,
        ),
        ...data.expenses,
      ],
      incomes: data.incomes,
      advisories: data.advisories,
    );
  }

  @override
  void Function() watch(void Function() onChange) => () {};
}

ExpenseRecord expense(
  String id,
  double amount,
  DateTime spentOn, {
  String category = 'Food',
  String? walletId = 'w1',
}) => ExpenseRecord(
  id: id,
  walletId: walletId,
  categoryName: category,
  amount: amount,
  description: '',
  spentOn: spentOn,
);
