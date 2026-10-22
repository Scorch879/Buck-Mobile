import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
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
    final size = MediaQuery.sizeOf(context);
    final isShort = size.height < 780;
    final isNarrow = size.width < 380;

    return Scaffold(
      body: BuckBackground(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isNarrow ? 14 : 20,
              vertical: isShort ? 12 : 24,
            ),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Container(
                padding: EdgeInsets.symmetric(
                  horizontal: isNarrow ? 18 : 24,
                  vertical: isShort ? 20 : 28,
                ),
                decoration: BoxDecoration(
                  color: AppColors.cardSurface.withValues(alpha: 0.92),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.cardBorder, width: 1.0),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.5),
                      blurRadius: 24,
                      offset: const Offset(0, 10),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Logo Avatar (matching Figma 2173:4312)
                    BuckLogoBadge(size: isShort ? 72 : 84),
                    SizedBox(height: isShort ? 14 : 20),

                    // Eyebrow & Title
                    Text('ACCOUNT RECOVERY', style: AppTextStyles.eyebrow),
                    const SizedBox(height: 6),
                    Text(
                      'Reset Password',
                      style: isShort
                          ? AppTextStyles.h1.copyWith(fontSize: 24)
                          : AppTextStyles.h1,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Enter the email connected to your Buck account',
                      style: AppTextStyles.bodySubdued,
                      textAlign: TextAlign.center,
                    ),
                    SizedBox(height: isShort ? 18 : 28),

                  // Error Message Banner
                  if (_errorMessage != null) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF4A100B),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: const Color(0xFFEA4335).withValues(alpha: 0.6)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline, color: Color(0xFFFF6B6B), size: 18),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              _errorMessage!,
                              style: AppTextStyles.body.copyWith(
                                color: const Color(0xFFFFD1D1),
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
                        border: Border.all(color: AppColors.badgeCyanText.withValues(alpha: 0.5)),
                      ),
                      child: Column(
                        children: [
                          const Icon(Icons.check_circle_outline, color: AppColors.badgeCyanText, size: 40),
                          const SizedBox(height: 12),
                          Text(
                            'Reset Link Sent',
                            style: AppTextStyles.h2.copyWith(fontSize: 18, color: AppColors.badgeCyanText),
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
                    const SizedBox(height: 24),
                  ] else ...[
                    // Email input
                    BuckTextField(
                      label: 'Email address',
                      placeholder: 'you@example.com',
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                    ),
                    SizedBox(height: isShort ? 18 : 28),

                    // Send Reset Link CTA (Orange button matching Figma)
                    BuckButton(
                      text: 'Send Reset Link',
                      variant: BuckButtonVariant.orange,
                      suffixIcon: Icons.arrow_forward_rounded,
                      isLoading: _isLoading,
                      onPressed: _handleReset,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // Footer: Back to Sign In
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text('Already have an account? ', style: AppTextStyles.bodySubdued),
                        GestureDetector(
                          onTap: () => Navigator.of(context).pop(),
                          child: Text(
                            'Back to Sign In',
                            style: AppTextStyles.label.copyWith(
                              color: AppColors.textPrimary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
