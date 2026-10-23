import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/widgets/buck_background.dart';
import '../../../../core/widgets/buck_button.dart';
import '../../../../core/widgets/buck_text_field.dart';
import '../../../../core/constants/dev_config.dart';
import '../../data/auth_service.dart';
import '../widgets/buck_logo_badge.dart';
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
  void initState() {
    super.initState();
    if (DevConfig.isDevMode && DevConfig.autoFillAdmin) {
      _emailController.text = DevConfig.adminEmail;
      _passwordController.text = DevConfig.adminPassword;
    }
  }

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

  Future<void> _handleDevAdminLogin() async {
    _emailController.text = DevConfig.adminEmail;
    _passwordController.text = DevConfig.adminPassword;

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final response = await _authService.signIn(
        email: DevConfig.adminEmail,
        password: DevConfig.adminPassword,
      );
      if (!mounted) return;
      setState(() => _isLoading = false);
      if (response.user != null) {
        DevConfig.mockAdminSessionActive.value = false;
        widget.onSignInSuccess?.call();
      }
    } on AuthException catch (e) {
      final msg = e.message.toLowerCase();
      // If email is not confirmed in Supabase or user not found, activate dev admin mode directly
      if (msg.contains('email not confirmed') ||
          (e.statusCode == '400' && msg.contains('not confirmed'))) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        DevConfig.mockAdminSessionActive.value = true;
        return;
      }

      if (msg.contains('invalid login credentials') ||
          msg.contains('not found') ||
          msg.contains('user not found')) {
        try {
          final signUpRes = await _authService.signUp(
            email: DevConfig.adminEmail,
            password: DevConfig.adminPassword,
            fullName: DevConfig.adminName,
          );
          if (!mounted) return;
          if (signUpRes.session != null) {
            setState(() => _isLoading = false);
            widget.onSignInSuccess?.call();
            return;
          }
          // Supabase created the user but requires email confirmation -> enter dev admin session
          setState(() => _isLoading = false);
          DevConfig.mockAdminSessionActive.value = true;
          return;
        } catch (_) {
          if (!mounted) return;
          setState(() => _isLoading = false);
          DevConfig.mockAdminSessionActive.value = true;
          return;
        }
      }
      if (!mounted) return;
      // On any other dev error, fall back to dev admin session so local testing is never blocked
      setState(() => _isLoading = false);
      DevConfig.mockAdminSessionActive.value = true;
    } catch (_) {
      if (!mounted) return;
      setState(() => _isLoading = false);
      DevConfig.mockAdminSessionActive.value = true;
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
                    // Logo Avatar (matching Figma 2172:61)
                    BuckLogoBadge(size: isShort ? 72 : 84),
                    SizedBox(height: isShort ? 14 : 20),

                    // Eyebrow & Title
                    Text('WELCOME BACK', style: AppTextStyles.eyebrow),
                    const SizedBox(height: 4),
                    Text(
                      'Sign in to Buck',
                      style: isShort
                          ? AppTextStyles.h1.copyWith(fontSize: 24)
                          : AppTextStyles.h1,
                    ),
                    SizedBox(height: isShort ? 16 : 22),

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
                  SizedBox(height: isShort ? 14 : 18),

                  // Divider
                  Row(
                    children: [
                      const Expanded(child: Divider(color: AppColors.dividerColor, thickness: 1)),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        child: Text(
                          'or sign in with email',
                          style: AppTextStyles.bodySubdued.copyWith(fontSize: 12),
                        ),
                      ),
                      const Expanded(child: Divider(color: AppColors.dividerColor, thickness: 1)),
                    ],
                  ),
                  SizedBox(height: isShort ? 14 : 18),

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

                  // Dev Mode Quick Login Banner (when DEV_MODE=true)
                  if (DevConfig.isDevMode) ...[
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: AppColors.actionIconBg,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: AppColors.primaryOrange.withValues(alpha: 0.5),
                          width: 1,
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.bolt,
                            color: AppColors.primaryOrange,
                            size: 18,
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'DEV MODE • ADMIN',
                                  style: AppTextStyles.eyebrow.copyWith(
                                    fontSize: 10,
                                    color: AppColors.primaryOrange,
                                  ),
                                ),
                                Text(
                                  DevConfig.adminEmail,
                                  style: AppTextStyles.caption.copyWith(fontSize: 11),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                          TextButton(
                            style: TextButton.styleFrom(
                              backgroundColor: AppColors.primaryOrange,
                              foregroundColor: Colors.white,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 4,
                              ),
                              minimumSize: Size.zero,
                              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(6),
                              ),
                            ),
                            onPressed: _isLoading ? null : _handleDevAdminLogin,
                            child: const Text(
                              'Quick Login',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    SizedBox(height: isShort ? 12 : 16),
                  ],

                  // Email input
                  BuckTextField(
                    label: 'Email address',
                    placeholder: 'you@example.com',
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                  ),
                  SizedBox(height: isShort ? 12 : 16),

                  // Password input
                  BuckTextField(
                    label: 'Password',
                    placeholder: 'Enter your password',
                    controller: _passwordController,
                    isPassword: true,
                  ),
                  SizedBox(height: isShort ? 8 : 12),

                  // Forgot password link
                  Align(
                    alignment: Alignment.centerLeft,
                    child: GestureDetector(
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const ForgotPasswordScreen()),
                        );
                      },
                      child: Text('Forgot password?', style: AppTextStyles.eyebrow),
                    ),
                  ),
                  SizedBox(height: isShort ? 16 : 22),

                  // Sign In CTA
                  BuckButton(
                    text: 'Sign In',
                    suffixIcon: Icons.arrow_forward_rounded,
                    isLoading: _isLoading,
                    onPressed: _handleSignIn,
                  ),
                  SizedBox(height: isShort ? 14 : 18),

                  // Footer: Create account link
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text("Don't have an account? ", style: AppTextStyles.bodySubdued),
                        GestureDetector(
                          onTap: () {
                            Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SignUpScreen()),
                            );
                          },
                          child: Text(
                            'Create Account',
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
