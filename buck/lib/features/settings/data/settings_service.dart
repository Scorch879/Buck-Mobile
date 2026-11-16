import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/constants/dev_config.dart';
import '../../../core/services/supabase_service.dart';

/// User profile and preference values rendered across Settings screens.
class BuckSettingsContext {
  final String displayName;
  final String email;
  final String connectionLabel;
  final String providerName;
  final bool isGoogleManaged;
  final bool isDevMode;

  const BuckSettingsContext({
    required this.displayName,
    required this.email,
    required this.connectionLabel,
    required this.providerName,
    required this.isGoogleManaged,
    this.isDevMode = false,
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
    } catch (_) {
      // Ignore storage failures in ephemeral test/web environments.
    }
  }

  Future<void> setTheme(String theme) async {
    selectedTheme.value = theme;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_themeKey, theme);
    } catch (_) {
      // Non-fatal preference persistence failure.
    }
  }

  Future<void> setCustomAvatar(Uint8List? bytes) async {
    customAvatarBytes.value = bytes;
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool(_avatarRemovedKey, bytes == null);
    } catch (_) {
      // Non-fatal preference persistence failure.
    }
  }

  Future<void> updateDisplayName(String newName) async {
    final trimmed = newName.trim();
    if (trimmed.isEmpty) {
      throw ArgumentError('Display name cannot be empty.');
    }
    if (DevConfig.mockAdminSessionActive.value || !SupabaseService.isInitialized) {
      return;
    }

    final client = SupabaseService.client;
    final user = client.auth.currentUser;
    if (user == null) {
      throw const AuthException('Not signed in');
    }

    await client.auth.updateUser(
      UserAttributes(data: {'full_name': trimmed, 'username': trimmed}),
    );

    await client
        .from('profiles')
        .upsert({'id': user.id, 'username': trimmed});
  }

  Future<void> submitFeedback({
    required String category,
    required String title,
    required String details,
  }) async {
    final cleanTitle = title.trim();
    final cleanDetails = details.trim();
    if (cleanTitle.isEmpty && cleanDetails.isEmpty) {
      throw ArgumentError('Please enter a title or details for your feedback.');
    }

    if (DevConfig.mockAdminSessionActive.value || !SupabaseService.isInitialized) {
      return;
    }

    final client = SupabaseService.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      await client.from('feedback').insert({
        'user_id': user.id,
        'category': category,
        'title': cleanTitle,
        'details': cleanDetails,
      });
    } catch (_) {
      // Optional backend feedback table may not be provisioned in every env.
    }
  }

  Future<void> requestAccountDeletion() async {
    if (DevConfig.mockAdminSessionActive.value || !SupabaseService.isInitialized) {
      return;
    }

    final client = SupabaseService.client;
    final user = client.auth.currentUser;
    if (user == null) return;

    try {
      await client.functions.invoke('request-account-deletion');
    } catch (_) {
      // Fall back gracefully if the deletion edge function is not deployed yet.
    }
  }
}
