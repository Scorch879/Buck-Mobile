import 'finance_models.dart';
import 'finance_repository.dart';

/// Pre-populated dev finance source matching the Figma design data.
class DevFinanceSource implements FinanceDataSource {
  FinanceData _data = FinanceData(
    profileName: 'Admin',
    activeWalletId: 'wallet-main',
    wallets: const [
      Wallet(id: 'wallet-main', name: 'Main Wallet', balance: 24500.00),
      Wallet(id: 'wallet-savings', name: 'Savings', balance: 50000.00),
      Wallet(id: 'wallet-emergency', name: 'Emergency Fund', balance: 15000.00),
    ],
    expenses: [
      ExpenseRecord(
        id: 'exp-1',
        walletId: 'wallet-main',
        categoryName: 'Food',
        amount: 320.00,
        description: 'Lunch at Bistro',
        spentOn: DateTime.now().subtract(const Duration(hours: 2)),
      ),
      ExpenseRecord(
        id: 'exp-2',
        walletId: 'wallet-main',
        categoryName: 'Transportation',
        amount: 150.00,
        description: 'Grab ride to office',
        spentOn: DateTime.now().subtract(const Duration(days: 1)),
      ),
      ExpenseRecord(
        id: 'exp-3',
        walletId: 'wallet-main',
        categoryName: 'Shopping',
        amount: 1250.00,
        description: 'Groceries at Supermarket',
        spentOn: DateTime.now().subtract(const Duration(days: 2)),
      ),
      ExpenseRecord(
        id: 'exp-4',
        walletId: 'wallet-main',
        categoryName: 'Bills & Utilities',
        amount: 2499.00,
        description: 'Fiber Internet bill',
        spentOn: DateTime.now().subtract(const Duration(days: 4)),
      ),
      ExpenseRecord(
        id: 'exp-5',
        walletId: 'wallet-main',
        categoryName: 'Food',
        amount: 1450.00,
        description: 'Weekend dinner with team',
        spentOn: DateTime.now().subtract(const Duration(days: 6)),
      ),
      ExpenseRecord(
        id: 'exp-6',
        walletId: 'wallet-main',
        categoryName: 'Shopping',
        amount: 3890.00,
        description: 'New shoes and work clothes',
        spentOn: DateTime.now().subtract(const Duration(days: 10)),
      ),
      ExpenseRecord(
        id: 'exp-7',
        walletId: 'wallet-main',
        categoryName: 'Bills & Utilities',
        amount: 4850.00,
        description: 'Meralco electricity bill',
        spentOn: DateTime.now().subtract(const Duration(days: 14)),
      ),
      ExpenseRecord(
        id: 'exp-8',
        walletId: 'wallet-main',
        categoryName: 'Transportation',
        amount: 2200.00,
        description: 'Shell gasoline full tank',
        spentOn: DateTime.now().subtract(const Duration(days: 18)),
      ),
      ExpenseRecord(
        id: 'exp-9',
        walletId: 'wallet-main',
        categoryName: 'Others',
        amount: 1500.00,
        description: 'Fitness gym monthly pass',
        spentOn: DateTime.now().subtract(const Duration(days: 22)),
      ),
      ExpenseRecord(
        id: 'exp-10',
        walletId: 'wallet-main',
        categoryName: 'Shopping',
        amount: 18500.00,
        description: 'External monitor for workstation',
        spentOn: DateTime.now().subtract(const Duration(days: 40)),
      ),
      ExpenseRecord(
        id: 'exp-11',
        walletId: 'wallet-main',
        categoryName: 'Bills & Utilities',
        amount: 12500.00,
        description: 'Quarterly insurance premium',
        spentOn: DateTime.now().subtract(const Duration(days: 55)),
      ),
      ExpenseRecord(
        id: 'exp-12',
        walletId: 'wallet-main',
        categoryName: 'Others',
        amount: 8900.00,
        description: 'Annual dental checkup & clinic',
        spentOn: DateTime.now().subtract(const Duration(days: 70)),
      ),
    ],
    incomes: [
      IncomeRecord(
        id: 'inc-1',
        walletId: 'wallet-main',
        source: 'Salary',
        amount: 45000.00,
        receivedOn: DateTime(DateTime.now().year, DateTime.now().month, 15),
      ),
      IncomeRecord(
        id: 'inc-2',
        walletId: 'wallet-savings',
        source: 'Freelance',
        amount: 12000.00,
        receivedOn: DateTime(DateTime.now().year, DateTime.now().month, 5),
      ),
    ],
    advisories: const [
      AiAdvisory(
        id: 'adv-1',
        title: 'Spending Pattern Analysis',
        suggestion: 'You spent 12% less on dining this week. Keep it up!',
        advice: 'Allocating the surplus ₱1,200 to your Emergency Fund will help reach your goal 2 weeks faster.',
      ),
    ],
  );

  final List<void Function()> _listeners = [];

  @override
  Future<FinanceData> load({required DateTime now}) async => _data;

  @override
  Future<void> addIncome({
    required String walletId,
    required double amount,
    required String source,
    required String description,
    required DateTime receivedOn,
  }) async {
    _data = FinanceData(
      profileName: _data.profileName,
      activeWalletId: _data.activeWalletId,
      wallets: [
        for (final w in _data.wallets)
          w.id == walletId
              ? Wallet(id: w.id, name: w.name, balance: w.balance + amount)
              : w,
      ],
      expenses: _data.expenses,
      incomes: [
        IncomeRecord(
          id: 'inc-${DateTime.now().millisecondsSinceEpoch}',
          walletId: walletId,
          source: source,
          amount: amount,
          receivedOn: receivedOn,
        ),
        ...?_data.incomes,
      ],
      advisories: _data.advisories,
    );
    for (final cb in _listeners) {
      cb();
    }
  }

  @override
  Future<void> addExpense({
    required String walletId,
    required double amount,
    required String categoryName,
    required String description,
    required DateTime spentOn,
  }) async {
    _data = FinanceData(
      profileName: _data.profileName,
      activeWalletId: _data.activeWalletId,
      wallets: [
        for (final w in _data.wallets)
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
          id: 'exp-${DateTime.now().millisecondsSinceEpoch}',
          walletId: walletId,
          categoryName: categoryName,
          amount: amount,
          description: description,
          spentOn: spentOn,
        ),
        ..._data.expenses,
      ],
      incomes: _data.incomes,
      advisories: _data.advisories,
    );
    for (final cb in _listeners) {
      cb();
    }
  }

  @override
  Future<void> createWallet({
    required String name,
    required double initialBalance,
  }) async {
    final newId = 'wallet-${DateTime.now().millisecondsSinceEpoch}';
    final newWallet = Wallet(id: newId, name: name, balance: initialBalance);
    _data = FinanceData(
      profileName: _data.profileName,
      activeWalletId: _data.activeWalletId ?? newId,
      wallets: [..._data.wallets, newWallet],
      expenses: _data.expenses,
      incomes: _data.incomes,
      advisories: _data.advisories,
    );
    for (final cb in _listeners) {
      cb();
    }
  }

  @override
  Future<void> setActiveWallet(String walletId) async {
    _data = FinanceData(
      profileName: _data.profileName,
      activeWalletId: walletId,
      wallets: _data.wallets,
      expenses: _data.expenses,
      incomes: _data.incomes,
      advisories: _data.advisories,
    );
    for (final cb in _listeners) {
      cb();
    }
  }

  @override
  void Function() watch(void Function() onChange) {
    _listeners.add(onChange);
    return () => _listeners.remove(onChange);
  }
}
