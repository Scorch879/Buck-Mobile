import 'package:flutter/foundation.dart';

/// Development configuration for local debugging and testing.
///
/// Values can be overridden via `.env` with `--dart-define-from-file=.env`.
class DevConfig {
  /// Whether Dev Mode features (e.g. quick admin login) are enabled.
  static const bool isDevMode = bool.fromEnvironment(
    'DEV_MODE',
    defaultValue: kDebugMode,
  );

  /// Default admin email for dev testing.
  static const String adminEmail = String.fromEnvironment(
    'DEV_ADMIN_EMAIL',
    defaultValue: 'admin@buck.dev',
  );

  /// Default admin password for dev testing.
  static const String adminPassword = String.fromEnvironment(
    'DEV_ADMIN_PASSWORD',
    defaultValue: 'AdminPassword123!',
  );

  /// Default admin display name.
  static const String adminName = String.fromEnvironment(
    'DEV_ADMIN_NAME',
    defaultValue: 'Admin User',
  );

  /// Whether to automatically pre-fill admin credentials in debug mode.
  static const bool autoFillAdmin = bool.fromEnvironment(
    'DEV_AUTO_FILL_ADMIN',
    defaultValue: false,
  );

  /// Active mock admin session state for instant dev testing without email confirmation.
  static final ValueNotifier<bool> mockAdminSessionActive = ValueNotifier<bool>(false);
}
