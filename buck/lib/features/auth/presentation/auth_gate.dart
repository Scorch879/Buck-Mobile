import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/dev_config.dart';
import '../../finance/data/dev_finance_source.dart';
import '../../finance/presentation/finance_controller.dart';
import '../../shell/presentation/main_shell.dart';
import '../data/auth_service.dart';
import 'screens/sign_in_screen.dart';

/// Shows the app shell when a Supabase session exists, otherwise Sign In.
/// Reacts to sign-in, OAuth callbacks, session restore, sign-out and dev sessions.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();
  FinanceController? _devController;

  @override
  void dispose() {
    _devController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<bool>(
      valueListenable: DevConfig.mockAdminSessionActive,
      builder: (context, mockActive, _) {
        if (mockActive) {
          _devController ??= FinanceController(DevFinanceSource());
          return MainShell(financeController: _devController);
        }

        return StreamBuilder<AuthState>(
          stream: _authService.onAuthStateChange,
          builder: (context, snapshot) {
            final session =
                snapshot.data?.session ?? _authService.currentSession;
            if (session == null) return const SignInScreen();
            return const MainShell();
          },
        );
      },
    );
  }
}
