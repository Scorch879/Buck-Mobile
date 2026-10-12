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
