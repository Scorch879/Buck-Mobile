import 'package:flutter/foundation.dart';

/// Configuration for Buck AI services and Web app synchronization.
///
/// Values come from the `.env` configuration file via `--dart-define-from-file=.env`.
class BuckAiConstants {
  static const String _defaultAiUrl = 'https://buck-web-ai.vercel.app';

  static const String supabaseAiProxyUrl =
      'https://glnuzqmnmzuxgujmxigx.supabase.co/functions/v1/buck-ai-proxy';

  static const String _rawAiUrl = String.fromEnvironment(
    'BUCK_AI_URL',
    defaultValue: _defaultAiUrl,
  );

  static const String _rawSiteUrl = String.fromEnvironment(
    'NEXT_PUBLIC_SITE_URL',
    defaultValue: 'https://bucktbt-dev.vercel.app',
  );

  static String get _cleanRawAiUrl => _rawAiUrl.replaceAll(RegExp(r'/+$'), '');

  /// Normalized Buck AI backend URL (no trailing slash).
  ///
  /// Uses a custom `BUCK_AI_URL` when explicitly configured to something other
  /// than [_defaultAiUrl], and otherwise returns [supabaseAiProxyUrl] so every
  /// phone, tunnel domain, localhost port, and native build works without CORS
  /// rejection.
  static String get aiUrl => _selectAiUrl(_cleanRawAiUrl);

  @visibleForTesting
  static String resolveAiUrl(String rawAiUrl) =>
      _selectAiUrl(rawAiUrl.replaceAll(RegExp(r'/+$'), ''));

  static String _selectAiUrl(String cleanRawAiUrl) {
    if (cleanRawAiUrl.isNotEmpty && cleanRawAiUrl != _defaultAiUrl) {
      return cleanRawAiUrl;
    }
    return supabaseAiProxyUrl;
  }

  /// Deduplicated advisor endpoint URLs in failover priority order.
  static List<String> candidateEndpoints(String advisorPath) =>
      buildCandidateEndpoints(advisorPath);

  @visibleForTesting
  static List<String> buildCandidateEndpoints(
    String advisorPath, {
    String? primaryBaseUrl,
    bool isWeb = kIsWeb,
    Uri? baseUri,
  }) {
    final trimmed = advisorPath.trim().replaceFirst(RegExp(r'^/+'), '');
    final normalizedPath = trimmed.isEmpty ? '' : '/$trimmed';
    final effectivePrimary =
        (primaryBaseUrl ?? aiUrl).replaceAll(RegExp(r'/+$'), '');

    final candidates = <String>[];
    void addCandidate(String url) {
      if (!candidates.contains(url)) {
        candidates.add(url);
      }
    }

    addCandidate('$effectivePrimary$normalizedPath');

    final uri = baseUri ?? (isWeb ? Uri.base : null);
    if (isWeb &&
        uri != null &&
        uri.scheme.startsWith('http') &&
        !uri.host.endsWith('.vercel.app')) {
      final origin = uri.origin.replaceAll(RegExp(r'/+$'), '');
      if (origin.isNotEmpty) {
        addCandidate('$origin$normalizedPath');
      }
    }

    addCandidate('$_defaultAiUrl$normalizedPath');
    return List.unmodifiable(candidates);
  }

  /// Normalized Buck Web site URL (no trailing slash).
  static String get siteUrl => _rawSiteUrl.replaceAll(RegExp(r'/+$'), '');

  // Endpoint paths
  static String get advisorInsightEndpoint => '$aiUrl/advisor/insight';
  static String get advisorHistoryEndpoint => '$aiUrl/advisor/history';
  static String get advisorChatEndpoint => '$aiUrl/advisor/chat';
  static String get advisorCategorizeEndpoint => '$aiUrl/advisor/categorize';
  static String get advisorGoalTipEndpoint => '$aiUrl/advisor/goal-tip';
}
