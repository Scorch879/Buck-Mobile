import 'package:flutter/material.dart';

class AppColors {
  // Primary Backgrounds & Surfaces
  static const Color background = Color(0xFF100705);       // Deep charcoal brown
  static const Color backgroundDark = Color(0xFF0A0403);   // Darkest backdrop
  static const Color cardSurface = Color(0xFF1E0600);      // Card fill
  static const Color cardSurfaceAlt = Color(0xFF1D0B06);   // Alternate card fill

  // Borders
  static const Color cardBorder = Color(0xFFFD994A);       // Vibrant orange stroke
  static const Color inputBorder = Color(0xFF785B4C);      // Subdued brown stroke
  static const Color dividerColor = Color(0xFF5A443A);     // Divider line color

  // Accents & Gradients
  static const Color primaryOrange = Color(0xFFF97316);    // Burnt orange
  static const Color amberAccent = Color(0xFFFB923C);      // Warm amber
  static const Color peachAccent = Color(0xFFFDBA74);      // Soft peach
  static const Color lightPeach = Color(0xFFFED7AA);       // Highlight cream peach
  static const Color trackBrown = Color(0xFF4A2D22);       // Progress bar track brown

  // Buttons & Raised Elements
  static const Color raisedCream = Color(0xFFFFF7EE);      // Off-white cream surface
  static const Color textDark = Color(0xFF1D0B06);         // Dark button label text

  // Input Fields
  static const Color inputBg = Color(0xFF35251D);          // Input container background
  static const Color placeholderText = Color(0xFFC6B5AB);  // Subdued placeholder text

  // Typography
  static const Color textPrimary = Color(0xFFFFF7EE);      // White / Cream primary text
  static const Color textSecondary = Color(0xFFC6B5AB);    // Subdued secondary text
  static const Color textAccent = Color(0xFFD98B5C);       // Eyebrow / link orange text

  // Badges & Analytics
  static const Color badgeCyanBg = Color(0xFF00415D);      // +99% badge dark cyan bg
  static const Color badgeCyanText = Color(0xFF56D3C7);    // +99% badge bright cyan text

  // Navigation Bar
  static const Color navBarBg = Color(0xFF100B09);         // Bottom navigation bar container
  static const Color navBarBorder = Color(0xFFFDBA74);     // Bottom navigation border
  static const Color navBarIcon = Color(0xFFFF8E5D);       // Bottom navbar icon color
  static const Color navBarIconActive = Color(0xCCFF4400); // Active navbar icon (vivid orange @ 80%)
  static const Color navBarActive = Color(0xFFFFF7EE);     // Active home button icon
  static const Color navRaisedSurface = Color(
    0xFFFFE7D2,
  ); // Raised active tab circle
  static const Color navRaisedGlow = Color(0x47F97316); // Glow under raised tab

  // App Shell (Header / Screen backdrop)
  static const Color headerBorder = Color(0xFFFF994A); // Header bottom stroke
  static const Color screenGradientTop = Color(0xFF180D09);
  static const Color screenGradientBottom = Color(0xFF4A1D0B);

  // Glass Cards (dashboard / expenses)
  static const Color glassCardBg = Color(0xB3000000); // Black @ 70%
  static const Color glassCardBorder = Color(0xEBFF994A); // Orange @ 92%
  static const Color glassCardGlow = Color(0x2EFF6A13); // Orange glow @ 18%
  static const Color cardTitle = Color(0xFFD5E2F5); // Cool card title text
  static const Color metricValue = Color(0xFFF7FAFF); // Metric numbers
  static const Color subtleDivider = Color(0x94785B4C); // Brown divider @ 58%
  static const Color listFooterBg = Color(
    0xFF120B07,
  ); // Recent list footer strip

  // Quick Actions
  static const Color actionIconBg = Color(0xFF1A1008);
  static const Color actionIconBorder = Color(0x66FF994A); // Orange @ 40%

  // Orange gradient (AI icon, wallet / plus buttons)
  static const Color gradientOrangeStart = Color(0xFFE57136);
  static const Color gradientOrangeEnd = Color(0xFFFF8D43);

  // Wallet allocation bars
  static const Color walletPurple = Color(0xFF936CE4);
  static const Color walletGreen = Color(0xFF2F9E7C);
  static const Color walletOrange = Color(0xFFFF8E5D);
  static const Color walletTeal = Color(0xFF2A7D8C);

  // Badges (translucent variant)
  static const Color badgeCyanBgSoft = Color(0x7D00415D); // Dark cyan @ 49%

  // Cash Flow (Income / Expenses / Savings)
  static const Color incomeGreen = Color(0xFF36C49A);
  static const Color incomeTileBg = Color(0xFF0D2B1A);
  static const Color incomeTileBorder = Color(0x4536C49A); // Green @ 27%
  static const Color expensePink = Color(0xFFE95879);
  static const Color expenseTileBg = Color(0xFF2B0D15);
  static const Color expenseTileBorder = Color(0x45E95879); // Pink @ 27%
  static const Color savingsGreen = Color(0xFF4ADE80);
}

/// Adaptive light/dark color tokens resolved from `Theme.of(context).brightness`.
///
/// Dark values preserve the Figma espresso/burnt-orange aesthetic verbatim, while
/// light values render a clean warm-cream palette when `'Light'` is chosen in
/// Appearance settings.
class BuckPalette {
  final bool isLight;

  const BuckPalette._(this.isLight);

  static BuckPalette of(BuildContext context) {
    return BuckPalette._(Theme.of(context).brightness == Brightness.light);
  }

  Color get shellBg => isLight ? const Color(0xFFF6EDE4) : const Color(0xFF2B1309);
  Color get scaffoldDarkBg => isLight ? const Color(0xFFFBF5EE) : AppColors.navBarBg;
  Color get cardSurface => isLight ? const Color(0xFFFFFFFF) : const Color(0xFF1D110C);
  Color get surfaceElevated => isLight ? const Color(0xFFFFF7EE) : const Color(0xFF241710);
  Color get glassCardBg =>
      isLight ? const Color(0xEBFFFFFF) : AppColors.glassCardBg;
  Color get glassCardBorder =>
      isLight ? const Color(0xA6E57136) : AppColors.glassCardBorder;
  Color get glassCardGlow =>
      isLight ? const Color(0x1EE57136) : AppColors.glassCardGlow;
  Color get inputBg => isLight ? const Color(0xFFF1E3D5) : AppColors.inputBg;
  Color get border => isLight ? const Color(0xFFD8BEAA) : const Color(0xFF785B4C);
  Color get subtleBorder =>
      isLight ? const Color(0xFFE7D3C2) : const Color(0xFF483126);
  Color get divider =>
      isLight ? const Color(0x4DD98B5C) : AppColors.subtleDivider;
  Color get textPrimary =>
      isLight ? const Color(0xFF1D0B06) : AppColors.textPrimary;
  Color get textSecondary =>
      isLight ? const Color(0xFF6E5244) : AppColors.textSecondary;
  Color get textAccent =>
      isLight ? const Color(0xFFC85314) : AppColors.textAccent;
  Color get cardTitle =>
      isLight ? const Color(0xFF23110A) : AppColors.cardTitle;
  Color get metricValue =>
      isLight ? const Color(0xFF190A05) : AppColors.metricValue;
  Color get navBarBg =>
      isLight ? const Color(0xFFFDF7F1) : AppColors.navBarBg;
  Color get navBarBorder =>
      isLight ? const Color(0xFFE57136) : AppColors.navBarBorder;
  Color get navRaisedSurface =>
      isLight ? const Color(0xFFFFDFC4) : AppColors.navRaisedSurface;
  Color get navBarIcon =>
      isLight ? const Color(0xFFD86122) : AppColors.navBarIcon;
  Color get actionIconBg =>
      isLight ? const Color(0xFFFFEFE0) : AppColors.actionIconBg;
  Color get trackBrown =>
      isLight ? const Color(0xFFEBD9CA) : AppColors.trackBrown;
  Color get listFooterBg =>
      isLight ? const Color(0xFFF3E6DA) : AppColors.listFooterBg;
  Color get headerText => isLight ? const Color(0xFF1D0B06) : Colors.white;
  Color get headerDivider =>
      isLight ? const Color(0x4DE57136) : const Color(0x5CE66820);
  List<Color> get headerGradientColors => isLight
      ? const [Color(0xFFF6EDE4), Color(0xF0F6EDE4), Color(0xCCF6EDE4)]
      : const [Color(0xFF2B1309), Color(0xDB261108), Color(0xB8220F07)];
  Color get panelOverlayBg =>
      isLight ? const Color(0xFFFBF5EE) : AppColors.navBarBg;
  Color get panelCardBg =>
      isLight ? const Color(0xFFFFFFFF) : const Color(0xFF392519);
  Color get panelTileBg =>
      isLight ? const Color(0xFFF4E8DC) : const Color(0xFF241710);
  Color get chatSurfaceBg =>
      isLight ? const Color(0xFFFDF7F1) : const Color(0xFF140B07);
  Color get chatBubbleAiBg =>
      isLight ? const Color(0xFFF4E7DA) : const Color(0xFF22130C);
  Color get chartGridLine =>
      isLight ? const Color(0x33785B4C) : const Color(0x2E785B4C);
  Color get incomeTileBg =>
      isLight ? const Color(0xFFE6F8F1) : AppColors.incomeTileBg;
  Color get expenseTileBg =>
      isLight ? const Color(0xFFFDECEF) : AppColors.expenseTileBg;
  Color get dangerSurface =>
      isLight ? const Color(0xFFFCECEE) : const Color(0xFF271315);
  Color get dangerReminderBg =>
      isLight ? const Color(0xFFF8DCE0) : const Color(0xFF351B1E);
  Color get dangerBorder =>
      isLight ? const Color(0xFFE39B9D) : const Color(0xFF713A3B);
  Color get dangerTitle =>
      isLight ? const Color(0xFFB32530) : const Color(0xFFFF9B91);
}
