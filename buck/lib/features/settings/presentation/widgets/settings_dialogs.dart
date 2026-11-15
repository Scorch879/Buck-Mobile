import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import 'settings_common.dart';

/// Shows the Figma "Sign out confirmation" (`2542:1209`) modal dialog.
Future<bool?> showSignOutConfirmationDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => _ConfirmationAlertDialog(
      title: 'Sign out of Buck?',
      body:
          "You'll need to sign in again to access your account. Your saved data will stay in your account.",
      confirmLabel: 'Sign out',
      cancelLabel: 'Stay signed in',
      onConfirm: () => Navigator.of(ctx).pop(true),
      onCancel: () => Navigator.of(ctx).pop(false),
    ),
  );
}

/// Shows the Figma "Deletion request confirmation" (`2542:1221`) modal dialog.
Future<bool?> showDeletionRequestConfirmationDialog(BuildContext context) {
  return showDialog<bool>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (ctx) => _ConfirmationAlertDialog(
      title: 'Request account deletion?',
      body:
          "We'll email you a confirmation link. Once you confirm, your account enters a 10-day recovery window. You can recover it during those 10 days. After that, deletion is permanent.",
      confirmLabel: 'Request deletion',
      cancelLabel: 'Keep account',
      onConfirm: () => Navigator.of(ctx).pop(true),
      onCancel: () => Navigator.of(ctx).pop(false),
    ),
  );
}

class _ConfirmationAlertDialog extends StatelessWidget {
  final String title;
  final String body;
  final String confirmLabel;
  final String cancelLabel;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _ConfirmationAlertDialog({
    required this.title,
    required this.body,
    required this.confirmLabel,
    required this.cancelLabel,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 392),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: SettingsColors.cardSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: SettingsColors.border, width: 1),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: SizedBox(
                  width: 48,
                  child: Center(
                    child: SvgPicture.asset(
                      'assets/icons/settings_warning_red.svg',
                      width: 24,
                      height: 24,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                title,
                style: GoogleFonts.inter(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  height: 32 / 24,
                  color: SettingsColors.textPrimary,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                body,
                style: GoogleFonts.inter(
                  fontSize: 16,
                  fontWeight: FontWeight.w400,
                  height: 24 / 16,
                  color: SettingsColors.textMuted,
                ),
              ),
              const SizedBox(height: 20),
              SettingsRedButton(label: confirmLabel, onTap: onConfirm),
              const SizedBox(height: 12),
              Material(
                color: Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                child: InkWell(
                  onTap: onCancel,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    height: 48,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: SettingsColors.border, width: 2),
                    ),
                    alignment: Alignment.center,
                    child: Text(
                      cancelLabel,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        height: 20 / 14,
                        color: SettingsColors.textPrimary,
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
