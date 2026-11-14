import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_constants.dart';

class SupabaseService {
  static bool get isInitialized {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  static Future<void> initialize() async {
    await Supabase.initialize(
      url: SupabaseConstants.url,
      // ignore: deprecated_member_use
      anonKey: SupabaseConstants.anonKey,
      authOptions: const FlutterAuthClientOptions(
        authFlowType: AuthFlowType.pkce,
      ),
    );

    if (kIsWeb &&
        Supabase.instance.client.auth.currentSession == null &&
        Uri.base.queryParameters.containsKey('code')) {
      try {
        await Supabase.instance.client.auth.getSessionFromUrl(Uri.base);
      } catch (_) {}
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
