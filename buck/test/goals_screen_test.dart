import 'package:buck/features/goals/data/goal_model.dart';
import 'package:buck/features/goals/data/goals_repository.dart';
import 'package:buck/features/goals/presentation/allocate_funds_dialog.dart';
import 'package:buck/features/goals/presentation/create_goal_dialog.dart';
import 'package:buck/features/goals/presentation/goals_controller.dart';
import 'package:buck/features/goals/presentation/screens/goals_screen.dart';
import 'package:buck/features/goals/presentation/widgets/goal_card.dart';
import 'package:buck/features/shell/presentation/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/dev_finance_source.dart';
import 'support/fake_finance_source.dart';
import 'package:buck/features/finance/data/finance_repository.dart';
import 'package:buck/features/finance/presentation/finance_controller.dart';
import 'package:buck/features/finance/data/finance_models.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  testWidgets('GoalsScreen renders header and dynamic goal cards', (tester) async {
    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = GoalsController(initialGoals: sampleSeedGoals);
    String? triggeredAction;

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalsScreen(
            controller: controller,
            onRefresh: () async {},
            onAction: (msg) => triggeredAction = msg,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Verify Title & Subtitle
    expect(find.text('Financial Goals'), findsOneWidget);
    expect(find.text('Track your savings targets'), findsOneWidget);
    expect(find.text('+ Create Goal'), findsOneWidget);

    // Verify 3 initial Goal Cards
    expect(find.byType(GoalCard), findsNWidgets(3));
    expect(find.text('Emergency Fund'), findsOneWidget);
    expect(find.text('Vacation Fund'), findsOneWidget);
    expect(find.text('New Laptop'), findsOneWidget);

    // Verify initial values are dynamic and non-static
    expect(find.text('₱45,200'), findsOneWidget);
    expect(find.text('45.2% saved'), findsOneWidget);

    // Tap Allocate Funds from Wallet → opens dialog
    await tester.tap(find.text('Allocate Funds from Wallet →').first);
    await tester.pumpAndSettle();
    expect(find.byType(AllocateFundsDialog), findsOneWidget);

    // Confirm allocation (+1000 default)
    await tester.tap(find.text('Confirm Allocation'));
    await tester.pumpAndSettle();

    // Dynamic value check: 45,200 + 1000 = 46,200!
    expect(find.text('₱46,200'), findsOneWidget);
    expect(find.text('46.2% saved'), findsOneWidget);
    expect(triggeredAction, contains('Allocated ₱1000 to Emergency Fund.'));

    // Tap + Create Goal -> opens CreateGoalDialog
    await tester.tap(find.text('+ Create Goal'));
    await tester.pumpAndSettle();
    expect(find.byType(CreateGoalDialog), findsOneWidget);

    // Enter goal name and target
    await tester.enterText(find.byType(TextField).first, 'Wedding Fund');
    await tester.enterText(find.byType(TextField).at(1), '150000');
    final submitButton = find.widgetWithText(ElevatedButton, '+ Create Goal').last;
    await tester.ensureVisible(submitButton);
    await tester.tap(submitButton);
    await tester.pumpAndSettle();

    // Verify newly created dynamic goal card is in the list
    expect(find.text('Wedding Fund'), findsOneWidget);
    expect(find.text('of ₱150,000'), findsOneWidget);
    expect(find.byType(GoalCard), findsNWidgets(4));

    // Verify AI Tip button is stacked vertically above the "On Track" pill on the right
    final firstTitleRect = tester.getRect(find.text('Emergency Fund'));
    final firstAiRect = tester.getRect(find.bySemanticsLabel('AI Goal Tip').first);
    final firstStatusRect = tester.getRect(find.text('On Track').first);
    expect(firstAiRect.left, greaterThan(firstTitleRect.right));
    expect(firstAiRect.bottom, lessThanOrEqualTo(firstStatusRect.top));
    expect(firstStatusRect.left, greaterThan(firstTitleRect.left));
  });

  testWidgets('MainShell navigates to dynamic GoalsScreen via footer icon', (tester) async {
    final fake = FakeFinanceSource(
      const FinanceData(
        profileName: 'Admin',
        activeWalletId: 'w1',
        wallets: [Wallet(id: 'w1', name: 'Cash', balance: 5000)],
        expenses: [],
        incomes: [],
        advisories: [],
      ),
    );

    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final controller = FinanceController(fake);
    final goals = GoalsController(initialGoals: sampleSeedGoals);
    addTearDown(() {
      controller.dispose();
      goals.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MainShell(financeController: controller, goalsController: goals),
      ),
    );
    await tester.pumpAndSettle();

    // Tap the Goals tab (rightmost icon, labelled 'Goals')
    await tester.tap(find.bySemanticsLabel('Goals'));
    await tester.pumpAndSettle();

    // Verify we are on GoalsScreen
    expect(find.text('Financial Goals'), findsOneWidget);
    expect(find.text('Emergency Fund'), findsOneWidget);
  });

  testWidgets('New account with empty GoalsDataSource shows zero demo goals or funds', (tester) async {
    final emptyRepo = _EmptyGoalsRepository();
    final controller = GoalsController(repository: emptyRepo);
    addTearDown(controller.dispose);

    // Must not start with pre-populated demo goals/funds when backed by a real repository
    expect(controller.hasRepository, isTrue);
    expect(controller.goals, isEmpty);

    await controller.refresh();
    expect(controller.goals, isEmpty);

    tester.view.physicalSize = const Size(440, 956);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: GoalsScreen(
            controller: controller,
            onRefresh: () async {},
            onAction: (_) {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(GoalCard), findsNothing);
    expect(find.text('Emergency Fund'), findsNothing);
    expect(find.text('₱45,200'), findsNothing);
    expect(
      find.text('No goals yet. Tap "+ Create Goal" to begin tracking savings!'),
      findsOneWidget,
    );
  });

  test('GoalsController does not notify after dispose and rethrows deleteGoal failures', () async {
    final repo = _FailingDeleteGoalsRepo();
    final controller = GoalsController(repository: repo);

    await controller.refresh();
    expect(controller.goals, hasLength(1));

    await expectLater(
      () => controller.deleteGoal('g1'),
      throwsA(isA<StateError>()),
    );
    expect(controller.goals, hasLength(1));

    // Start in-flight refresh then dispose immediately; must not throw on completion.
    repo.delayLoad = const Duration(milliseconds: 20);
    final refreshFuture = controller.refresh();
    controller.dispose();
    await refreshFuture;
  });
}

class _FailingDeleteGoalsRepo implements GoalsDataSource {
  Duration delayLoad = Duration.zero;

  @override
  Future<List<GoalItem>> loadGoals() async {
    if (delayLoad > Duration.zero) await Future<void>.delayed(delayLoad);
    return const [
      GoalItem(
        id: 'g1',
        title: 'Save Up',
        targetDate: 'Target: Dec 2026',
        status: GoalStatus.inProgress,
        currentAmount: 1000,
        targetAmount: 5000,
        icon: Icons.savings_outlined,
        themeColor: Color(0xFFFF8E5D),
        gradientColors: [Color(0xFFFF8E5D), Color(0xFFFF6A13)],
      ),
    ];
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
  }) =>
      throw UnimplementedError();

  @override
  Future<bool> allocateFunds({
    required String goalId,
    required double amount,
    String? walletId,
  }) async =>
      false;

  @override
  Future<void> deleteGoal(String goalId) async {
    throw StateError('DB delete failed');
  }

  @override
  void Function() watch(void Function() onChange) => () {};
}

class _EmptyGoalsRepository implements GoalsDataSource {
  @override
  Future<List<GoalItem>> loadGoals() async => const [];

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
  }) =>
      throw UnimplementedError();

  @override
  Future<bool> allocateFunds({
    required String goalId,
    required double amount,
    String? walletId,
  }) async =>
      false;

  @override
  Future<void> deleteGoal(String goalId) async {}

  @override
  void Function() watch(void Function() onChange) => () {};
}
