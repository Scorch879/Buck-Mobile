import 'package:buck/core/theme/app_colors.dart';
import 'package:buck/features/settings/data/settings_service.dart';
import 'package:buck/features/settings/presentation/screens/appearance_screen.dart';
import 'package:buck/features/settings/presentation/screens/danger_zone_screen.dart';
import 'package:buck/features/settings/presentation/screens/feedback_screen.dart';
import 'package:buck/features/settings/presentation/screens/profile_account_screen.dart';
import 'package:buck/features/settings/presentation/screens/security_screen.dart';
import 'package:buck/features/settings/presentation/screens/settings_menu_screen.dart';
import 'package:buck/features/shell/presentation/widgets/profile_side_panel.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

BuckSettingsContext _googleContext() => const BuckSettingsContext(
  displayName: 'Alex Mercer',
  email: 'alex@example.com',
  connectionLabel: 'Connected with Google',
  providerName: 'Google',
  isGoogleManaged: true,
);

Widget _wrap(Widget child) {
  return MaterialApp(
    theme: ThemeData.dark(useMaterial3: true).copyWith(
      scaffoldBackgroundColor: AppColors.background,
    ),
    home: child,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  GoogleFonts.config.allowRuntimeFetching = false;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await SettingsService.instance.setTheme('Dark');
  });

  testWidgets('ProfileSidePanel navigates to SettingsMenuScreen and sub-screens',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    final ctx = _googleContext();

    await tester.pumpWidget(
      _wrap(
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () {
                  showProfileSidePanel(
                    context: context,
                    displayName: ctx.displayName,
                    email: ctx.email,
                    connectionLabel: ctx.connectionLabel,
                    settingsContext: ctx,
                    onSignOut: () async {},
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

    expect(find.text('See more'), findsOneWidget);
    await tester.tap(find.text('See more'));
    await tester.pumpAndSettle();

    final openFullSettings = find.text('Open Full Settings');
    expect(openFullSettings, findsOneWidget);
    await tester.ensureVisible(openFullSettings);
    await tester.tap(openFullSettings);
    await tester.pumpAndSettle();

    expect(find.text('Settings'), findsOneWidget);
    expect(find.text('Profile & Account'), findsOneWidget);
    expect(find.text('Security'), findsOneWidget);
    expect(find.text('Appearance'), findsOneWidget);
    expect(find.text('Feedback'), findsOneWidget);
    expect(find.text('Danger Zone'), findsOneWidget);

    await tester.tap(find.text('Security'));
    await tester.pumpAndSettle();
    expect(find.text('Protected by Google'), findsOneWidget);
    expect(find.text('Email is managed by Google.'), findsOneWidget);
  });

  testWidgets('SettingsMenuScreen filters rows on search and has no duplicate sign out',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        SettingsMenuScreen(
          settingsContext: _googleContext(),
          onSignOut: () async {},
        ),
      ),
    );

    await tester.enterText(
      find.byKey(const Key('settings_search_input')),
      'theme',
    );
    await tester.pump();
    expect(find.text('No matching settings found.'), findsOneWidget);

    await tester.enterText(
      find.byKey(const Key('settings_search_input')),
      'Appearance',
    );
    await tester.pump();
    expect(find.text('Make it look like you'), findsOneWidget);
    expect(find.text('Security'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('settings_search_input')),
      '',
    );
    await tester.pump();

    expect(find.byKey(const Key('settings_sign_out_button')), findsNothing);
    expect(find.text('Sign out'), findsNothing);
  });

  testWidgets('ProfileAccountScreen validates empty display name',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(ProfileAccountScreen(settingsContext: _googleContext())),
    );
    await tester.pumpAndSettle();

    expect(find.text('Profile & Account'), findsOneWidget);
    expect(find.text('alex@example.com'), findsOneWidget);

    final nameInput = find.byType(TextField);
    await tester.enterText(nameInput, '   ');
    await tester.tap(find.text('Save changes'));
    await tester.pump();

    expect(find.text('Display name cannot be empty.'), findsOneWidget);
  });

  testWidgets('SecurityScreen adapts copy for Google vs email providers',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        const SecurityScreen(
          settingsContext: BuckSettingsContext(
            displayName: 'Alex',
            email: 'alex@buck.app',
            connectionLabel: 'Connected with Email',
            providerName: 'Buck Auth',
            isGoogleManaged: false,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Protected by Buck Auth'), findsOneWidget);
    expect(find.text('Signed in as alex@buck.app.'), findsOneWidget);
    expect(find.text('Managed via Buck authentication.'), findsOneWidget);
  });

  testWidgets('AppearanceScreen toggles between Light and Dark theme selection',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const AppearanceScreen()));
    await tester.pumpAndSettle();

    expect(find.text('Dark is currently selected.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('appearance_theme_light')));
    await tester.pumpAndSettle();
    expect(find.text('Light is currently selected.'), findsOneWidget);

    await tester.tap(find.byKey(const Key('appearance_theme_dark')));
    await tester.pumpAndSettle();
    expect(find.text('Dark is currently selected.'), findsOneWidget);
  });

  testWidgets('FeedbackScreen updates counters and validates empty submission',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(_wrap(const FeedbackScreen()));
    await tester.pumpAndSettle();

    expect(find.text('0 / 120'), findsOneWidget);
    expect(find.text('0 / 2,000'), findsOneWidget);

    await tester.tap(find.text('Bug report'));
    await tester.pump();

    await tester.enterText(
      find.byKey(const Key('feedback_title_input')),
      'Receipt scan crop',
    );
    await tester.enterText(
      find.byKey(const Key('feedback_details_input')),
      'Details',
    );
    await tester.pump();

    expect(find.text('17 / 120'), findsOneWidget);
    expect(find.text('7 / 2,000'), findsOneWidget);

    await tester.enterText(find.byKey(const Key('feedback_title_input')), '');
    await tester.enterText(find.byKey(const Key('feedback_details_input')), '');
    await tester.pump();

    final sendButton = find.text('Send feedback');
    await tester.ensureVisible(sendButton);
    await tester.tap(sendButton);
    await tester.pump();

    expect(
      find.text('Please enter a short summary or details.'),
      findsOneWidget,
    );
  });

  testWidgets('DangerZoneScreen gates Request deletion on typing DELETE and confirms dialog',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    var deletionConfirmed = false;

    await tester.pumpWidget(
      _wrap(
        DangerZoneScreen(
          onDeletionConfirmed: () async {
            deletionConfirmed = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    final requestButton = find.byKey(const Key('danger_zone_request_button'));
    await tester.ensureVisible(requestButton);
    await tester.tap(requestButton);
    await tester.pumpAndSettle();
    expect(find.text('Request account deletion?'), findsNothing);

    await tester.enterText(
      find.byKey(const Key('danger_zone_delete_input')),
      'DELETE',
    );
    await tester.pump();

    await tester.ensureVisible(requestButton);
    await tester.tap(requestButton);
    await tester.pumpAndSettle();

    expect(find.text('Request account deletion?'), findsOneWidget);
    expect(find.text('Keep account'), findsOneWidget);

    await tester.tap(find.text('Request deletion').last);
    await tester.pumpAndSettle();
    expect(deletionConfirmed, isTrue);
  });

  testWidgets('SettingsScaffold honors top, bottom, and horizontal bar safe insets',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(
          size: Size(402, 874),
          viewPadding: EdgeInsets.fromLTRB(20, 59, 20, 34),
          padding: EdgeInsets.fromLTRB(20, 59, 20, 34),
        ),
        child: _wrap(
          SettingsMenuScreen(
            settingsContext: _googleContext(),
            onSignOut: () async {},
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final scrollView = tester.widget<SingleChildScrollView>(
      find.byType(SingleChildScrollView),
    );
    expect(
      scrollView.padding,
      const EdgeInsets.fromLTRB(36, 75, 36, 62),
    );
  });

  testWidgets('Swiping right pops Settings sub-screen back to SettingsMenuScreen',
      (tester) async {
    tester.view.physicalSize = const Size(402, 874);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      _wrap(
        SettingsMenuScreen(
          settingsContext: _googleContext(),
          onSignOut: () async {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Appearance'));
    await tester.pumpAndSettle();
    expect(find.text('A look that feels like you.'), findsOneWidget);

    await tester.fling(find.byType(AppearanceScreen), const Offset(220, 0), 850);
    await tester.pumpAndSettle();

    expect(find.text('A look that feels like you.'), findsNothing);
    expect(find.text('Settings'), findsOneWidget);
  });
}
