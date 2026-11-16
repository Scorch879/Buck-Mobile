import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

/// Persists and evaluates whether the signed-in user should see the interactive
/// new-user Buck onboarding tutorial.
class OnboardingService {
  OnboardingService._({
    Future<SharedPreferences> Function()? prefsProvider,
    SupabaseClient? Function()? clientProvider,
  })  : _prefsProvider = prefsProvider ?? SharedPreferences.getInstance,
        _clientProvider = clientProvider ?? _defaultClientProvider;

  @visibleForTesting
  factory OnboardingService.forTest({
    required Future<SharedPreferences> Function() prefsProvider,
    SupabaseClient? Function()? clientProvider,
  }) {
    return OnboardingService._(
      prefsProvider: prefsProvider,
      clientProvider: clientProvider ?? () => null,
    );
  }

  static final OnboardingService instance = OnboardingService._();

  static const String _completedKeyPrefix = 'buck_onboarding_completed_';
  static const String _pendingSignUpKey = 'buck_onboarding_pending_signup';
  static const String _pendingSignUpEmailKey =
      'buck_onboarding_pending_signup_email';
  static const String metadataCompletedKey = 'buck_onboarding_completed';

  /// Window within which a newly created auth user is treated as brand new
  /// even on cross-device first sign-in or OAuth signup.
  static const Duration newAccountWindow = Duration(minutes: 15);

  final Future<SharedPreferences> Function() _prefsProvider;
  final SupabaseClient? Function() _clientProvider;

  static SupabaseClient? _defaultClientProvider() {
    try {
      return Supabase.instance.client;
    } catch (_) {
      return null;
    }
  }

  String _completedKeyFor(String userId) => '$_completedKeyPrefix$userId';

  /// Records that a user just completed sign-up on this device so their first
  /// authenticated landing in [MainShell] triggers onboarding even if email
  /// confirmation took longer than [newAccountWindow].
  Future<void> markPendingNewSignUp([String? email]) async {
    final prefs = await _prefsProvider();
    await prefs.setBool(_pendingSignUpKey, true);
    final normalizedEmail = email?.trim().toLowerCase();
    if (normalizedEmail != null && normalizedEmail.isNotEmpty) {
      await prefs.setString(_pendingSignUpEmailKey, normalizedEmail);
    }
  }

  /// Clears any pending local sign-up flag once consumed or dismissed.
  Future<void> clearPendingNewSignUp() async {
    final prefs = await _prefsProvider();
    await prefs.remove(_pendingSignUpKey);
    await prefs.remove(_pendingSignUpEmailKey);
  }

  /// Returns `true` ONLY when [user] is a newly signed up user who has not yet
  /// completed or skipped the onboarding tutorial.
  Future<bool> shouldShowOnboardingForUser(
    User? user, {
    DateTime? now,
  }) async {
    if (user == null) return false;

    final metadata = user.userMetadata;
    if (metadata != null && metadata[metadataCompletedKey] == true) {
      return false;
    }

    final prefs = await _prefsProvider();
    if (prefs.getBool(_completedKeyFor(user.id)) ?? false) {
      return false;
    }

    final hasPendingSignUp = prefs.getBool(_pendingSignUpKey) ?? false;
    if (hasPendingSignUp) {
      final pendingEmail =
          prefs.getString(_pendingSignUpEmailKey)?.trim().toLowerCase();
      final userEmail = user.email?.trim().toLowerCase();
      if (pendingEmail == null ||
          pendingEmail.isEmpty ||
          userEmail == null ||
          pendingEmail == userEmail) {
        return true;
      }
    }

    final createdAt = DateTime.tryParse(user.createdAt)?.toUtc();
    if (createdAt == null) return false;

    final referenceNow = (now ?? DateTime.now()).toUtc();
    final age = referenceNow.difference(createdAt);
    if (age.isNegative) {
      // Allow minor client/server clock skew on newly created accounts.
      return age.abs() <= const Duration(minutes: 5);
    }
    return age <= newAccountWindow;
  }

  /// Marks onboarding complete locally and syncs to Supabase user metadata so
  /// returning users do not see the tutorial again across sessions/devices.
  Future<void> completeOnboarding(User? user) async {
    final prefs = await _prefsProvider();
    await prefs.remove(_pendingSignUpKey);
    await prefs.remove(_pendingSignUpEmailKey);

    if (user == null) return;
    await prefs.setBool(_completedKeyFor(user.id), true);

    final client = _clientProvider();
    if (client != null) {
      try {
        await client.auth.updateUser(
          UserAttributes(data: {metadataCompletedKey: true}),
        );
      } catch (_) {
        // Local SharedPreferences flag prevents repeat prompts offline/test.
      }
    }
  }
}
