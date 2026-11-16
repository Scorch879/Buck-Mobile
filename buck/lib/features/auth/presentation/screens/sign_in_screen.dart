import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_layout.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/buck_background.dart';
import '../../../../core/widgets/buck_button.dart';
import '../../../../core/widgets/buck_text_field.dart';
import '../../../../core/constants/dev_config.dart';
import '../../data/auth_service.dart';
import 'sign_up_screen.dart';
import 'forgot_password_screen.dart';

class SignInScreen extends StatefulWidget {
  final VoidCallback? onSignInSuccess;

  const SignInScreen({super.key, this.onSignInSuccess});

  @override
  State<SignInScreen> createState() => _SignInScreenState();
}

class _SignInScreenState extends State<SignInScreen> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return false;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return false;
    }

    if (password.isEmpty) {
      setState(() => _errorMessage = 'Please enter your password.');
      return false;
    }

    setState(() => _errorMessage = null);
    return true;
  }

  Future<void> _handleSignIn() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.signIn(
        email: _emailController.text,
        password: _passwordController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.user != null) {
        DevConfig.mockAdminSessionActive.value = false;
        if (widget.onSignInSuccess != null) {
          widget.onSignInSuccess!();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Welcome back, ${response.user?.email ?? 'User'}!'),
              backgroundColor: AppColors.primaryOrange,
            ),
          );
        }
      }
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
        _errorMessage = 'An unexpected error occurred: ${e.toString()}';
      });
    }
  }

  Future<void> _handleGoogleSignIn() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      await _authService.signInWithGoogle();
      if (!mounted) return;
      setState(() => _isLoading = false);
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
        _errorMessage = 'Could not start Google Sign-In: $e';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    final topSafe = AppLayout.topSafeInset(context);
    final bottomSafe = AppLayout.bottomSafeInset(context);

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
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildFormSurface(
                        palette: palette,
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

  Widget _buildFormSurface({
    required BuckPalette palette,
    required bool isShort,
    required bool isCompact,
    required bool isNarrow,
  }) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 16 : (isCompact ? 18 : 22),
        vertical: isCompact ? 18 : (isShort ? 22 : 26),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: palette.isLight
              ? [
                  const Color(0xF8FFFFFF),
                  const Color(0xF2FFF7EE),
                ]
              : [
                  const Color(0xFF281209).withValues(alpha: 0.90),
                  AppColors.cardSurface.withValues(alpha: 0.94),
                ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: palette.glassCardBorder.withValues(alpha: 0.55),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: palette.isLight ? 0.12 : 0.45),
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
            'WELCOME BACK',
            style: AppTextStyles.eyebrow.copyWith(color: palette.textAccent),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isCompact ? 2 : 4),
          Text(
            'Sign in to Buck',
            style: (isCompact
                    ? AppTextStyles.h1.copyWith(fontSize: 21)
                    : (isShort
                        ? AppTextStyles.h1.copyWith(fontSize: 23)
                        : AppTextStyles.h2.copyWith(fontSize: 26)))
                .copyWith(color: palette.textPrimary),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isCompact ? 14 : (isShort ? 18 : 22)),

          // Continue with Google Button
          SizedBox(
            width: double.infinity,
            height: isCompact ? 46 : 52,
            child: OutlinedButton(
              style: OutlinedButton.styleFrom(
                backgroundColor: palette.cardSurface,
                side: BorderSide(color: palette.border, width: 1.2),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(26),
                ),
              ),
              onPressed: _isLoading ? null : _handleGoogleSignIn,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        color: Colors.white,
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'G',
                        style: TextStyle(
                          color: Color(0xFFEA4335),
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      'Continue with Google',
                      style: AppTextStyles.label.copyWith(
                        color: palette.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: isCompact ? 12 : (isShort ? 14 : 18)),

          // Divider
          Row(
            children: [
              Expanded(child: Divider(color: palette.border, thickness: 1)),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Text(
                  'or sign in with email',
                  style: AppTextStyles.bodySubdued.copyWith(
                    fontSize: 12,
                    color: palette.textSecondary,
                  ),
                ),
              ),
              Expanded(child: Divider(color: palette.border, thickness: 1)),
            ],
          ),
          SizedBox(height: isCompact ? 12 : (isShort ? 14 : 18)),

          // Error Message Banner
          if (_errorMessage != null) ...[
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: palette.isLight
                    ? const Color(0xFFFDE8E8)
                    : const Color(0xFF4A100B),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFEA4335).withValues(alpha: 0.6),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.error_outline,
                    color: Color(0xFFFF6B6B),
                    size: 18,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _errorMessage!,
                      style: AppTextStyles.body.copyWith(
                        color: palette.isLight
                            ? const Color(0xFF991B1B)
                            : const Color(0xFFFFD1D1),
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: isCompact ? 10 : 14),
          ],

          // Email input
          BuckTextField(
            label: 'Email address',
            placeholder: 'you@example.com',
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
          ),
          SizedBox(height: isCompact ? 8 : (isShort ? 12 : 14)),

          // Password input
          BuckTextField(
            label: 'Password',
            placeholder: 'Enter your password',
            controller: _passwordController,
            isPassword: true,
          ),
          SizedBox(height: isCompact ? 6 : (isShort ? 8 : 10)),

          // Forgot password link
          Align(
            alignment: Alignment.centerLeft,
            child: GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                );
              },
              child: Text(
                'Forgot password?',
                style: AppTextStyles.eyebrow.copyWith(color: palette.textAccent),
              ),
            ),
          ),
          SizedBox(height: isCompact ? 12 : (isShort ? 16 : 20)),

          // Sign In CTA
          BuckButton(
            text: 'Sign In',
            suffixIcon: Icons.arrow_forward_rounded,
            isLoading: _isLoading,
            onPressed: _handleSignIn,
          ),
          SizedBox(height: isCompact ? 10 : (isShort ? 14 : 16)),

          // Footer: Create account link
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  "Don't have an account? ",
                  style: AppTextStyles.bodySubdued.copyWith(
                    color: palette.textSecondary,
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const SignUpScreen()),
                    );
                  },
                  child: Text(
                    'Create Account',
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
