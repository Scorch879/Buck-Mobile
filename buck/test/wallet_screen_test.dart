import 'package:buck/features/finance/data/finance_models.dart';
import 'package:buck/features/finance/data/finance_repository.dart';
import 'package:buck/features/finance/domain/finance_snapshot.dart';
import 'package:buck/features/finance/presentation/finance_controller.dart';
import 'package:buck/features/wallet/presentation/screens/wallet_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/fake_finance_source.dart';

void main() {
  final now = DateTime(2026, 10, 23);

  late FakeFinanceSource fakeSource;
  late FinanceController controller;

  setUp(() {
    fakeSource = FakeFinanceSource(
      FinanceData(
        profileName: 'Admin',
        activeWalletId: 'w1',
        wallets: const [
          Wallet(id: 'w1', name: 'Main Wallet', balance: 25000),
          Wallet(id: 'w2', name: 'Savings', balance: 50000),
        ],
        expenses: [
          ExpenseRecord(
            id: 'e1',
            walletId: 'w1',
            categoryName: 'Food',
            amount: 500,
            description: 'Lunch',
            spentOn: now,
          ),
        ],
        incomes: [
          IncomeRecord(
            id: 'i1',
            walletId: 'w1',
            source: 'Salary',
            amount: 45000,
            receivedOn: now,
          ),
        ],
        advisories: const [],
      ),
    );
    controller = FinanceController(fakeSource);
  });

  tearDown(() {
    controller.dispose();
  });

  Widget buildTestScreen(FinanceSnapshot snapshot) {
    return MaterialApp(
      home: Scaffold(
        body: WalletScreen(
          snapshot: snapshot,
          controller: controller,
          onRefresh: () async {},
          onAddIncome: () {},
        ),
      ),
    );
  }

  testWidgets('renders WalletScreen with non-static dynamic values from snapshot', (tester) async {
    await controller.start();
    final snapshot = controller.snapshot!;

    await tester.pumpWidget(buildTestScreen(snapshot));
    await tester.pumpAndSettle();

    // Page Title
    expect(find.text('Wallets & balances'), findsOneWidget);

    // Active Wallet details
    expect(find.text('Main Wallet'), findsWidgets);
    expect(find.text('₱25,000.00'), findsWidgets);

    // Tabs
    expect(find.text('Wallets'), findsWidgets);
    expect(find.text('Income'), findsWidgets);

    // Manage your wallets card
    expect(find.text('Manage your wallets'), findsOneWidget);
    expect(find.text('2 wallets'), findsOneWidget);
    expect(find.text('Savings'), findsOneWidget);
    expect(find.text('₱50,000.00'), findsOneWidget);

    // Wallet history card
    expect(find.text('Wallet history'), findsOneWidget);
    expect(find.text('Lunch'), findsOneWidget);
  });

  testWidgets('switches to Income tab and displays income records', (tester) async {
    await controller.start();
    final snapshot = controller.snapshot!;

    await tester.pumpWidget(buildTestScreen(snapshot));
    await tester.pumpAndSettle();

    // Tap "Income" tab
    await tester.tap(find.text('Income'));
    await tester.pumpAndSettle();

    // Manage your income card
    expect(find.text('Manage your income'), findsOneWidget);
    expect(find.text('1 incomes'), findsOneWidget);
    expect(find.text('Salary'), findsWidgets);
    expect(find.text('+₱45,000.00'), findsWidgets);
    expect(find.text('+ Add Income'), findsOneWidget);
  });

  testWidgets('opens net worth modal when View Net Worth is tapped', (tester) async {
    await controller.start();
    final snapshot = controller.snapshot!;

    await tester.pumpWidget(buildTestScreen(snapshot));
    await tester.pumpAndSettle();

    // Tap "View Net Worth →"
    await tester.tap(find.text('View Net Worth →'));
    await tester.pumpAndSettle();

    // Total Net Worth is 25,000 + 50,000 = 75,000
    expect(find.text('TOTAL NET WORTH'), findsOneWidget);
    expect(find.text('₱75,000.00'), findsOneWidget);
    expect(find.text('Across 2 active wallets'), findsOneWidget);
  });

  testWidgets('creates a new wallet via dialog', (tester) async {
    await controller.start();
    final snapshot = controller.snapshot!;

    await tester.pumpWidget(buildTestScreen(snapshot));
    await tester.pumpAndSettle();

    // Drag to bring "+ New Wallet" well within viewport
    await tester.drag(find.byType(ListView).first, const Offset(0, -250));
    await tester.pumpAndSettle();

    // Tap "+ New Wallet"
    await tester.tap(find.text('+ New Wallet'));
    await tester.pumpAndSettle();

    expect(find.text('Create New Wallet'), findsOneWidget);

    // Fill in wallet details
    await tester.enterText(find.byType(TextFormField).first, 'Emergency Fund');
    await tester.enterText(find.byType(TextFormField).last, '15000');

    // Submit
    await tester.tap(find.widgetWithText(ElevatedButton, 'Create Wallet'));
    await tester.pumpAndSettle();

    // Fake source should have 3 wallets now
    expect(fakeSource.data.wallets.length, 3);
    expect(fakeSource.data.wallets.any((w) => w.name == 'Emergency Fund'), isTrue);
  });
}
