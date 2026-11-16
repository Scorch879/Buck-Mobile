import 'dart:ui' as ui;

import 'package:buck/features/finance/data/finance_models.dart';
import 'package:buck/features/finance/data/finance_repository.dart';
import 'package:buck/features/finance/presentation/finance_controller.dart';
import 'package:buck/features/onboarding/data/onboarding_service.dart';
import 'package:buck/features/onboarding/presentation/buck_onboarding_overlay.dart';
import 'package:buck/features/shell/presentation/main_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'support/fake_finance_source.dart';

User _makeUser({
  required String id,
  required DateTime createdAt,
  String? email,
  Map<String, dynamic>? userMetadata,
}) {
  return User(
    id: id,
    email: email,
    appMetadata: const {},
    userMetadata: userMetadata ?? const {},
    aud: 'authenticated',
    createdAt: createdAt.toUtc().toIso8601String(),
  );
}

void main() {
  setUpAll(() => GoogleFonts.config.allowRuntimeFetching = false);

  group('OnboardingService', () {
    late OnboardingService service;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      service = OnboardingService.forTest(
        prefsProvider: SharedPreferences.getInstance,
      );
    });

    test('returns false when user is null', () async {
      expect(await service.shouldShowOnboardingForUser(null), isFalse);
    });

    test('returns true for newly created user within 15-minute window', () async {
      final now = DateTime.utc(2026, 11, 16, 12, 0, 0);
      final user = _makeUser(
        id: 'new-user-1',
        email: 'fresh@buck.app',
        createdAt: now.subtract(const Duration(minutes: 4)),
      );

      expect(
        await service.shouldShowOnboardingForUser(user, now: now),
        isTrue,
      );
    });

    test('returns false for existing older user without pending sign-up', () async {
      final now = DateTime.utc(2026, 11, 16, 12, 0, 0);
      final user = _makeUser(
        id: 'old-user-1',
        email: 'existing@buck.app',
        createdAt: now.subtract(const Duration(days: 3)),
      );

      expect(
        await service.shouldShowOnboardingForUser(user, now: now),
        isFalse,
      );
    });

    test('returns true when matching email has pending local sign-up flag', () async {
      final now = DateTime.utc(2026, 11, 16, 12, 0, 0);
      await service.markPendingNewSignUp('Fresh.User@buck.app');

      final matchingUser = _makeUser(
        id: 'confirmed-user-1',
        email: 'fresh.user@buck.app',
        createdAt: now.subtract(const Duration(hours: 2)),
      );
      final differentUser = _makeUser(
        id: 'other-user-2',
        email: 'someone@buck.app',
        createdAt: now.subtract(const Duration(hours: 2)),
      );

      expect(
        await service.shouldShowOnboardingForUser(differentUser, now: now),
        isFalse,
      );
      expect(
        await service.shouldShowOnboardingForUser(matchingUser, now: now),
        isTrue,
      );
    });

    test('returns false when user metadata already marks onboarding complete', () async {
      final now = DateTime.utc(2026, 11, 16, 12, 0, 0);
      final user = _makeUser(
        id: 'meta-done-user',
        email: 'done@buck.app',
        createdAt: now.subtract(const Duration(minutes: 1)),
        userMetadata: const {OnboardingService.metadataCompletedKey: true},
      );

      expect(
        await service.shouldShowOnboardingForUser(user, now: now),
        isFalse,
      );
    });

    test('completeOnboarding persists locally and clears pending flag', () async {
      final now = DateTime.utc(2026, 11, 16, 12, 0, 0);
      final user = _makeUser(
        id: 'new-user-2',
        email: 'fresh2@buck.app',
        createdAt: now.subtract(const Duration(minutes: 2)),
      );

      await service.markPendingNewSignUp('fresh2@buck.app');
      expect(
        await service.shouldShowOnboardingForUser(user, now: now),
        isTrue,
      );

      await service.completeOnboarding(user);

      expect(
        await service.shouldShowOnboardingForUser(user, now: now),
        isFalse,
      );
    });
  });

  group('BuckOnboardingOverlay & MainShell integration', () {
    final now = DateTime(2026, 11, 16, 12, 0);

    FakeFinanceSource createFakeSource() => FakeFinanceSource(
          FinanceData(
            profileName: 'New User',
            activeWalletId: 'w1',
            wallets: const [Wallet(id: 'w1', name: 'Cash', balance: 5000)],
            expenses: [
              expense('e1', 120, DateTime(2026, 11, 15), category: 'Dining'),
            ],
            incomes: const [],
            advisories: const [],
          ),
        );

    Future<void> pumpShellWithOnboarding(
      WidgetTester tester, {
      required bool showOnboarding,
      OnboardingService? service,
    }) async {
      tester.view.physicalSize = const Size(430, 932);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);

      final controller = FinanceController(createFakeSource(), clock: () => now);
      addTearDown(controller.dispose);

      await tester.pumpWidget(
        MaterialApp(
          home: MainShell(
            financeController: controller,
            onboardingService: service,
            showOnboardingOverride: showOnboarding,
          ),
        ),
      );
      await controller.refresh();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
    }

    Future<void> tapNextAndSettle(WidgetTester tester) async {
      await tester.tap(find.byKey(const Key('onboarding_next_button')));
      for (var i = 0; i < 8; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    testWidgets('does not show onboarding overlay for returning/existing users', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pumpShellWithOnboarding(tester, showOnboarding: false);

      expect(find.byType(BuckOnboardingOverlay), findsNothing);
    });

    testWidgets(
      'walks all 7 Figma onboarding steps across tabs and dismisses on Done',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        final service = OnboardingService.forTest(
          prefsProvider: SharedPreferences.getInstance,
        );
        await pumpShellWithOnboarding(
          tester,
          showOnboarding: true,
          service: service,
        );

        expect(find.byType(BuckOnboardingOverlay), findsOneWidget);
        expect(find.text('1 / 7'), findsOneWidget);
        expect(find.byKey(const Key('onboarding_skip_button')), findsOneWidget);
        for (var i = 0; i < 7; i++) {
          expect(find.byKey(Key('onboarding_dot_$i')), findsOneWidget);
        }

        // Step 1 -> Step 2 (Home: Add Expense)
        await tapNextAndSettle(tester);
        expect(find.text('2 / 7'), findsOneWidget);

        // Step 2 -> Step 3 (Home: Add Income)
        await tapNextAndSettle(tester);
        expect(find.text('3 / 7'), findsOneWidget);

        // Step 3 -> Step 4 (Wallet tab: + New Wallet)
        await tapNextAndSettle(tester);
        expect(find.text('4 / 7'), findsOneWidget);
        expect(find.text('+ New Wallet'), findsWidgets);

        // Step 4 -> Step 5 (Expenses tab)
        await tapNextAndSettle(tester);
        expect(find.text('5 / 7'), findsOneWidget);
        expect(find.text('Added Expenses'), findsOneWidget);

        // Step 5 -> Step 6 (Goals tab)
        await tapNextAndSettle(tester);
        expect(find.text('6 / 7'), findsOneWidget);
        expect(find.text('Financial Goals'), findsOneWidget);

        // Step 6 -> Step 7 (Stats tab)
        await tapNextAndSettle(tester);
        expect(find.text('7 / 7'), findsOneWidget);
        expect(find.text('Done'), findsOneWidget);
        expect(find.text('Category Breakdown'), findsOneWidget);

        // Complete tutorial
        await tester.tap(find.byKey(const Key('onboarding_next_button')));
        await tester.pump(const Duration(milliseconds: 250));
        expect(find.byType(BuckOnboardingOverlay), findsNothing);
      },
    );

    testWidgets('Skip button immediately dismisses onboarding overlay', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      await pumpShellWithOnboarding(tester, showOnboarding: true);

      expect(find.byType(BuckOnboardingOverlay), findsOneWidget);
      expect(find.text('1 / 7'), findsOneWidget);

      await tester.tap(find.byKey(const Key('onboarding_skip_button')));
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(BuckOnboardingOverlay), findsNothing);
    });

    test(
      'SpotlightScrimPainter leaves whole card cutouts un-dimmed with orange line highlight',
      () async {
        final painter = SpotlightScrimPainter(
          cardCutouts: [
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(20, 20, 260, 120),
              const Radius.circular(24),
            ),
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(20, 160, 260, 100),
              const Radius.circular(24),
            ),
          ],
          lineHighlights: [
            RRect.fromRectAndRadius(
              const Rect.fromLTWH(80, 50, 60, 60),
              const Radius.circular(16),
            ),
          ],
          ringProgress: 1.0,
        );

        final recorder = ui.PictureRecorder();
        final canvas = Canvas(recorder);
        painter.paint(canvas, const Size(300, 300));
        final picture = recorder.endRecording();
        final image = await picture.toImage(300, 300);
        final bytes = await image.toByteData(
          format: ui.ImageByteFormat.rawRgba,
        );
        expect(bytes, isNotNull);

        int alphaAt(int x, int y) {
          final offset = (y * 300 + x) * 4;
          return bytes!.getUint8(offset + 3);
        }

        // Outside both cards: dimmed ~65% black
        expect(alphaAt(5, 5), greaterThan(150));
        // Inside first whole-card cutout (away from button ring): 100% transparent!
        expect(alphaAt(40, 80), equals(0));
        // Inside second whole-card cutout: 100% transparent!
        expect(alphaAt(150, 210), equals(0));
        // Directly on the button line highlight top edge (y=50, x=110): opaque orange!
        expect(alphaAt(110, 50), equals(255));
      },
    );
  });
}
