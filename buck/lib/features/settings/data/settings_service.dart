import 'dart:convert' show utf8;

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';

/// User profile and preference values rendered across Settings screens.
class BuckSettingsContext {
  final String displayName;
  final String email;
  final String connectionLabel;
  final String providerName;
  final bool isGoogleManaged;

  const BuckSettingsContext({
    required this.displayName,
    required this.email,
    required this.connectionLabel,
    required this.providerName,
    required this.isGoogleManaged,
  });
}

/// Manages user profile updates, feedback submission, deletion requests,
/// and persisted local appearance / avatar preferences.
class SettingsService {
  SettingsService._();

  static final SettingsService instance = SettingsService._();

  static const _themeKey = 'buck_appearance_theme';
  static const _avatarRemovedKey = 'buck_avatar_removed';

  /// `'Dark'` (default) or `'Light'` selected in Appearance Settings.
  final ValueNotifier<String> selectedTheme = ValueNotifier<String>('Dark');

  /// Optional custom avatar image bytes selected in Profile & Account.
  final ValueNotifier<Uint8List?> customAvatarBytes = ValueNotifier<Uint8List?>(
    null,
  );

  bool _loaded = false;

  Future<void> ensureLoaded() async {
    if (_loaded) return;
    _loaded = true;
    try {
      final prefs = await SharedPreferences.getInstance();
      final savedTheme = prefs.getString(_themeKey);
      if (savedTheme == 'Light' || savedTheme == 'Dark') {
        selectedTheme.value = savedTheme!;
      }
      if (prefs.getBool(_avatarRemovedKey) == true) {
        customAvatarBytes.value = null;
      }
    } catch (e) {
      // Non-fatal in ephemeral widget test environments.
      debugPrint('SettingsService.ensureLoaded fallback: $e');
    }
  }

  Future<void> setTheme(String theme) async {
    selectedTheme.value = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, theme);
    } catch (e) {
      debugPrint('SettingsService.setTheme persistence error: $e');
    }
  }

  Future<void> setCustomAvatar(Uint8List? bytes) async {
    customAvatarBytes.value = bytes;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_avatarRemovedKey, bytes == null);
    } catch (e) {
      debugPrint('SettingsService.setCustomAvatar persistence error: $e');
    }
  }

  Future<void> updateDisplayName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }
    if (!SupabaseService.isInitialized) {
      throw StateError('Unable to update profile: Supabase is not connected.');
    }

    final client = SupabaseService.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Not signed in');
    }

    await client.auth.updateUser(
      UserAttributes(data: {'full_name': trimmed, 'username': trimmed}),
    );

    await client.from('profiles').upsert({'id': user.id, 'username': trimmed});
  }

  Future<void> submitFeedback({
    required String category,
    required String title,
    required String details,
  }) async {
    final cleanTitle = title.trim();
    final cleanDetails = details.trim();
    if (cleanTitle.isEmpty || cleanDetails.isEmpty) {
      throw ArgumentError('Please enter both a summary title and details.');
    }
    if (!SupabaseService.isInitialized) {
      throw StateError('Unable to submit feedback right now. Not connected.');
    }

    final client = SupabaseService.client;
    final user = client.auth.currentUser;
    final email = user?.email?.trim().toLowerCase() ?? '';
    if (user == null || email.isEmpty) {
      throw const AuthException('Not signed in');
    }

    await client.from('feedback').insert({
      'user_email': sha256Email(email),
      'category': category,
      'title': cleanTitle,
      'details': cleanDetails,
    });
  }

  /// Returns whether the currently signed-in account uses a password that must
  /// be re-entered before requesting deletion.
  Future<bool> accountRequiresPassword() async {
    if (!SupabaseService.isInitialized) return true;
    final client = SupabaseService.client;
    final user = client.auth.currentUser;
    if (user == null) return true;

    try {
      final res = await client.rpc(
        'get_auth_user_capabilities',
        params: {'p_user_id': user.id},
      );
      if (res is List && res.isNotEmpty) {
        final row = res.first;
        if (row is Map && row['has_password'] is bool) {
          return row['has_password'] as bool;
        }
      } else if (res is Map && res['has_password'] is bool) {
        return res['has_password'] as bool;
      }
    } catch (_) {
      // Fall back to identity metadata inspection when capability RPC fails.
    }

    final identities = user.identities ?? const [];
    if (identities.isNotEmpty) {
      return identities.any((i) => i.provider.toLowerCase() == 'email');
    }
    final provider =
        user.appMetadata['provider']?.toString().toLowerCase() ?? 'email';
    return provider != 'google';
  }

  Future<void> requestAccountDeletion({
    String confirmation = 'DELETE',
    String? password,
  }) async {
    if (confirmation.trim() != 'DELETE') {
      throw ArgumentError('Type DELETE to confirm account deletion.');
    }
    if (!SupabaseService.isInitialized) {
      throw StateError(
        'Unable to reach account deletion service right now. Please try again.',
      );
    }

    final client = SupabaseService.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Not signed in');
    }

    final requiresPassword = await accountRequiresPassword();
    if (requiresPassword && (password == null || password.isEmpty)) {
      throw const AuthException(
        'Please enter your password to confirm account deletion.',
      );
    }

    try {
      await client.rpc(
        'request_account_deletion',
        params: {
          'p_confirmation': confirmation.trim(),
          if (password != null && password.isNotEmpty) 'p_password': password,
        },
      );
    } on PostgrestException catch (e) {
      final msg = e.message.trim();
      if (msg.isNotEmpty) {
        throw AuthException(msg);
      }
      throw StateError('Account deletion request failed.');
    }
  }

  /// Computes lowercase SHA-256 hex matching Postgres `private.sha256_email`.
  @visibleForTesting
  static String sha256Email(String email) {
    final normalized = email.trim().toLowerCase();
    return _sha256Hex(Uint8List.fromList(utf8.encode(normalized)));
  }

  static String _sha256Hex(Uint8List input) {
    const k = <int>[
      0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1,
      0x923f82a4, 0xab1c5ed5, 0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3,
      0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174, 0xe49b69c1, 0xefbe4786,
      0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
      0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147,
      0x06ca6351, 0x14292967, 0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13,
      0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85, 0xa2bfe8a1, 0xa81a664b,
      0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
      0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a,
      0x5b9cca4f, 0x682e6ff3, 0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208,
      0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
    ];

    int rotr(int x, int n) => ((x & 0xffffffff) >>> n) | ((x << (32 - n)) & 0xffffffff);

    final bitLen = input.length * 8;
    final padLen = ((input.length + 8) ~/ 64 + 1) * 64;
    final padded = Uint8List(padLen)
      ..setAll(0, input)
      ..[input.length] = 0x80;
    final bd = ByteData.sublistView(padded);
    bd.setUint32(padLen - 4, bitLen & 0xffffffff, Endian.big);
    bd.setUint32(padLen - 8, (bitLen ~/ 0x100000000) & 0xffffffff, Endian.big);

    var h0 = 0x6a09e667;
    var h1 = 0xbb67ae85;
    var h2 = 0x3c6ef372;
    var h3 = 0xa54ff53a;
    var h4 = 0x510e527f;
    var h5 = 0x9b05688c;
    var h6 = 0x1f83d9ab;
    var h7 = 0x5be0cd19;

    final w = List<int>.filled(64, 0);
    for (var offset = 0; offset < padLen; offset += 64) {
      for (var i = 0; i < 16; i++) {
        w[i] = bd.getUint32(offset + i * 4, Endian.big);
      }
      for (var i = 16; i < 64; i++) {
        final s0 = rotr(w[i - 15], 7) ^ rotr(w[i - 15], 18) ^ (w[i - 15] >>> 3);
        final s1 = rotr(w[i - 2], 17) ^ rotr(w[i - 2], 19) ^ (w[i - 2] >>> 10);
        w[i] = (w[i - 16] + s0 + w[i - 7] + s1) & 0xffffffff;
      }

      var a = h0, b = h1, c = h2, d = h3, e = h4, f = h5, g = h6, h = h7;
      for (var i = 0; i < 64; i++) {
        final s1 = rotr(e, 6) ^ rotr(e, 11) ^ rotr(e, 25);
        final ch = (e & f) ^ ((~e & 0xffffffff) & g);
        final temp1 = (h + s1 + ch + k[i] + w[i]) & 0xffffffff;
        final s0 = rotr(a, 2) ^ rotr(a, 13) ^ rotr(a, 22);
        final maj = (a & b) ^ (a & c) ^ (b & c);
        final temp2 = (s0 + maj) & 0xffffffff;

        h = g;
        g = f;
        f = e;
        e = (d + temp1) & 0xffffffff;
        d = c;
        c = b;
        b = a;
        a = (temp1 + temp2) & 0xffffffff;
      }

      h0 = (h0 + a) & 0xffffffff;
      h1 = (h1 + b) & 0xffffffff;
      h2 = (h2 + c) & 0xffffffff;
      h3 = (h3 + d) & 0xffffffff;
      h4 = (h4 + e) & 0xffffffff;
      h5 = (h5 + f) & 0xffffffff;
      h6 = (h6 + g) & 0xffffffff;
      h7 = (h7 + h) & 0xffffffff;
    }

    return [h0, h1, h2, h3, h4, h5, h6, h7]
        .map((v) => v.toRadixString(16).padLeft(8, '0'))
        .join();
  }
}
