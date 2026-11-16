import 'package:buck/features/finance/data/finance_models.dart';
import 'package:buck/features/finance/data/finance_repository.dart';

/// In-memory [FinanceDataSource] for widget tests.
class FakeFinanceSource implements FinanceDataSource {
  FinanceData data;
  final List<Map<String, Object>> addedIncomes = [];
  final List<Map<String, Object>> addedExpenses = [];
  final List<Map<String, Object>> transferredFunds = [];

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
  Future<void> createWallet({
    required String name,
    required double initialBalance,
  }) async {
    final newId = 'wallet-${data.wallets.length + 1}';
    final newWallet = Wallet(id: newId, name: name, balance: initialBalance);
    data = FinanceData(
      profileName: data.profileName,
      activeWalletId: data.activeWalletId ?? newId,
      wallets: [...data.wallets, newWallet],
      expenses: data.expenses,
      incomes: data.incomes,
      advisories: data.advisories,
    );
  }

  @override
  Future<void> setActiveWallet(String walletId) async {
    data = FinanceData(
      profileName: data.profileName,
      activeWalletId: walletId,
      wallets: data.wallets,
      expenses: data.expenses,
      incomes: data.incomes,
      advisories: data.advisories,
    );
  }

  @override
  Future<void> transferFunds({
    required String sourceWalletId,
    required String targetWalletId,
    required double amount,
  }) async {
    if (sourceWalletId == targetWalletId) {
      throw 'Source and target wallets must be different.';
    }
    if (amount <= 0) {
      throw 'Transfer amount must be greater than zero.';
    }
    final source = data.wallets.firstWhere((w) => w.id == sourceWalletId);
    if (source.balance < amount) {
      throw 'Insufficient funds in source wallet.';
    }
    transferredFunds.add({
      'sourceWalletId': sourceWalletId,
      'targetWalletId': targetWalletId,
      'amount': amount,
    });
    data = FinanceData(
      profileName: data.profileName,
      activeWalletId: data.activeWalletId,
      wallets: [
        for (final w in data.wallets)
          if (w.id == sourceWalletId)
            Wallet(id: w.id, name: w.name, balance: w.balance - amount)
          else if (w.id == targetWalletId)
            Wallet(id: w.id, name: w.name, balance: w.balance + amount)
          else
            w,
      ],
      expenses: data.expenses,
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
