/// Supabase connection settings.
///
/// Values come from the shared `.env` via
/// `flutter run --dart-define-from-file=../.env`. Only the public URL and
/// publishable (anon) key are read — never reference server-only secrets
/// (service role key, management tokens) from app code.
class SupabaseConstants {
  static const String _rawUrl = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_URL',
    defaultValue: 'https://glnuzqmnmzuxgujmxigx.supabase.co',
  );

  /// Strips any trailing slashes from the configured URL.
  static String get url => _rawUrl.replaceAll(RegExp(r'/+$'), '');

  static const String anonKey = String.fromEnvironment(
    'NEXT_PUBLIC_SUPABASE_ANON_KEY',
    defaultValue: 'sb_publishable_K_mTR916JUVYmzrIbLEZng_l2bfOLcr',
  );
}
