import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/supabase_service.dart';
import '../../ai/data/services/buck_ai_service.dart';

class AuthService {
  final SupabaseClient? _customClient;

  AuthService({SupabaseClient? client}) : _customClient = client;

  SupabaseClient get _client => _customClient ?? SupabaseService.client;

  User? get currentUser =>
      SupabaseService.isInitialized ? _client.auth.currentUser : null;

  Session? get currentSession =>
      SupabaseService.isInitialized ? _client.auth.currentSession : null;

  Stream<AuthState> get onAuthStateChange =>
      SupabaseService.isInitialized ? _client.auth.onAuthStateChange : const Stream.empty();

  /// Sign In with Email & Password
  Future<AuthResponse> signIn({
    required String email,
    required String password,
  }) async {
    return await _client.auth.signInWithPassword(
      email: email.trim().toLowerCase(),
      password: password,
    );
  }

  /// Sign Up with Email, Password, and Full Name / Username
  Future<AuthResponse> signUp({
    required String email,
    required String password,
    required String fullName,
  }) async {
    final cleanEmail = email.trim().toLowerCase();
    final cleanName = fullName.trim();

    return await _client.auth.signUp(
      email: cleanEmail,
      password: password,
      data: {
        'full_name': cleanName,
        'username': cleanName,
      },
    );
  }

  /// Send password reset link to user email
  Future<void> resetPassword({required String email}) async {
    await _client.auth.resetPasswordForEmail(
      email.trim().toLowerCase(),
    );
  }

  /// Deep link the native apps listen on (see AndroidManifest.xml / Info.plist).
  static const String mobileRedirectUrl = 'buck://auth-callback';

  /// Where Supabase sends the user back after Google sign-in.
  /// - Web: back to this Flutter app's own origin with trailing slash (e.g. http://localhost:8080/),
  ///   which matches Supabase allowlists like 'http://localhost:8080/' or 'http://localhost:8080/**'.
  /// - Android/iOS: the custom `buck://auth-callback` deep link.
  static String get oauthRedirectUrl {
    if (kIsWeb) {
      final origin = Uri.base.origin;
      return origin.endsWith('/') ? origin : '$origin/';
    }
    return mobileRedirectUrl;
  }

  /// Initiate OAuth flow with Google
  Future<bool> signInWithGoogle() async {
    final redirectTo = oauthRedirectUrl;
    final res = await _client.auth.getOAuthSignInUrl(
      provider: OAuthProvider.google,
      redirectTo: redirectTo,
    );

    var targetUrl = res.url;
    final codeChallenge = Uri.parse(res.url).queryParameters['code_challenge'];
    if (codeChallenge != null && codeChallenge.isNotEmpty) {
      try {
        final directUrl = await _client.rpc<String>(
          'create_mobile_google_oauth_url',
          params: {
            'p_code_challenge': codeChallenge,
            'p_redirect_to': redirectTo,
          },
        );
        if (directUrl.isNotEmpty) {
          targetUrl = directUrl;
        }
      } catch (_) {
        // Fall back to the standard Supabase OAuth URL if the RPC fails.
      }
    }

    return await launchUrl(
      Uri.parse(targetUrl),
      mode: kIsWeb ? LaunchMode.platformDefault : LaunchMode.externalApplication,
      webOnlyWindowName: '_self',
    );
  }

  /// Sign Out
  Future<void> signOut() async {
    BuckAiService.instance.resetSessionState();
    if (SupabaseService.isInitialized) {
      await _client.auth.signOut();
    }
  }
}
