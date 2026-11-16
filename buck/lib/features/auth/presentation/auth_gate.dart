import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/widgets/buck_background.dart';
import '../../shell/presentation/main_shell.dart';
import '../data/auth_service.dart';
import 'screens/sign_in_screen.dart';

/// Shows the app shell when a Supabase session exists, otherwise Sign In.
/// Surfaces Supabase startup errors cleanly with a manual retry option.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  bool _retrying = false;

  Future<void> _retryInit() async {
    if (_retrying) return;
    setState(() => _retrying = true);
    try {
      await SupabaseService.initialize();
    } catch (_) {
      // Error state is recorded in SupabaseService.initErrorNotifier.
    } finally {
      if (mounted) {
        setState(() => _retrying = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<String?>(
      valueListenable: SupabaseService.initErrorNotifier,
      builder: (context, initError, _) {
        if (initError != null && !SupabaseService.isInitialized) {
          return _SupabaseInitErrorView(
            message: initError,
            retrying: _retrying,
            onRetry: _retryInit,
          );
        }

        return StreamBuilder<AuthState>(
          stream: _authService.onAuthStateChange,
          builder: (context, snapshot) {
            final session =
                snapshot.data?.session ?? _authService.currentSession;
            if (session == null) return const SignInScreen();
            return MainShell(key: ValueKey(session.user.id));
          },
        );
      },
    );
  }
}

class _SupabaseInitErrorView extends StatelessWidget {
  final String message;
  final bool retrying;
  final Future<void> Function() onRetry;

  const _SupabaseInitErrorView({
    required this.message,
    required this.retrying,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    final palette = BuckPalette.of(context);
    return Scaffold(
      backgroundColor: palette.shellBg,
      body: BuckBackground(
        useSafeArea: true,
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 380),
              child: Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: palette.glassCardBg,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: palette.glassCardBorder),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.cloud_off_rounded,
                      color: AppColors.primaryOrange,
                      size: 40,
                    ),
                    const SizedBox(height: 14),
                    Text(
                      'Unable to connect to Buck',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        color: palette.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      maxLines: 4,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: palette.textSecondary,
                        fontSize: 13,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: retrying ? null : onRetry,
                        style: FilledButton.styleFrom(
                          backgroundColor: AppColors.primaryOrange,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(retrying ? 'Connecting...' : 'Retry'),
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
