import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';

/// Shared visual palette and reusable building blocks aligned with the Figma
/// `Settings Menu` (`2498:609`) and `Main Mobile` (`2172:33`) sub-screens.
abstract final class SettingsColors {
  static const scaffoldBg = AppColors.navBarBg; // #100B09
  static const cardSurface = Color(0xFF1D110C);
  static const inputBg = AppColors.inputBg; // #35251D
  static const border = Color(0xFF785B4C);
  static const subtleBorder = Color(0xFF483126);
  static const accent = Color(0xFFD98B5C);
  static const accentOrange = AppColors.primaryOrange; // #FF994A
  static const textPrimary = AppColors.textPrimary; // #FFF7EE
  static const textMuted = AppColors.textSecondary; // #C6B5AB

  static const dangerSurface = Color(0xFF271315);
  static const dangerReminderBg = Color(0xFF351B1E);
  static const dangerBorder = Color(0xFF713A3B);
  static const dangerTitle = Color(0xFFFF9B91);

  static const orangeButtonGradient = LinearGradient(
    begin: Alignment(-0.9, -0.3),
    end: Alignment(0.9, 0.3),
    colors: [Color(0xFFE57136), Color(0xFFF48648), Color(0xFFFF8D43)],
  );

  static const redButtonGradient = LinearGradient(
    begin: Alignment(-0.9, -0.3),
    end: Alignment(0.9, 0.3),
    colors: [Color(0xFFAC2530), Color(0xFFC42F3A), Color(0xFFD13945)],
  );
}

/// Full-screen container matching the dark `#100B09` edge-to-edge Figma settings
/// canvas while honoring device safe insets and protecting top/bottom bars.
class SettingsScaffold extends StatefulWidget {
  final Widget child;

  const SettingsScaffold({super.key, required this.child});

  @override
  State<SettingsScaffold> createState() => _SettingsScaffoldState();
}

class _SettingsScaffoldState extends State<SettingsScaffold>
    with SingleTickerProviderStateMixin {
  double _swipeBackOffset = 0.0;
  late final AnimationController _snapBackController = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 180),
  );
  Animation<double>? _snapBackAnim;

  @override
  void initState() {
    super.initState();
    AppLayout.pushDarkBarSurface();
    _snapBackController.addListener(() {
      final anim = _snapBackAnim;
      if (anim != null && mounted) {
        setState(() => _swipeBackOffset = anim.value);
      }
    });
  }

  @override
  void dispose() {
    _snapBackController.dispose();
    AppLayout.popDarkBarSurface();
    super.dispose();
  }

  void _onSwipeBackUpdate(DragUpdateDetails details) {
    if (!Navigator.of(context).canPop()) return;
    if (_snapBackController.isAnimating) {
      _snapBackController.stop();
    }
    final next = _swipeBackOffset + details.delta.dx;
    if (next >= 0.0 || _swipeBackOffset > 0.0) {
      setState(() => _swipeBackOffset = math.max(0.0, next));
    }
  }

  void _onSwipeBackEnd(DragEndDetails details) {
    if (_swipeBackOffset == 0.0 && (details.primaryVelocity ?? 0.0) <= 320) {
      return;
    }
    if (!Navigator.of(context).canPop()) {
      setState(() => _swipeBackOffset = 0.0);
      return;
    }
    final velocity = details.primaryVelocity ?? 0.0;
    if (velocity > 320 || _swipeBackOffset > 96.0) {
      setState(() => _swipeBackOffset = 0.0);
      Navigator.of(context).maybePop();
      return;
    }
    _snapBackAnim = Tween<double>(begin: _swipeBackOffset, end: 0.0).animate(
      CurvedAnimation(parent: _snapBackController, curve: Curves.easeOutCubic),
    );
    _snapBackController.forward(from: 0.0);
  }

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    final topInset = AppLayout.topSafeInset(context);
    final bottomInset = AppLayout.bottomSafeInset(context);
    final leftInset = AppLayout.leftSafeInset(context);
    final rightInset = AppLayout.rightSafeInset(context);

    return Scaffold(
      backgroundColor: palette.scaffoldDarkBg,
      body: GestureDetector(
        behavior: HitTestBehavior.translucent,
        excludeFromSemantics: true,
        onHorizontalDragUpdate: _onSwipeBackUpdate,
        onHorizontalDragEnd: _onSwipeBackEnd,
        onHorizontalDragCancel: () => _onSwipeBackEnd(DragEndDetails()),
        child: Transform.translate(
          offset: Offset(_swipeBackOffset, 0),
          child: Stack(
            fit: StackFit.expand,
            children: [
              Align(
                alignment: Alignment.topCenter,
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 520),
                  child: SingleChildScrollView(
                    padding: EdgeInsets.fromLTRB(
                      math.max(24.0, leftInset + 16.0),
                      math.max(20.0, topInset + 16.0),
                      math.max(24.0, rightInset + 16.0),
                      math.max(44.0, bottomInset + 28.0),
                    ),
                    child: widget.child,
                  ),
                ),
              ),
              // Smooth top/bottom safe-area scrims prevent scrolled content from
              // colliding with the status bar/notch or floating browser toolbar.
              Positioned(
                top: 0,
                left: 0,
                right: 0,
                height: math.max(16.0, topInset + 14.0),
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          palette.scaffoldDarkBg,
                          palette.scaffoldDarkBg.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: math.max(16.0, bottomInset + 14.0),
                child: IgnorePointer(
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.bottomCenter,
                        end: Alignment.topCenter,
                        colors: [
                          palette.scaffoldDarkBg,
                          palette.scaffoldDarkBg.withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header for settings sub-screens.
///
/// Supports two Figma header styles:
/// - `largeTitle = false` (Settings, Security, Feedback): centered `20px` title
///   beside the transparent `40x40` back button.
/// - `largeTitle = true` (Profile & Account, Appearance, Danger Zone): pill
///   `#35251D` `40x40` back button with a `34px` ExtraBold title underneath.
class SettingsPageHeader extends StatelessWidget {
  final String title;
  final String subtitle;
  final bool largeTitle;
  final VoidCallback? onBack;

  const SettingsPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    this.largeTitle = false,
    this.onBack,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    final handleBack = onBack ?? () => Navigator.of(context).maybePop();

    if (largeTitle) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SettingsBackButton(filled: true, onTap: handleBack),
          const SizedBox(height: 14),
          Text(
            title,
            style: GoogleFonts.inter(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              height: 42 / 34,
              color: palette.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 16,
              fontWeight: FontWeight.w400,
              height: 22 / 16,
              color: palette.textSecondary,
            ),
          ),
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: _SettingsBackButton(filled: false, onTap: handleBack),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 44),
                child: Text(
                  title,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    height: 28 / 20,
                    color: palette.textPrimary,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 22),
        Text(
          subtitle,
          style: GoogleFonts.inter(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            height: 22 / 16,
            color: palette.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _SettingsBackButton extends StatelessWidget {
  final bool filled;
  final VoidCallback onTap;

  const _SettingsBackButton({required this.filled, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    return Material(
      color: filled ? palette.inputBg : Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: const Key('settings_back_button'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          width: 40,
          height: 40,
          child: Center(
            child: SvgPicture.asset(
              'assets/icons/profile_panel_arrow_left.svg',
              width: 20,
              height: 20,
              colorFilter: palette.isLight
                  ? ColorFilter.mode(palette.textPrimary, BlendMode.srcIn)
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

/// Primary orange gradient button (`Save changes`, `Send feedback`).
class SettingsOrangeButton extends StatelessWidget {
  final String label;
  final bool loading;
  final VoidCallback? onTap;

  const SettingsOrangeButton({
    super.key,
    required this.label,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(12),
        child: Ink(
          height: 48,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            gradient: enabled ? SettingsColors.orangeButtonGradient : null,
            color: enabled ? null : SettingsColors.inputBg,
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: SettingsColors.cardSurface,
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      height: 24 / 16,
                      color: enabled
                          ? SettingsColors.cardSurface
                          : SettingsColors.textMuted,
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

/// Red gradient button matching Figma `Button/Red Small` (`Sign out`, `Request deletion`).
class SettingsRedButton extends StatelessWidget {
  final String label;
  final double height;
  final bool loading;
  final VoidCallback? onTap;

  const SettingsRedButton({
    super.key,
    required this.label,
    this.height = 48,
    this.loading = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null && !loading;
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: enabled ? onTap : null,
        borderRadius: BorderRadius.circular(8),
        child: Ink(
          height: height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            gradient: enabled ? SettingsColors.redButtonGradient : null,
            color: enabled ? null : const Color(0xFF4A2528),
          ),
          child: Center(
            child: loading
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.2,
                      color: Colors.white,
                    ),
                  )
                : Text(
                    label,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      height: 24 / 14,
                      color: enabled
                          ? Colors.white
                          : Colors.white.withValues(alpha: 0.48),
                    ),
                  ),
          ),
        ),
      ),
    );
  }
}

void showSettingsSnackBar(
  BuildContext context,
  String message, {
  bool isError = false,
}) {
  final bottomInset = AppLayout.bottomSafeInset(context);
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError
            ? const Color(0xFFC42F3A)
            : AppColors.primaryOrange,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.fromLTRB(
          16,
          0,
          16,
          math.max(16.0, bottomInset + 12.0),
        ),
      ),
    );
}
