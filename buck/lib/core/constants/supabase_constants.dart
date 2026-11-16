/// Supabase connection settings.
///
/// Values come from the shared `.env` via
/// `flutter run --dart-define-from-file=.env` (or `../.env`). Only the public
/// URL and publishable (anon) key are read — never reference server-only
/// secrets (service role key, management tokens) from app code.
class SupabaseConstants {
  static const String _rawUrl = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_URL',
    defaultValue: 'https://glnuzqmnmzuxgujmxigx.supabase.co',
  );

  /// Strips any trailing slashes from the configured URL.
  static String get url => _rawUrl.trim().replaceAll(RegExp(r'/+$'), '');

  static const String anonKey = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_K_mTR916JUVYmzrIbLEZng_l2bfOLcr',
  );

  /// Validates that required Supabase config is present and well-formed.
  static void validate() {
    final parsed = Uri.tryParse(url);
    if (url.isEmpty ||
        parsed == null ||
        parsed.scheme != 'https' ||
        parsed.host.isEmpty) {
      throw StateError(
        'Invalid NEXT_PUBLIC_SUPABASE_URL configuration. '
        'Pass a valid https:// URL via --dart-define-from-file=.env.',
      );
    }
    if (anonKey.trim().isEmpty) {
      throw StateError(
        'Missing NEXT_PUBLIC_SUPABASE_ANON_KEY configuration. '
        'Pass the publishable key via --dart-define-from-file=.env.',
      );
    }
  }
}
