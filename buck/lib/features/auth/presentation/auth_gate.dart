import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../shell/presentation/main_shell.dart';
import '../data/auth_service.dart';
import 'screens/sign_in_screen.dart';

/// Shows the app shell when a Supabase session exists, otherwise Sign In.
/// Reacts to sign-in, OAuth callbacks, session restore and sign-out.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final _authService = AuthService();

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthState>(
      stream: _authService.onAuthStateChange,
      builder: (context, snapshot) {
        final session = snapshot.data?.session ?? _authService.currentSession;
        if (session == null) return const SignInScreen();
        return const MainShell();
      },
    );
  }
}
