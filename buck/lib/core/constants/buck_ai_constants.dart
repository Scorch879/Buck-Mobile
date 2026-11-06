/// Configuration for Buck AI services and Web app synchronization.
///
/// Values come from the `.env` configuration file via `--dart-define-from-file=.env`.
class BuckAiConstants {
  static const String _rawAiUrl = String.fromEnvironment(
    'BUCK_AI_URL',
    defaultValue: 'https://buck-web-ai.vercel.app',
  );

  static const String _rawSiteUrl = String.fromEnvironment(
    'NEXT_PUBLIC_SITE_URL',
    defaultValue: 'https://bucktbt-dev.vercel.app',
  );

  /// Normalized Buck AI backend URL (no trailing slash).
  static String get aiUrl => _rawAiUrl.replaceAll(RegExp(r'/+$'), '');

  /// Normalized Buck Web site URL (no trailing slash).
  static String get siteUrl => _rawSiteUrl.replaceAll(RegExp(r'/+$'), '');

  // Endpoint paths
  static String get advisorInsightEndpoint => '$aiUrl/advisor/insight';
  static String get advisorHistoryEndpoint => '$aiUrl/advisor/history';
  static String get advisorChatEndpoint => '$aiUrl/advisor/chat';
  static String get advisorCategorizeEndpoint => '$aiUrl/advisor/categorize';
  static String get advisorGoalTipEndpoint => '$aiUrl/advisor/goal-tip';
}
