import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/buck_ai_constants.dart';
import '../../../../core/constants/dev_config.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/ai_chat_message.dart';
import '../models/ai_insight_response.dart';

/// User-safe exception thrown by [BuckAiService].
class BuckAiException implements Exception {
  final String message;
  final int? statusCode;

  const BuckAiException(this.message, {this.statusCode});

  factory BuckAiException.fromStatus(int statusCode) {
    if (statusCode == 401 || statusCode == 403) {
      return BuckAiException(
        'Please sign in again to use Buck AI.',
        statusCode: statusCode,
      );
    }
    if (statusCode == 429) {
      return BuckAiException(
        'Buck AI is taking a quick breather (rate limit reached). Please try again in a moment.',
        statusCode: statusCode,
      );
    }
    return BuckAiException(
      'Buck AI is temporarily unavailable. Please try again shortly.',
      statusCode: statusCode,
    );
  }

  @override
  String toString() => message;
}

/// Service interfacing with the Buck AI FastAPI service.
///
/// Sends user queries with the user's Supabase JWT access token for
/// authenticated, RLS-bounded AI analytics and financial advisory.
class BuckAiService {
  static const Duration _requestTimeout = Duration(seconds: 20);
  static const Duration regenerateCooldown = Duration(seconds: 60);

  /// Shared singleton instance so widgets do not leak [http.Client] instances.
  static final BuckAiService instance = BuckAiService._internal(http.Client(), ownsClient: false);

  final http.Client _client;
  final bool _ownsClient;

  /// Session-scoped chat message history preserved across sheet opens.
  final List<AiChatMessage> chatHistory = [];

  /// Timestamp of the last manual insight regeneration for client-side rate limiting.
  DateTime? lastRegeneratedAt;

  BuckAiService._internal(this._client, {required bool ownsClient})
      : _ownsClient = ownsClient;

  /// Returns the shared [instance] unless a custom [client] is injected (e.g. in tests).
  factory BuckAiService({http.Client? client}) {
    if (client == null) return instance;
    return BuckAiService._internal(client, ownsClient: true);
  }

  bool get _isDevMockSession => DevConfig.mockAdminSessionActive.value;

  /// Resolves a valid bearer token, refreshing the Supabase session if expired.
  Future<String?> _resolveToken({String? overrideToken}) async {
    if (overrideToken != null && overrideToken.isNotEmpty) {
      return overrideToken;
    }
    if (!SupabaseService.isInitialized) return null;
    try {
      var session = SupabaseService.client.auth.currentSession;
      if (session == null) return null;
      if (session.isExpired) {
        final refreshed = await SupabaseService.client.auth.refreshSession();
        session = refreshed.session ?? SupabaseService.client.auth.currentSession;
      }
      return session?.accessToken;
    } catch (e) {
      debugPrint('Token refresh warning: $e');
      return SupabaseService.client.auth.currentSession?.accessToken;
    }
  }

  Map<String, String> _buildHeaders(String? token) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  /// Remaining cooldown seconds before manual insight regeneration is allowed.
  int get remainingCooldownSeconds {
    final last = lastRegeneratedAt;
    if (last == null) return 0;
    final elapsed = DateTime.now().difference(last);
    final remaining = regenerateCooldown - elapsed;
    return remaining.isNegative ? 0 : remaining.inSeconds;
  }

  /// Maps any AI-returned category or description keyword to the canonical
  /// mobile expense category list.
  static String mapToMobileCategory(String rawCategory, {String fallbackDescription = ''}) {
    const mobileCategories = [
      'Food',
      'Transportation',
      'Shopping',
      'Bills & Utilities',
      'Entertainment',
      'Health & Wellness',
      'Education',
      'Other',
    ];

    final normalized = rawCategory.trim();
    for (final exact in mobileCategories) {
      if (exact.toLowerCase() == normalized.toLowerCase()) {
        return exact;
      }
    }

    final combined = '${normalized.toLowerCase()} ${fallbackDescription.toLowerCase()}';

    bool matchesAny(List<String> keywords) =>
        keywords.any((k) => combined.contains(k));

    if (matchesAny([
      'food', 'dining', 'restaurant', 'coffee', 'cafe', 'starbucks',
      'jollibee', 'mcdonald', 'grocery', 'groceries', 'meal', 'snack',
      'lunch', 'dinner', 'breakfast', 'bakery', 'drink',
    ])) {
      return 'Food';
    }
    if (matchesAny([
      'transport', 'gas', 'fuel', 'shell', 'petron', 'caltex', 'uber',
      'grab', 'angkas', 'joyride', 'taxi', 'bus', 'train', 'mrt', 'lrt',
      'jeep', 'fare', 'toll', 'parking', 'commute', 'flight', 'airline',
    ])) {
      return 'Transportation';
    }
    if (matchesAny([
      'bill', 'utility', 'utilities', 'electric', 'meralco', 'water',
      'maynilad', 'manila water', 'internet', 'wifi', 'globe', 'smart',
      'pldt', 'converge', 'rent', 'phone', 'postpaid', 'insurance',
    ])) {
      return 'Bills & Utilities';
    }
    if (matchesAny([
      'health', 'medical', 'medicine', 'pharmacy', 'mercury drug', 'watsons',
      'doctor', 'hospital', 'clinic', 'dental', 'wellness', 'gym', 'fitness',
    ])) {
      return 'Health & Wellness';
    }
    if (matchesAny([
      'entertain', 'movie', 'cinema', 'netflix', 'spotify', 'youtube',
      'game', 'gaming', 'steam', 'concert', 'hobby', 'leisure', 'subscription',
    ])) {
      return 'Entertainment';
    }
    if (matchesAny([
      'educat', 'school', 'tuition', 'book', 'course', 'udemy', 'coursera',
      'seminar', 'training', 'stationery', 'supplies',
    ])) {
      return 'Education';
    }
    if (matchesAny([
      'shop', 'clothes', 'apparel', 'shoes', 'mall', 'lazada', 'shopee',
      'amazon', 'uniqlo', 'zara', 'gadget', 'electronics', 'gift', 'home',
    ])) {
      return 'Shopping';
    }

    return 'Other';
  }

  AiInsightResponse _devMockInsight({bool refreshed = false}) {
    final now = DateTime.now();
    return AiInsightResponse(
      id: 'dev-insight-001',
      title: 'Steady Weekly Pacing',
      suggestion:
          'Keep daily spending under ₱1,200.00 to stay on track for your Emergency Fund goal.',
      advice:
          'In Dev Mode, your simulated monthly spending is ₱14,850.00 against ₱45,000.00 in tracked income. '
          'Your current savings rate is 67%, which comfortably supports your Moderate saving attitude. '
          'Setting aside ₱2,500.00 per week will keep your Emergency Fund ahead of schedule.',
      financialHealthScore: 84,
      priority: 'low',
      focus: 'savings',
      walletAdvice:
          'Use your Main Wallet for everyday expenses while keeping your Savings wallet untouched as your goal buffer.',
      period: AiPeriod(
        asOf: '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}',
        monthStart: '${now.year}-${now.month.toString().padLeft(2, '0')}-01',
      ),
      generatedWith: 'dev-preview',
      createdAt: now.toIso8601String(),
      cached: !refreshed,
      stale: false,
    );
  }

  /// Fetches the latest financial strategy insight.
  ///
  /// Set [refresh] to true to force Gemini regeneration (subject to rate limit cooldowns).
  Future<AiInsightResponse> getInsight({bool refresh = false, String? token}) async {
    final effectiveToken = await _resolveToken(overrideToken: token);
    if (effectiveToken == null && _isDevMockSession) {
      if (refresh) lastRegeneratedAt = DateTime.now();
      return _devMockInsight(refreshed: refresh);
    }

    final uri = Uri.parse(
      refresh
          ? '${BuckAiConstants.advisorInsightEndpoint}?refresh=true'
          : BuckAiConstants.advisorInsightEndpoint,
    );

    try {
      final response = await _client
          .get(uri, headers: _buildHeaders(effectiveToken))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        if (refresh) lastRegeneratedAt = DateTime.now();
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return AiInsightResponse.fromJson(data);
      }

      throw BuckAiException.fromStatus(response.statusCode);
    } on BuckAiException {
      rethrow;
    } on TimeoutException {
      throw const BuckAiException(
        'Buck AI request timed out. Please check your connection and try again.',
      );
    } catch (e) {
      debugPrint('BuckAiService.getInsight error: $e');
      throw const BuckAiException(
        'Unable to reach Buck AI right now. Please try again shortly.',
      );
    }
  }

  /// Fetches saved advisory history.
  Future<AiInsightResponse?> getHistory({String? token}) async {
    final effectiveToken = await _resolveToken(overrideToken: token);
    if (effectiveToken == null && _isDevMockSession) {
      return _devMockInsight();
    }

    final uri = Uri.parse(BuckAiConstants.advisorHistoryEndpoint);
    try {
      final response = await _client
          .get(uri, headers: _buildHeaders(effectiveToken))
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return AiInsightResponse.fromJson(data);
      }
    } catch (e) {
      debugPrint('BuckAiService.getHistory warning: $e');
    }
    return null;
  }

  /// Auto-categorizes an expense or list of expenses using Gemini NLP embeddings,
  /// normalizing results to mobile category names.
  Future<List<String>> categorize({
    required List<String> descriptions,
    String kind = 'expense',
    String? token,
  }) async {
    if (descriptions.isEmpty) return const [];

    final effectiveToken = await _resolveToken(overrideToken: token);
    if (effectiveToken == null && _isDevMockSession) {
      return descriptions
          .map((d) => mapToMobileCategory('', fallbackDescription: d))
          .toList();
    }

    final uri = Uri.parse(BuckAiConstants.advisorCategorizeEndpoint);
    try {
      final response = await _client
          .post(
            uri,
            headers: _buildHeaders(effectiveToken),
            body: jsonEncode({
              'kind': kind,
              'descriptions': descriptions,
            }),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        final categories = data['categories'];
        if (categories is List) {
          return [
            for (var i = 0; i < categories.length; i++)
              mapToMobileCategory(
                categories[i].toString(),
                fallbackDescription: i < descriptions.length ? descriptions[i] : '',
              ),
          ];
        }
      }
    } catch (e) {
      debugPrint('BuckAiService.categorize fallback: $e');
    }

    // Offline / fallback local keyword categorization
    return descriptions
        .map((d) => mapToMobileCategory('', fallbackDescription: d))
        .toList();
  }

  /// Generates a customized AI saving or execution tip for a financial goal.
  Future<String?> getGoalTip({
    String? goalId,
    String? goalName,
    double? targetAmount,
    String? token,
  }) async {
    final effectiveToken = await _resolveToken(overrideToken: token);
    if (effectiveToken == null && _isDevMockSession) {
      final name = (goalName != null && goalName.isNotEmpty) ? goalName : 'your goal';
      final amount = (targetAmount != null && targetAmount > 0)
          ? '₱${(targetAmount / 12).toStringAsFixed(2)}'
          : 'a fixed amount';
      return 'To reach $name steadily, automate a monthly transfer of $amount right after payday and keep it in a dedicated savings wallet.';
    }

    final uri = Uri.parse(BuckAiConstants.advisorGoalTipEndpoint);
    final body = <String, dynamic>{};
    if (goalId != null && goalId.isNotEmpty) body['goalId'] = goalId;
    if (goalName != null && goalName.isNotEmpty) body['goalName'] = goalName;
    if (targetAmount != null && targetAmount > 0) body['targetAmount'] = targetAmount;

    try {
      final response = await _client
          .post(
            uri,
            headers: _buildHeaders(effectiveToken),
            body: jsonEncode(body),
          )
          .timeout(_requestTimeout);

      if (response.statusCode == 200) {
        final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
        return data['tip'] as String?;
      }
      throw BuckAiException.fromStatus(response.statusCode);
    } on BuckAiException {
      rethrow;
    } on TimeoutException {
      throw const BuckAiException(
        'Buck AI request timed out. Please try again.',
      );
    } catch (e) {
      debugPrint('BuckAiService.getGoalTip error: $e');
      throw const BuckAiException('Unable to load AI goal tip right now.');
    }
  }

  /// Streams real-time financial advisor chat responses token-by-token.
  Stream<String> streamChat(String question, {String? token}) async* {
    final effectiveToken = await _resolveToken(overrideToken: token);
    if (effectiveToken == null && _isDevMockSession) {
      const mockReply =
          'Based on your **Dev Mode** snapshot, your daily spending cap is **₱1,200.00** per day.\n\n'
          '- Current monthly spend: **₱14,850.00**\n'
          '- Recommended weekly saving: **₱2,500.00** toward your Emergency Fund';
      for (final word in mockReply.split(' ')) {
        await Future<void>.delayed(const Duration(milliseconds: 15));
        yield '$word ';
      }
      return;
    }

    final uri = Uri.parse(BuckAiConstants.advisorChatEndpoint);
    final request = http.Request('POST', uri);
    request.headers.addAll(_buildHeaders(effectiveToken));
    request.body = jsonEncode({'question': question});

    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client.send(request).timeout(_requestTimeout);
    } on TimeoutException {
      throw const BuckAiException(
        'Buck AI chat connection timed out. Please try again.',
      );
    } catch (e) {
      debugPrint('BuckAiService.streamChat send error: $e');
      throw const BuckAiException(
        'Unable to connect to Buck AI chat right now.',
      );
    }

    if (streamedResponse.statusCode != 200) {
      throw BuckAiException.fromStatus(streamedResponse.statusCode);
    }

    final lineStream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;

      final jsonPayload = trimmed.substring(5).trim();
      if (jsonPayload.isEmpty) continue;

      Map<String, dynamic>? parsed;
      try {
        final decoded = jsonDecode(jsonPayload);
        if (decoded is Map<String, dynamic>) {
          parsed = decoded;
        }
      } catch (e) {
        debugPrint('SSE JSON parse warning: $e');
        continue;
      }

      if (parsed == null) continue;

      final type = parsed['type'] as String?;
      if (type == 'delta') {
        final text = parsed['text'] as String?;
        if (text != null && text.isNotEmpty) {
          yield text;
        }
      } else if (type == 'error') {
        final errorMsg = (parsed['message'] ?? parsed['error']) as String? ??
            'Buck AI encountered an error while answering.';
        throw BuckAiException(errorMsg);
      } else if (type == 'done') {
        break;
      }
    }
  }

  /// Clears the in-memory advisor chat session messages.
  void clearChatHistory() {
    chatHistory.clear();
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
