import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/buck_ai_constants.dart';
import '../../../../core/constants/dev_config.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../finance/data/dev_finance_source.dart';
import '../models/ai_chat_message.dart';
import '../models/ai_insight_response.dart';

/// Canonical expense categories supported across the mobile app.
const List<String> mobileExpenseCategories = [
  'Food',
  'Transportation',
  'Shopping',
  'Bills & Utilities',
  'Entertainment',
  'Health & Wellness',
  'Education',
  'Other',
];

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
  static const Duration _defaultRequestTimeout = Duration(seconds: 20);
  static const Duration regenerateCooldown = Duration(seconds: 60);

  /// Shared singleton instance so widgets do not leak [http.Client] instances.
  static final BuckAiService instance = BuckAiService._internal(
    http.Client(),
    ownsClient: false,
    requestTimeout: _defaultRequestTimeout,
  );

  final http.Client _client;
  final bool _ownsClient;
  final Duration _requestTimeout;

  /// Session-scoped chat message history preserved across sheet opens.
  final List<AiChatMessage> chatHistory = [];

  /// Timestamp of the last manual insight regeneration for client-side rate limiting.
  DateTime? lastRegeneratedAt;

  BuckAiService._internal(
    this._client, {
    required bool ownsClient,
    required Duration requestTimeout,
  })  : _ownsClient = ownsClient,
        _requestTimeout = requestTimeout;

  /// Creates an isolated [BuckAiService] instance.
  ///
  /// Prefer [BuckAiService.instance] in production widgets to share session state
  /// and avoid creating extra [http.Client] instances.
  BuckAiService({http.Client? client, Duration? requestTimeout})
      : _client = client ?? http.Client(),
        _ownsClient = true,
        _requestTimeout = requestTimeout ?? _defaultRequestTimeout;

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
  /// mobile expense category list using whole-word matching.
  static String mapToMobileCategory(String rawCategory, {String fallbackDescription = ''}) {
    final normalized = rawCategory.trim();
    for (final exact in mobileExpenseCategories) {
      if (exact.toLowerCase() == normalized.toLowerCase()) {
        return exact;
      }
    }

    final combined = '${normalized.toLowerCase()} ${fallbackDescription.toLowerCase()}';

    bool matchesAny(List<String> keywords) {
      final pattern = r'\b(?:' + keywords.map(RegExp.escape).join('|') + r')\b';
      return RegExp(pattern, caseSensitive: false).hasMatch(combined);
    }

    if (matchesAny([
      'food', 'foods', 'dining', 'dine', 'restaurant', 'restaurants', 'coffee',
      'cafe', 'cafes', 'starbucks', 'jollibee', 'mcdonald', 'mcdonalds',
      'grocery', 'groceries', 'supermarket', 'meal', 'meals', 'snack', 'snacks',
      'lunch', 'dinner', 'breakfast', 'bakery', 'drink', 'drinks', 'bistro',
    ])) {
      return 'Food';
    }
    if (matchesAny([
      'transport', 'transportation', 'gas', 'gasoline', 'fuel', 'shell',
      'petron', 'caltex', 'uber', 'grab', 'angkas', 'joyride', 'taxi', 'cab',
      'bus', 'train', 'mrt', 'lrt', 'jeep', 'jeepney', 'fare', 'toll',
      'parking', 'commute', 'flight', 'flights', 'airline', 'airlines',
    ])) {
      return 'Transportation';
    }
    if (matchesAny([
      'bill', 'bills', 'utility', 'utilities', 'electric', 'electricity',
      'meralco', 'water', 'maynilad', 'manila water', 'internet', 'wifi',
      'fiber', 'globe', 'smart', 'pldt', 'converge', 'rent', 'rental', 'phone',
      'mobile', 'postpaid', 'insurance',
    ])) {
      return 'Bills & Utilities';
    }
    if (matchesAny([
      'health', 'healthcare', 'medical', 'medicine', 'medicines', 'pharmacy',
      'mercury drug', 'watsons', 'doctor', 'hospital', 'clinic', 'dental',
      'dentist', 'wellness', 'gym', 'fitness', 'workout',
    ])) {
      return 'Health & Wellness';
    }
    if (matchesAny([
      'entertainment', 'entertain', 'movie', 'movies', 'cinema', 'netflix',
      'spotify', 'youtube', 'game', 'games', 'gaming', 'steam', 'concert',
      'hobby', 'hobbies', 'leisure', 'subscription', 'subscriptions',
    ])) {
      return 'Entertainment';
    }
    if (matchesAny([
      'education', 'educational', 'school', 'tuition', 'book', 'books',
      'textbook', 'course', 'courses', 'udemy', 'coursera', 'seminar',
      'training', 'workshop', 'stationery', 'supplies',
    ])) {
      return 'Education';
    }
    if (matchesAny([
      'shopping', 'shop', 'clothes', 'clothing', 'apparel', 'shoes', 'mall',
      'lazada', 'shopee', 'amazon', 'uniqlo', 'zara', 'gadget', 'gadgets',
      'electronics', 'monitor', 'gift', 'gifts', 'home',
    ])) {
      return 'Shopping';
    }

    return 'Other';
  }

  /// Fetches the latest financial strategy insight.
  ///
  /// Set [refresh] to true to force Gemini regeneration (subject to rate limit cooldowns).
  Future<AiInsightResponse> getInsight({bool refresh = false, String? token}) async {
    final effectiveToken = await _resolveToken(overrideToken: token);
    if (effectiveToken == null && _isDevMockSession) {
      if (refresh) lastRegeneratedAt = DateTime.now();
      return DevFinanceSource.mockInsight(refreshed: refresh);
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
      return DevFinanceSource.mockInsight();
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
      return DevFinanceSource.mockGoalTip(
        goalName: goalName,
        targetAmount: targetAmount,
      );
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

  /// Builds a contextual question payload incorporating up to the last 6 completed turns.
  String _buildContextualQuestion(String question, List<AiChatMessage>? historySource) {
    final source = historySource ?? chatHistory;
    final completed = source
        .where((m) => m.id != 'initial' && !m.isStreaming && m.text.trim().isNotEmpty)
        .toList();
    if (completed.isNotEmpty &&
        completed.last.isUser &&
        completed.last.text.trim() == question.trim()) {
      completed.removeLast();
    }
    if (completed.isEmpty) return question;

    final recent = completed.length > 6
        ? completed.sublist(completed.length - 6)
        : completed;
    final contextLines = recent
        .map((m) => '${m.isUser ? "User" : "Advisor"}: ${m.text.trim()}')
        .join('\n');
    return 'Previous conversation:\n$contextLines\n\nCurrent question: $question';
  }

  /// Streams real-time financial advisor chat responses token-by-token.
  Stream<String> streamChat(
    String question, {
    String? token,
    List<AiChatMessage>? history,
  }) {
    late final StreamController<String> controller;
    StreamSubscription<String>? lineSub;
    var isCancelled = false;

    controller = StreamController<String>(
      onCancel: () async {
        isCancelled = true;
        await lineSub?.cancel();
      },
      onListen: () async {
        try {
          final effectiveToken = await _resolveToken(overrideToken: token);
          if (isCancelled) return;

          if (effectiveToken == null && _isDevMockSession) {
            for (final word in DevFinanceSource.mockChatReply.split(' ')) {
              if (isCancelled) return;
              await Future<void>.delayed(const Duration(milliseconds: 15));
              if (isCancelled) return;
              controller.add('$word ');
            }
            if (!isCancelled && !controller.isClosed) {
              await controller.close();
            }
            return;
          }

          final uri = Uri.parse(BuckAiConstants.advisorChatEndpoint);
          final request = http.Request('POST', uri);
          request.headers.addAll(_buildHeaders(effectiveToken));
          request.body = jsonEncode({
            'question': _buildContextualQuestion(question, history),
          });

          final http.StreamedResponse streamedResponse;
          try {
            streamedResponse = await _client.send(request).timeout(_requestTimeout);
          } on TimeoutException {
            if (!isCancelled && !controller.isClosed) {
              controller.addError(const BuckAiException(
                'Buck AI chat connection timed out. Please try again.',
              ));
              await controller.close();
            }
            return;
          } catch (e) {
            debugPrint('BuckAiService.streamChat send error: $e');
            if (!isCancelled && !controller.isClosed) {
              controller.addError(const BuckAiException(
                'Unable to connect to Buck AI chat right now.',
              ));
              await controller.close();
            }
            return;
          }

          if (isCancelled) return;

          if (streamedResponse.statusCode != 200) {
            if (!controller.isClosed) {
              controller.addError(
                BuckAiException.fromStatus(streamedResponse.statusCode),
              );
              await controller.close();
            }
            return;
          }

          final lineStream = streamedResponse.stream
              .timeout(_requestTimeout)
              .transform(utf8.decoder)
              .transform(const LineSplitter());

          lineSub = lineStream.listen(
            (line) {
              if (isCancelled || controller.isClosed) return;
              final trimmed = line.trim();
              if (!trimmed.startsWith('data:')) return;

              final jsonPayload = trimmed.substring(5).trim();
              if (jsonPayload.isEmpty) return;

              Map<String, dynamic>? parsed;
              try {
                final decoded = jsonDecode(jsonPayload);
                if (decoded is Map<String, dynamic>) {
                  parsed = decoded;
                }
              } catch (e) {
                debugPrint('SSE JSON parse warning: $e');
                return;
              }

              if (parsed == null) return;

              final type = parsed['type'] as String?;
              if (type == 'delta') {
                final text = parsed['text'] as String?;
                if (text != null && text.isNotEmpty) {
                  controller.add(text);
                }
              } else if (type == 'error') {
                final errorMsg = (parsed['message'] ?? parsed['error']) as String? ??
                    'Buck AI encountered an error while answering.';
                controller.addError(BuckAiException(errorMsg));
                lineSub?.cancel();
                controller.close();
              } else if (type == 'done') {
                lineSub?.cancel();
                controller.close();
              }
            },
            onError: (Object e) {
              if (isCancelled || controller.isClosed) return;
              if (e is BuckAiException) {
                controller.addError(e);
              } else if (e is TimeoutException) {
                controller.addError(const BuckAiException(
                  'Buck AI response timed out. Please try again.',
                ));
              } else {
                debugPrint('BuckAiService.streamChat stream error: $e');
                controller.addError(const BuckAiException(
                  'Connection interrupted while receiving Buck AI response.',
                ));
              }
              controller.close();
            },
            onDone: () {
              if (!isCancelled && !controller.isClosed) {
                controller.close();
              }
            },
            cancelOnError: true,
          );
        } catch (e) {
          if (!isCancelled && !controller.isClosed) {
            controller.addError(
              e is BuckAiException
                  ? e
                  : const BuckAiException(
                      'Unable to connect to Buck AI chat right now.',
                    ),
            );
            await controller.close();
          }
        }
      },
    );

    return controller.stream;
  }

  /// Clears the in-memory advisor chat session messages.
  void clearChatHistory() {
    chatHistory.clear();
  }

  /// Resets all user-scoped session state (chat history and regenerate cooldown) on sign-out.
  void resetSessionState() {
    chatHistory.clear();
    lastRegeneratedAt = null;
  }

  void dispose() {
    if (_ownsClient) {
      _client.close();
    }
  }
}
