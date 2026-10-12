import 'package:buck/core/widgets/buck_footer_nav.dart';
import 'package:buck/features/finance/data/finance_models.dart';
import 'package:buck/features/finance/data/finance_repository.dart';
import 'package:buck/features/finance/presentation/finance_controller.dart';
import 'package:buck/features/shell/presentation/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/fake_finance_source.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final now = DateTime(2026, 10, 15, 14);

  FakeFinanceSource source({List<IncomeRecord>? incomes}) => FakeFinanceSource(
    FinanceData(
      profileName: 'Jo',
      activeWalletId: 'w1',
      wallets: const [Wallet(id: 'w1', name: 'Cash', balance: 5000)],
      expenses: [
        expense('e1', 450, DateTime(2026, 10, 14), category: 'Shopping'),
        expense('e2', 80, DateTime(2026, 10, 13), category: 'Transportation'),
      ],
      incomes: incomes,
      advisories: const [
        AiAdvisory(
          id: 'a1',
          title: 'Weekly review',
          suggestion: 'Dining is up this week.',
          advice: '',
        ),
      ],
    ),
  );

  Future<FinanceController> pumpShell(
    WidgetTester tester,
    FakeFinanceSource fake,
  ) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final controller = FinanceController(fake, clock: () => now);
    addTearDown(controller.dispose);
    await tester.pumpWidget(
      MaterialApp(home: MainShell(financeController: controller)),
    );
    await tester.pumpAndSettle();
    return controller;
  }

  testWidgets('Home shows live profile name, balance and insight', (
    tester,
  ) async {
    await pumpShell(tester, source());
    expect(find.text('Welcome Jo'), findsOneWidget);
    expect(find.text('₱5,000'), findsOneWidget);
    expect(find.text('₱530'), findsOneWidget); // this week's spending
    await tester.tap(find.text('AI INSIGHT'));
    await tester.pumpAndSettle();
    expect(find.text('Dining is up this week.'), findsOneWidget);
  });

  testWidgets('Expenses tab lists this month and shows untracked income', (
    tester,
  ) async {
    await pumpShell(tester, source());
    await tester.tap(find.bySemanticsLabel('Expenses'));
    await tester.pumpAndSettle();

    final footer = tester.widget<BuckFooterNav>(find.byType(BuckFooterNav));
    expect(footer.activeTab, BuckTab.expenses);
    expect(find.text('Shopping'), findsOneWidget);
    expect(find.text('-₱530.00'), findsOneWidget); // total spending
    expect(find.text('Not tracked yet'), findsOneWidget);
    expect(find.text('October 2026'), findsOneWidget);
  });

  testWidgets('Undesigned tab shows coming-soon instead of switching', (
    tester,
  ) async {
    await pumpShell(tester, source());
    await tester.tap(find.bySemanticsLabel('Stats'));
    await tester.pump();

    final footer = tester.widget<BuckFooterNav>(find.byType(BuckFooterNav));
    expect(footer.activeTab, BuckTab.home);
    expect(find.text('Stats is coming soon.'), findsOneWidget);
  });

  testWidgets('Add Income saves to the active wallet and refreshes', (
    tester,
  ) async {
    final fake = source(incomes: const []);
    await pumpShell(tester, fake);

    await tester.tap(find.bySemanticsLabel('Add Income').first);
    await tester.pumpAndSettle();
    expect(find.text('NEW INCOME'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '1200');
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Salary').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Add Income'));
    await tester.pumpAndSettle();

    expect(fake.addedIncomes.single['amount'], 1200);
    expect(fake.addedIncomes.single['walletId'], 'w1');
    expect(find.text('₱6,200'), findsOneWidget); // balance refreshed
    expect(find.text('Income added to Cash.'), findsOneWidget);
  });

  testWidgets('Add Income validates the amount', (tester) async {
    final fake = source(incomes: const []);
    await pumpShell(tester, fake);

    await tester.tap(find.bySemanticsLabel('Add Income').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Add Income'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an amount greater than 0.'), findsOneWidget);
    expect(fake.addedIncomes, isEmpty);
  });

  testWidgets('Add Expense saves to the active wallet and debits balance', (
    tester,
  ) async {
    final fake = source(incomes: const []);
    await pumpShell(tester, fake);

    await tester.tap(find.bySemanticsLabel('Add Expense').first);
    await tester.pumpAndSettle();
    expect(find.text('NEW SPENDING'), findsOneWidget);
    expect(find.text('Add Spending'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '800');
    await tester.tap(find.byType(DropdownButton<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Food').hitTestable().first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Add Expense'));
    await tester.pumpAndSettle();

    expect(fake.addedExpenses.single['amount'], 800);
    expect(fake.addedExpenses.single['walletId'], 'w1');
    expect(fake.addedExpenses.single['categoryName'], 'Food');
    expect(find.text('₱4,200'), findsOneWidget); // 5000 - 800
    expect(find.text('Expense added to Cash.'), findsOneWidget);
  });

  testWidgets('Add Expense validates the amount and category', (tester) async {
    final fake = source(incomes: const []);
    await pumpShell(tester, fake);

    await tester.tap(find.bySemanticsLabel('Add Expense').first);
    await tester.pumpAndSettle();
    await tester.tap(find.widgetWithText(InkWell, 'Add Expense'));
    await tester.pumpAndSettle();

    expect(find.text('Enter an amount greater than 0.'), findsOneWidget);
    expect(fake.addedExpenses, isEmpty);
  });
}

