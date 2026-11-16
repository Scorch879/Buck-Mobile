import 'dart:async';
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

class SignUpScreen extends StatefulWidget {
  final VoidCallback? onSignUpSuccess;

  const SignUpScreen({super.key, this.onSignUpSuccess});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  final _authService = AuthService();

  bool _isLoading = false;
  String? _errorMessage;
  bool _accountCreated = false;
  StreamSubscription<AuthState>? _authSub;

  @override
  void initState() {
    super.initState();
    _authSub = _authService.onAuthStateChange.listen((state) {
      if (!mounted || state.session == null) return;
      if (Navigator.of(context).canPop()) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
  }

  @override
  void dispose() {
    _authSub?.cancel();
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  bool _validateInputs() {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    if (name.isEmpty) {
      setState(() => _errorMessage = 'Please enter your full name.');
      return false;
    }

    if (email.isEmpty) {
      setState(() => _errorMessage = 'Please enter your email address.');
      return false;
    }

    final emailRegex = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');
    if (!emailRegex.hasMatch(email)) {
      setState(() => _errorMessage = 'Please enter a valid email address.');
      return false;
    }

    if (password.length < 8) {
      setState(() => _errorMessage = 'Password must be at least 8 characters long.');
      return false;
    }

    if (password != confirmPassword) {
      setState(() => _errorMessage = 'Passwords do not match.');
      return false;
    }

    setState(() => _errorMessage = null);
    return true;
  }

  Future<void> _handleSignUp() async {
    if (!_validateInputs()) return;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.signUp(
        email: _emailController.text,
        password: _passwordController.text,
        fullName: _nameController.text,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (response.user != null) {
        setState(() => _accountCreated = true);
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
    final topSafe = AppLayout.topSafeInset(context);
    final bottomSafe = AppLayout.bottomSafeInset(context);

    return Scaffold(
      backgroundColor: const Color(0xFF2B1309),
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
                      SizedBox(height: isCompact ? 10 : (isShort ? 14 : 20)),
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
                      fontSize: 20,
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
                'Sign In',
                style: AppTextStyles.caption.copyWith(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: AppColors.lightPeach,
                ),
              ),
            ),
          ],
        ),
        SizedBox(height: isCompact ? 8 : (isShort ? 12 : 16)),
        Text(
          'START FRESH WITH BUCK',
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
              const TextSpan(text: 'Build a budget that\n'),
              TextSpan(
                text: 'actually fits',
                style: TextStyle(color: AppColors.amberAccent),
              ),
              const TextSpan(text: ' your life.'),
            ],
          ),
        ),
        SizedBox(height: isCompact ? 4 : 6),
        Text(
          'Create your profile to track cash flow, wallets, and AI financial insights.',
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
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isNarrow ? 16 : (isCompact ? 18 : 22),
        vertical: isCompact ? 16 : (isShort ? 20 : 24),
      ),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            const Color(0xFF281209).withValues(alpha: 0.90),
            AppColors.cardSurface.withValues(alpha: 0.94),
          ],
        ),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: AppColors.cardBorder.withValues(alpha: 0.45),
          width: 1.0,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primaryOrange.withValues(alpha: 0.10),
            blurRadius: 28,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.45),
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
            'GET STARTED',
            style: AppTextStyles.eyebrow,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            'Create your Buck account',
            style: isShort
                ? AppTextStyles.h1.copyWith(fontSize: 22)
                : AppTextStyles.h2.copyWith(fontSize: 25),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: isShort ? 14 : 18),

          if (_accountCreated) ...[
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
                    Icons.mark_email_read_outlined,
                    color: AppColors.badgeCyanText,
                    size: 40,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'Confirmation link sent!',
                    style: AppTextStyles.h2.copyWith(
                      fontSize: 18,
                      color: AppColors.badgeCyanText,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'We sent a verification link to ${_emailController.text.trim()}. Please verify your email before signing in.',
                    style: AppTextStyles.body.copyWith(fontSize: 13),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            BuckButton(
              text: 'Back to Sign In',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ] else ...[
            // Continue with Google Button
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  backgroundColor: AppColors.cardSurfaceAlt,
                  side: const BorderSide(color: AppColors.inputBorder, width: 1.2),
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
                        style: AppTextStyles.label.copyWith(color: AppColors.textPrimary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            SizedBox(height: isShort ? 12 : 16),

            // Divider
            Row(
              children: [
                const Expanded(child: Divider(color: AppColors.dividerColor, thickness: 1)),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text(
                    'or sign up with email',
                    style: AppTextStyles.bodySubdued.copyWith(fontSize: 12),
                  ),
                ),
                const Expanded(child: Divider(color: AppColors.dividerColor, thickness: 1)),
              ],
            ),
            SizedBox(height: isShort ? 12 : 16),

            // Error Banner
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
              const SizedBox(height: 14),
            ],

            // Full name
            BuckTextField(
              label: 'Full name',
              placeholder: 'Your full name',
              controller: _nameController,
            ),
            SizedBox(height: isShort ? 10 : 14),

            // Email input
            BuckTextField(
              label: 'Email address',
              placeholder: 'you@example.com',
              controller: _emailController,
              keyboardType: TextInputType.emailAddress,
            ),
            SizedBox(height: isShort ? 10 : 14),

            // Password input
            BuckTextField(
              label: 'Password',
              placeholder: 'Create a password (min 8 chars)',
              controller: _passwordController,
              isPassword: true,
            ),
            SizedBox(height: isShort ? 10 : 14),

            // Confirm password input
            BuckTextField(
              label: 'Confirm password',
              placeholder: 'Re-enter your password',
              controller: _confirmPasswordController,
              isPassword: true,
            ),
            SizedBox(height: isShort ? 16 : 20),

            // Create Account CTA
            BuckButton(
              text: 'Create Account',
              suffixIcon: Icons.arrow_forward_rounded,
              isLoading: _isLoading,
              onPressed: _handleSignUp,
            ),
            SizedBox(height: isShort ? 14 : 16),

            // Footer: Sign In link
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('Already have an account? ', style: AppTextStyles.bodySubdued),
                  GestureDetector(
                    onTap: () => Navigator.of(context).pop(),
                    child: Text(
                      'Sign In',
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
        ],
      ),
    );
  }
}
