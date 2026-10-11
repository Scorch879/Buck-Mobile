import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'app_colors.dart';

class AppTextStyles {
  // Headings
  static TextStyle get h1 => GoogleFonts.inter(
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get h2 => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle get balanceTitle => GoogleFonts.inter(
        fontSize: 36,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      );

  // Eyebrow (e.g. "WELCOME BACK", "GET STARTED", "ACCOUNT RECOVERY")
  static TextStyle get eyebrow => GoogleFonts.inter(
        fontSize: 12,
        fontWeight: FontWeight.w700,
        color: AppColors.textAccent,
        letterSpacing: 1.2,
      );

  // Body & Labels
  static TextStyle get body => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      );

  static TextStyle get bodySubdued => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );

  static TextStyle get label => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      );

  // Buttons
  static TextStyle get buttonPrimary => GoogleFonts.inter(
        fontSize: 15,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      );

  static TextStyle get buttonOrange => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.textDark,
      );

  // Badges & Small Text
  static TextStyle get badge => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w700,
        color: AppColors.badgeCyanText,
      );

  // App Shell
  static TextStyle get headerTitle => GoogleFonts.inter(
        fontSize: 18,
        fontWeight: FontWeight.w700,
        height: 24 / 18,
        color: Colors.white,
      );

  // Dashboard cards (Manrope)
  static TextStyle get cardTitle => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.cardTitle,
      );

  static TextStyle get sectionTitle => GoogleFonts.manrope(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: AppColors.cardTitle,
      );

  static TextStyle get amountLarge => GoogleFonts.manrope(
        fontSize: 28,
        fontWeight: FontWeight.w800,
        color: AppColors.textPrimary,
        letterSpacing: -0.56,
      );

  static TextStyle get metricValue => GoogleFonts.manrope(
        fontSize: 22,
        fontWeight: FontWeight.w800,
        color: AppColors.metricValue,
        letterSpacing: -0.22,
      );

  static TextStyle get amountSmall => GoogleFonts.manrope(
        fontSize: 14,
        fontWeight: FontWeight.w700,
        color: AppColors.navBarIcon,
      );

  static TextStyle get badgeSoft => GoogleFonts.manrope(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        color: AppColors.badgeCyanText,
      );

  // Small captions (Inter)
  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      );
}
