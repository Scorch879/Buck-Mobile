import 'dart:async' show unawaited;
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'core/services/supabase_service.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_layout.dart';
import 'core/theme/app_text_styles.dart';
import 'core/widgets/buck_background.dart';
import 'features/auth/presentation/auth_gate.dart';
import 'features/auth/presentation/widgets/buck_logo_badge.dart';
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

  static SystemUiOverlayStyle _overlayStyle({required bool isLight}) {
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isLight ? Brightness.dark : Brightness.light,
      statusBarBrightness: isLight ? Brightness.light : Brightness.dark,
      systemStatusBarContrastEnforced: false,
      systemNavigationBarColor: Colors.transparent,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarIconBrightness:
          isLight ? Brightness.dark : Brightness.light,
      systemNavigationBarContrastEnforced: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String>(
      valueListenable: SettingsService.instance.selectedTheme,
      builder: (context, selectedTheme, _) {
        final isLight = selectedTheme == 'Light';
        AppLayout.setLightMode(isLight);
        SystemChrome.setSystemUIOverlayStyle(_overlayStyle(isLight: isLight));

        return MaterialApp(
          title: 'Buck Tracker',
          debugShowCheckedModeBanner: false,
          themeMode: isLight ? ThemeMode.light : ThemeMode.dark,
          theme: ThemeData(
            brightness: Brightness.light,
            scaffoldBackgroundColor: const Color(0xFFF6EDE4),
            primaryColor: AppColors.primaryOrange,
            colorScheme: const ColorScheme.light(
              primary: AppColors.primaryOrange,
              secondary: AppColors.amberAccent,
              surface: Color(0xFFFFFFFF),
            ),
          ),
          darkTheme: ThemeData(
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
                  left:
                      math.max(0.0, mergedViewPadding.left - mq.viewInsets.left),
                  top: math.max(0.0, mergedViewPadding.top - mq.viewInsets.top),
                  right: math.max(
                    0.0,
                    mergedViewPadding.right - mq.viewInsets.right,
                  ),
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
          home: const _BuckLaunchShell(),
        );
      },
    );
  }
}

/// Shows the Buck Budget Tracker splash screen on cold launch (like Grab or
/// Facebook) and smoothly reveals [AuthGate] beneath once the intro completes.
class _BuckLaunchShell extends StatefulWidget {
  const _BuckLaunchShell();

  @override
  State<_BuckLaunchShell> createState() => _BuckLaunchShellState();
}

class _BuckLaunchShellState extends State<_BuckLaunchShell>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1250),
  );
  bool _done = false;

  @override
  void initState() {
    super.initState();
    _controller.addStatusListener((status) {
      if (status == AnimationStatus.completed && mounted) {
        setState(() => _done = true);
      }
    });
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        const AuthGate(),
        if (!_done)
          Positioned.fill(
            child: IgnorePointer(
              child: AnimatedBuilder(
                animation: _controller,
                builder: (context, child) {
                  // Stay solid for 72% of duration, then fade out over last 28%.
                  final v = _controller.value;
                  final opacity = v < 0.72
                      ? 1.0
                      : (1.0 - (v - 0.72) / 0.28).clamp(0.0, 1.0);
                  return Opacity(opacity: opacity, child: child);
                },
                child: const BuckSplashView(),
              ),
            ),
          ),
      ],
    );
  }
}

class BuckSplashView extends StatelessWidget {
  const BuckSplashView({super.key});

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    return Scaffold(
      backgroundColor: palette.shellBg,
      body: BuckBackground(
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const BuckLogoBadge(size: 88),
              const SizedBox(height: 18),
              Text(
                'Buck',
                style: AppTextStyles.h1.copyWith(
                  fontSize: 32,
                  letterSpacing: -0.6,
                  color: palette.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Budget Tracker',
                style: AppTextStyles.bodySubdued.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: palette.textSecondary,
                ),
              ),
              const SizedBox(height: 28),
              SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(
                  strokeWidth: 2.4,
                  color: AppColors.primaryOrange.withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
