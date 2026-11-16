import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/buck_background.dart';
import '../../../../core/widgets/buck_button.dart';
import '../../../../core/widgets/buck_text_field.dart';
import '../../data/auth_service.dart';
import '../widgets/buck_logo_badge.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _emailSent = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  bool _validateEmail() {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return false;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return false;
    }

    setState(() => _errorMessage = null);
    return true;
  }

  Future<void> _handleReset() async {
    if (!_validateEmail()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.resetPassword(email: _emailController.text);
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _emailSent = true;
      });
    } on AuthException catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = e.message;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An error occurred while sending the reset link: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final topSafe = AppLayout.topSafeInset(context);
    final bottomSafe = AppLayout.bottomSafeInset(context);
    final palette = BuckPalette.of(context);

    return Scaffold(
      backgroundColor: palette.shellBg,
      extendBody: true,
      body: BuckBackground(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final isNarrow = constraints.maxWidth < 380;
            final isShort = constraints.maxHeight < 780;
            final isCompact = constraints.maxHeight < 700;
            final horizontalPad = isNarrow ? 14.0 : 16.0;
            final topPad = topSafe + (isCompact ? 12.0 : 18.0);
            final bottomPad = bottomSafe + (isCompact ? 14.0 : 20.0);
            final usableHeight = math.max(
              0.0,
              constraints.maxHeight - topPad - bottomPad,
            );

            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontalPad,
                topPad,
                horizontalPad,
                bottomPad,
              ),
              child: Center(
                child: ConstrainedBox(
                  constraints: BoxConstraints(
                    minHeight: usableHeight,
                    maxWidth: 480,
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildHeroSection(
                        isShort: isShort,
                        isCompact: isCompact,
                        isNarrow: isNarrow,
                      ),
                      SizedBox(height: isCompact ? 12 : (isShort ? 16 : 24)),
                      _buildFormSurface(
                        isShort: isShort,
                        isCompact: isCompact,
                        isNarrow: isNarrow,
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeroSection({
    required bool isShort,
    required bool isCompact,
    required bool isNarrow,
  }) {
    final headlineSize = isCompact
        ? (isNarrow ? 21.0 : 23.0)
        : (isNarrow ? 24.0 : (isShort ? 26.0 : 30.0));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            BuckLogoBadge(size: isCompact ? 36 : (isShort ? 40 : 46)),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Buck',
                    style: AppTextStyles.h2.copyWith(
                      fontSize: isCompact ? 18 : 20,
                      height: 1.1,
                    ),
                  ),
                  Text(
                    'Budget Tracker',
                    style: AppTextStyles.caption.copyWith(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            TextButton.icon(
              style: TextButton.styleFrom(
                foregroundColor: AppColors.lightPeach,
                backgroundColor: AppColors.primaryOrange.withValues(alpha: 0.14),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: AppColors.amberAccent.withValues(alpha: 0.45),
                  ),
                ),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              onPressed: () => Navigator.of(context).pop(),
              icon: const Icon(Icons.arrow_back_rounded, size: 15),
              label: Text(
                'Back',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lightPeach,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 10 : (isShort ? 14 : 20)),
        Text(
          'ACCOUNT RECOVERY',
          style: AppTextStyles.eyebrow.copyWith(
            fontSize: isCompact ? 10 : 11,
            color: AppColors.amberAccent,
          ),
        ),
        SizedBox(height: isCompact ? 4 : 6),
        Text.rich(
          TextSpan(
            style: AppTextStyles.h1.copyWith(
              fontSize: headlineSize,
              height: 1.12,
              fontWeight: FontWeight.w800,
            ),
            children: [
              const TextSpan(text: 'Get back into\n'),
              TextSpan(
                text: 'your Buck account.',
                style: TextStyle(color: AppColors.amberAccent),
              ),
            ],
          ),
        ),
        SizedBox(height: isCompact ? 4 : 6),
        Text(
          'Enter the email connected to your account and we will send a secure reset link.',
          style: AppTextStyles.bodySubdued.copyWith(
            fontSize: isCompact ? 12 : (isShort ? 13 : 14),
            height: isCompact ? 1.28 : 1.38,
          ),
        ),
      ],
    );
  }

  Widget _buildFormSurface({
    required bool isShort,
    required bool isCompact,
    required bool isNarrow,
  }) {
    final palette = BuckPalette.of(context);
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 16 : (isCompact ? 18 : 22),
        vertical: isCompact ? 16 : (isShort ? 22 : 26),
      ),
      decoration: BoxDecoration(
        color: palette.isLight ? palette.glassCardBg : null,
        gradient: palette.isLight
            ? null
            : LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  const Color(0xFF281209).withValues(alpha: 0.90),
                  AppColors.cardSurface.withValues(alpha: 0.94),
                ],
              ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: palette.isLight
              ? palette.glassCardBorder
              : AppColors.cardBorder.withValues(alpha: 0.45),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isLight ? 0.08 : 0.45),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'RESET PASSWORD',
            style: AppTextStyles.eyebrow.copyWith(color: palette.textAccent),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Reset Password',
            style: (isShort
                    ? AppTextStyles.h1.copyWith(fontSize: 23)
                    : AppTextStyles.h2.copyWith(fontSize: 26))
                .copyWith(color: palette.textPrimary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 6),
          Text(
            'We will email instructions to set a new password.',
            style: AppTextStyles.bodySubdued.copyWith(
              fontSize: 13,
              color: palette.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isShort ? 16 : 22),

          // Error Message Banner
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: palette.dangerSurface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: palette.dangerBorder),
              ),
              child: Row(
                children: [
                  Icon(Icons.error_outline, color: palette.dangerTitle, size: 18),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.body.copyWith(
                        color: palette.dangerTitle,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
          ],

          if (_emailSent) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: AppColors.badgeCyanBg.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.badgeCyanText.withValues(alpha: 0.5),
                ),
              ),
              child: Column(
                children: [
                  const Icon(
                    Icons.check_circle_outline,
                    color: AppColors.badgeCyanText,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Reset Link Sent',
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 18,
                      color: AppColors.badgeCyanText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Password reset link sent to ${_emailController.text.trim()}! Please check your inbox and spam folder.',
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
          ] else ...[
            // Email input
            BuckTextField(
              label: 'Email address',
              placeholder: 'you@example.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: isShort ? 18 : 24),

            // Send Reset Link CTA (Orange button matching Figma)
            BuckButton(
              text: 'Send Reset Link',
              variant: BuckButtonVariant.orange,
              suffixIcon: Icons.arrow_forward_rounded,
              isLoading: _isLoading,
              onPressed: _handleReset,
            ),
            const SizedBox(height: 18),
          ],

          // Footer: Back to Sign In
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Already have an account? ',
                  style: AppTextStyles.bodySubdued.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: () => Navigator.of(context).pop(),
                  child: Text(
                    'Back to Sign In',
                    style: AppTextStyles.label.copyWith(
                      color: palette.textPrimary,
                      decoration: TextDecoration.underline,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
