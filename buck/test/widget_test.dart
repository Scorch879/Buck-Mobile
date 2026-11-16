import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:buck/core/theme/app_colors.dart';
import 'package:buck/features/settings/data/settings_service.dart';
import 'package:buck/main.dart';

void main() {
  setUpAll(() {
    GoogleFonts.config.allowRuntimeFetching = false;
  });

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Buck app launches with splash, clean Sign In screen, and working Light/Dark theme', (WidgetTester tester) async {
    await SettingsService.instance.setTheme('Dark');
    await tester.pumpWidget(const BuckApp());

    // Splash branding renders on initial launch frame over AuthGate
    expect(find.byType(BuckSplashView), findsOneWidget);
    expect(find.text('Budget Tracker'), findsOneWidget);

    // Sign In screen removes website intro, header badge, and Dev Quick Login
    expect(find.text('Sign in to Buck'), findsOneWidget);
    expect(find.text('PERSONAL BUDGETING, MINUS THE MESS'), findsNothing);
    expect(find.text('Quick Login'), findsNothing);

    // Splash completes and unmounts cleanly
    await tester.pump(const Duration(milliseconds: 1400));
    await tester.pumpAndSettle();
    expect(find.byType(BuckSplashView), findsNothing);

    // Switching theme updates BuckPalette across the live MaterialApp
    final scaffoldCtx = tester.element(find.byType(Scaffold).last);
    expect(BuckPalette.of(scaffoldCtx).isLight, isFalse);

    await SettingsService.instance.setTheme('Light');
    await tester.pumpAndSettle();
    expect(BuckPalette.of(tester.element(find.byType(Scaffold).last)).isLight, isTrue);

    await SettingsService.instance.setTheme('Dark');
    await tester.pumpAndSettle();
  });
}
