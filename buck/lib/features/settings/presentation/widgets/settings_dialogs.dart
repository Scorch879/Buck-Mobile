import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../../core/theme/app_colors.dart';
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

/// Shows the Figma "Deletion request confirmation" (`2542:1221`) modal card.
/// Returns the verified/entered password string (empty string if account does
/// not use a password) when confirmed, or `null` when canceled.
Future<String?> showDeletionRequestConfirmationDialog(
  BuildContext context, {
  bool requirePassword = true,
}) {
  return showDialog<String>(
    context: context,
    barrierColor: Colors.black.withValues(alpha: 0.65),
    builder: (_) => _DeletionPasswordConfirmationDialog(
      requirePassword: requirePassword,
    ),
  );
}

class _DeletionPasswordConfirmationDialog extends StatefulWidget {
  final bool requirePassword;

  const _DeletionPasswordConfirmationDialog({required this.requirePassword});

  @override
  State<_DeletionPasswordConfirmationDialog> createState() =>
      _DeletionPasswordConfirmationDialogState();
}

class _DeletionPasswordConfirmationDialogState
    extends State<_DeletionPasswordConfirmationDialog> {
  final _passwordController = TextEditingController();
  bool _obscurePassword = true;
  String? _errorText;

  @override
  void dispose() {
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final password = _passwordController.text;
    if (widget.requirePassword && password.isEmpty) {
      setState(() {
        _errorText = 'Please enter your password to confirm deletion.';
      });
      return;
    }
    Navigator.of(context).pop(password);
  }

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 392),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: palette.cardSurface,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: palette.border, width: 1),
          ),
          child: SingleChildScrollView(
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
                const SizedBox(height: 18),
                Text(
                  'Request account deletion?',
                  style: GoogleFonts.inter(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    height: 30 / 22,
                    color: palette.textPrimary,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  widget.requirePassword
                      ? 'Enter your password to schedule account deletion. Your account enters a 10-day recovery window — sign back in anytime during those 10 days to cancel before deletion becomes permanent.'
                      : 'Confirm account deletion below. Your account enters a 10-day recovery window — sign back in anytime during those 10 days to cancel before deletion becomes permanent.',
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w400,
                    height: 21 / 14,
                    color: palette.textSecondary,
                  ),
                ),
                if (widget.requirePassword) ...[
                  const SizedBox(height: 16),
                  Text(
                    'Current password',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: palette.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 6),
                  TextField(
                    key: const Key('danger_zone_password_input'),
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    autofocus: true,
                    textInputAction: TextInputAction.done,
                    onSubmitted: (_) => _submit(),
                    onChanged: (_) {
                      if (_errorText != null) {
                        setState(() => _errorText = null);
                      }
                    },
                    style: GoogleFonts.inter(
                      fontSize: 15,
                      color: palette.textPrimary,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Enter your password',
                      hintStyle: GoogleFonts.inter(
                        fontSize: 14,
                        color: palette.textSecondary,
                      ),
                      filled: true,
                      fillColor: palette.scaffoldDarkBg,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 12,
                      ),
                      errorText: _errorText,
                      suffixIcon: IconButton(
                        onPressed: () => setState(
                          () => _obscurePassword = !_obscurePassword,
                        ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          size: 20,
                          color: palette.textSecondary,
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(color: palette.border, width: 1),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: palette.dangerTitle,
                          width: 1.5,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: palette.dangerTitle,
                          width: 1.2,
                        ),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: BorderSide(
                          color: palette.dangerTitle,
                          width: 1.5,
                        ),
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 18),
                SettingsRedButton(label: 'Request deletion', onTap: _submit),
                const SizedBox(height: 12),
                Material(
                  color: Colors.transparent,
                  borderRadius: BorderRadius.circular(12),
                  child: InkWell(
                    onTap: () => Navigator.of(context).pop(null),
                    borderRadius: BorderRadius.circular(12),
                    child: Container(
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: palette.border, width: 2),
                      ),
                      alignment: Alignment.center,
                      child: Text(
                        'Keep account',
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          height: 20 / 14,
                          color: palette.textPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
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
