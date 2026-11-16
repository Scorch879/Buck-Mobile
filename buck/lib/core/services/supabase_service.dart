import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:supabase_flutter/supabase_flutter.dart';
import '../constants/supabase_constants.dart';

class SupabaseService {
  static final ValueNotifier<String?> initErrorNotifier =
      ValueNotifier<String?>(null);

  static String? get initError => initErrorNotifier.value;

  static bool get isInitialized {
    try {
      return Supabase.instance.isInitialized;
    } catch (_) {
      return false;
    }
  }

  static Future<void> initialize() async {
    initErrorNotifier.value = null;
    try {
      SupabaseConstants.validate();
      if (!isInitialized) {
        await Supabase.initialize(
          url: SupabaseConstants.url,
          // ignore: deprecated_member_use
          anonKey: SupabaseConstants.anonKey,
          authOptions: const FlutterAuthClientOptions(
            authFlowType: AuthFlowType.pkce,
          ),
        );
      }
    } catch (e) {
      initErrorNotifier.value = e.toString();
      rethrow;
    }
  }

  static SupabaseClient get client => Supabase.instance.client;
}
