import 'package:buck/features/finance/data/finance_repository.dart';
import 'package:buck/features/finance/presentation/finance_controller.dart';
import 'package:buck/features/goals/presentation/goals_controller.dart';
import 'package:buck/features/shell/presentation/main_shell.dart';
import 'package:buck/features/shell/presentation/widgets/profile_side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';

import 'support/fake_finance_source.dart';

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  final now = DateTime(2026, 10, 15, 14);

  Future<void> pumpShell(
    WidgetTester tester, {
    Size viewportSize = const Size(440, 956),
  }) async {
    tester.view.physicalSize = viewportSize;
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    final finance = FinanceController(
      FakeFinanceSource(
        const FinanceData(
          profileName: 'Jo',
          activeWalletId: 'w1',
          wallets: [],
          expenses: [],
          incomes: [],
          advisories: [],
        ),
      ),
      clock: () => now,
    );
    final goals = GoalsController();
    addTearDown(() {
      finance.dispose();
      goals.dispose();
    });

    await tester.pumpWidget(
      MaterialApp(
        home: MainShell(financeController: finance, goalsController: goals),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('tapping header Menu opens left-aligned ProfileSidePanel', (
    tester,
  ) async {
    await pumpShell(tester);

    expect(find.byKey(const Key('profile_side_panel')), findsNothing);

    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();

    final panelFinder = find.byKey(const Key('profile_side_panel'));
    expect(panelFinder, findsOneWidget);

    final rect = tester.getRect(panelFinder);
    expect(rect.left, 0.0);
    expect(rect.width, 378.0);
    expect(rect.height, 956.0);

    // Core Figma 2510:648 sections
    expect(find.text('Jo'), findsOneWidget);
    expect(find.text('Your shortcuts'), findsOneWidget);
    expect(find.text('Profile & Account'), findsOneWidget);
    expect(find.text('Security'), findsNWidgets(2));
    expect(find.text('Appearance'), findsNWidgets(2));
    expect(find.text('Feedback'), findsNWidgets(2));
    expect(find.text('See more'), findsOneWidget);
    expect(find.text('Settings Menu'), findsOneWidget);
    expect(find.text('Danger Zone'), findsOneWidget);
  });

  testWidgets('ProfileSidePanel scales cleanly on compact phones (375x812)', (
    tester,
  ) async {
    await pumpShell(tester, viewportSize: const Size(375, 812));

    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.byKey(const Key('profile_side_panel')));
    expect(rect.left, 0.0);
    expect(rect.width, closeTo(330.0, 0.5));
    expect(tester.takeException(), isNull);
  });

  testWidgets('interactive sections expand and Sign Out confirms callback', (
    tester,
  ) async {
    var signedOut = false;

    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) => Scaffold(
            body: Center(
              child: ElevatedButton(
                onPressed: () {
                  showProfileSidePanel(
                    context: context,
                    displayName: 'Google',
                    email: 'user@gmail.com',
                    connectionLabel: 'Connected with Google',
                    onSignOut: () async {
                      signedOut = true;
                    },
                  );
                },
                child: const Text('Open Panel'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Panel'));
    await tester.pumpAndSettle();

    expect(find.text('Google'), findsOneWidget);
    expect(find.text('user@gmail.com'), findsOneWidget);
    expect(find.text('Connected with Google'), findsOneWidget);

    // Expand See more
    await tester.tap(find.text('See more'));
    await tester.pumpAndSettle();
    expect(find.text('See less'), findsOneWidget);
    expect(find.text('Open Full Settings'), findsOneWidget);

    // Expand Danger Zone and sign out via confirmation dialog
    await tester.ensureVisible(find.byKey(const Key('panel_danger_zone_row')));
    await tester.tap(find.byKey(const Key('panel_danger_zone_row')));
    await tester.pumpAndSettle();

    await tester.ensureVisible(find.text('Sign out'));
    await tester.tap(find.text('Sign out'));
    await tester.pumpAndSettle();

    expect(find.text('Sign out of Buck?'), findsOneWidget);

    await tester.tap(find.text('Sign out').last);
    await tester.pumpAndSettle();

    expect(signedOut, isTrue);
    expect(find.byKey(const Key('profile_side_panel')), findsNothing);
  });
}
