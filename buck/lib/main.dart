import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_layout.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/settings/data/settings_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Warm Inter/Manrope weights and persisted settings concurrently with
  // Supabase initialization so initial screen transitions do not stall on fonts.
  unawaited(SettingsService.instance.ensureLoaded());
  unawaited(
    GoogleFonts.pendingFonts([
      GoogleFonts.inter(fontWeight: FontWeight.w400),
      GoogleFonts.inter(fontWeight: FontWeight.w600),
      GoogleFonts.inter(fontWeight: FontWeight.w700),
      GoogleFonts.inter(fontWeight: FontWeight.w800),
      GoogleFonts.manrope(fontWeight: FontWeight.w500),
      GoogleFonts.manrope(fontWeight: FontWeight.w600),
      GoogleFonts.manrope(fontWeight: FontWeight.w700),
      GoogleFonts.manrope(fontWeight: FontWeight.w800),
    ]).catchError((_) => const <void>[]),
  );

  // Enable edge-to-edge rendering so notched phones and gesture navigation bars
  // do not show solid black letterbox bars at the top or bottom.
  await Future.wait([
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge),
    SupabaseService.initialize().catchError((Object e) {
      debugPrint('Supabase initialization error: $e');
    }),
  ]);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarContrastEnforced: false,
    ),
  );

  AppLayout.initWebSafeInsetsListener();

  runApp(const BuckApp());
}

class BuckApp extends StatelessWidget {
  const BuckApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Buck - Finance & Expenses Tracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        scaffoldBackgroundColor: AppColors.navBarBg,
        primaryColor: AppColors.primaryOrange,
        colorScheme: const ColorScheme.dark(
          primary: AppColors.primaryOrange,
          secondary: AppColors.amberAccent,
          surface: AppColors.cardSurface,
        ),
      ),
      builder: (context, child) {
        final content = child ?? const SizedBox.shrink();
        return ValueListenableBuilder<WebSafeInsets>(
          valueListenable: AppLayout.webSafeInsetsNotifier,
          builder: (context, webInsets, _) {
            if (webInsets.top == 0 &&
                webInsets.bottom == 0 &&
                webInsets.left == 0 &&
                webInsets.right == 0) {
              return content;
            }
            final mq = MediaQuery.of(context);
            final mergedViewPadding = EdgeInsets.only(
              left: math.max(mq.viewPadding.left, webInsets.left),
              top: math.max(mq.viewPadding.top, webInsets.top),
              right: math.max(mq.viewPadding.right, webInsets.right),
              bottom: math.max(mq.viewPadding.bottom, webInsets.bottom),
            );
            final mergedPadding = EdgeInsets.only(
              left: math.max(0.0, mergedViewPadding.left - mq.viewInsets.left),
              top: math.max(0.0, mergedViewPadding.top - mq.viewInsets.top),
              right: math.max(0.0, mergedViewPadding.right - mq.viewInsets.right),
              bottom: math.max(
                0.0,
                mergedViewPadding.bottom - mq.viewInsets.bottom,
              ),
            );
            return MediaQuery(
              data: mq.copyWith(
                viewPadding: mergedViewPadding,
                padding: mergedPadding,
              ),
              child: content,
            );
          },
        );
      },
      home: const AuthGate(),
    );
  }
}
