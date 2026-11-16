import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:intl/intl.dart';
import '../../../../core/constants/buck_ai_constants.dart';
import '../../../../core/constants/supabase_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../../../expenses/data/receipt_ocr_processor.dart';
import '../../../finance/data/finance_models.dart';
import '../../../goals/data/goal_model.dart';
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
  static const Duration _defaultRequestTimeout = Duration(seconds: 45);
  static const Duration _defaultStreamTimeout = Duration(seconds: 60);
  static const Duration regenerateCooldown = Duration(seconds: 60);

  /// Shared singleton instance so widgets do not leak [http.Client] instances.
  static final BuckAiService instance = BuckAiService._internal(
    http.Client(),
    ownsClient: false,
    requestTimeout: _defaultRequestTimeout,
    streamTimeout: _defaultStreamTimeout,
  );

  final http.Client _client;
  final bool _ownsClient;
  final Duration _requestTimeout;
  final Duration _streamTimeout;
  final bool? _useCandidateEndpoints;
  final Future<SupabaseAdvisorContext> Function()? _liveSupabaseContextLoader;

  /// Session-scoped chat message history preserved across sheet opens.
  final List<AiChatMessage> chatHistory = [];

  /// Timestamp of the last manual insight regeneration for client-side rate limiting.
  DateTime? lastRegeneratedAt;

  BuckAiService._internal(
    this._client, {
    required bool ownsClient,
    required Duration requestTimeout,
    required Duration streamTimeout,
  })  : _ownsClient = ownsClient,
        _requestTimeout = requestTimeout,
        _streamTimeout = streamTimeout,
        _useCandidateEndpoints = null,
        _liveSupabaseContextLoader = null;

  /// Creates an isolated [BuckAiService] instance.
  ///
  /// Prefer [BuckAiService.instance] in production widgets to share session state
  /// and avoid creating extra [http.Client] instances.
  BuckAiService({
    http.Client? client,
    Duration? requestTimeout,
    Duration? streamTimeout,
    @visibleForTesting bool? useCandidateEndpoints,
    @visibleForTesting
    Future<SupabaseAdvisorContext> Function()? liveSupabaseContextLoader,
  })  : _client = client ?? http.Client(),
        _ownsClient = true,
        _requestTimeout = requestTimeout ?? _defaultRequestTimeout,
        _streamTimeout =
            streamTimeout ?? requestTimeout ?? _defaultStreamTimeout,
        _useCandidateEndpoints = useCandidateEndpoints,
        _liveSupabaseContextLoader = liveSupabaseContextLoader;

  bool get _shouldUseCandidateEndpoints =>
      _useCandidateEndpoints ?? SupabaseService.isInitialized;

  bool get _canUseLiveSupabaseFallback {
    if (_liveSupabaseContextLoader != null) return true;
    if (!SupabaseService.isInitialized) return false;
    try {
      return SupabaseService.client.auth.currentUser != null;
    } catch (_) {
      return false;
    }
  }

  List<String> _endpointsFor(String advisorPath, String primaryUrl) {
    if (_shouldUseCandidateEndpoints) {
      return BuckAiConstants.candidateEndpoints(advisorPath);
    }
    return [primaryUrl];
  }

  /// Resolves a valid bearer token, refreshing the Supabase session if expired
  /// or close to expiry.
  Future<String?> _resolveToken({
    String? overrideToken,
    bool forceRefresh = false,
  }) async {
    if (overrideToken != null && overrideToken.isNotEmpty) {
      return overrideToken;
    }
    if (!SupabaseService.isInitialized) return null;
    try {
      var session = SupabaseService.client.auth.currentSession;
      if (session == null) return null;
      final expiresAtSec = session.expiresAt;
      final isNearExpiry = expiresAtSec != null &&
          DateTime.fromMillisecondsSinceEpoch(expiresAtSec * 1000)
              .isBefore(DateTime.now().add(const Duration(seconds: 60)));
      if (forceRefresh || session.isExpired || isNearExpiry) {
        final refreshed = await SupabaseService.client.auth.refreshSession();
        session = refreshed.session ?? SupabaseService.client.auth.currentSession;
      }
      return session?.accessToken;
    } catch (e) {
      debugPrint('Token refresh warning: $e');
      return SupabaseService.client.auth.currentSession?.accessToken;
    }
  }

  Map<String, String> _buildHeaders(
    String? token, {
    Uri? uri,
    bool isSse = false,
  }) {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      if (isSse) 'Accept': 'text/event-stream',
    };
    if (token != null && token.isNotEmpty) {
      headers['Authorization'] = 'Bearer $token';
    }
    if (_shouldUseCandidateEndpoints &&
        SupabaseConstants.anonKey.isNotEmpty &&
        (uri == null || !uri.host.endsWith('.vercel.app'))) {
      headers['apikey'] = SupabaseConstants.anonKey;
    }
    return headers;
  }

  static bool _isFailoverStatus(int statusCode) =>
      statusCode == 400 ||
      statusCode == 403 ||
      statusCode == 404 ||
      statusCode == 408 ||
      statusCode == 429 ||
      statusCode >= 500;

  static bool _isAuthFailureStatusOrBody(int statusCode, List<int> bodyBytes) {
    if (statusCode == 401) return true;
    if (bodyBytes.isEmpty) return false;
    try {
      final decoded = jsonDecode(utf8.decode(bodyBytes));
      if (decoded is Map<String, dynamic>) {
        return _isAuthFailureMap(decoded);
      }
    } catch (_) {}
    return false;
  }

  static bool _isAuthFailureMap(Map<String, dynamic> map) {
    final code = map['statusCode'] ?? map['status'] ?? map['code'];
    if (code == 401 || code == '401') return true;
    final parts = [
      map['error'],
      map['message'],
      map['detail'],
    ].whereType<String>().join(' ').toLowerCase();
    if (parts.isEmpty) return false;
    if (parts.contains('cors') || parts.contains('origin')) {
      return false;
    }
    return parts.contains('invalid jwt') ||
        parts.contains('jwt expired') ||
        parts.contains('not authenticated') ||
        parts.contains('missing authorization') ||
        parts.contains('invalid token') ||
        parts.contains('unauthorized');
  }

  Future<T> _sendJsonWithFailover<T>({
    required List<String> endpoints,
    required String? token,
    required Future<http.Response> Function(Uri uri, Map<String, String> headers)
        send,
    required T Function(Map<String, dynamic> json) parse,
    bool allowTokenRefresh = true,
    String timeoutMessage =
        'Buck AI request timed out. Please check your connection and try again.',
    String unreachableMessage =
        'Unable to reach Buck AI right now. Please try again shortly.',
  }) async {
    BuckAiException? lastError;
    var activeToken = token;
    var refreshedOnce = false;

    for (var i = 0; i < endpoints.length; i++) {
      final url = endpoints[i];
      final uri = Uri.parse(url);
      final headers = _buildHeaders(activeToken, uri: uri);
      try {
        final response = await send(uri, headers).timeout(_requestTimeout);
        if (response.statusCode == 200) {
          final decoded = jsonDecode(utf8.decode(response.bodyBytes));
          if (decoded is Map<String, dynamic>) {
            return parse(decoded);
          }
          lastError = BuckAiException(unreachableMessage);
          continue;
        }
        if (_isAuthFailureStatusOrBody(
            response.statusCode, response.bodyBytes)) {
          if (allowTokenRefresh && !refreshedOnce) {
            refreshedOnce = true;
            final nextToken = await _resolveToken(forceRefresh: true);
            if (nextToken != null &&
                nextToken.isNotEmpty &&
                nextToken != activeToken) {
              activeToken = nextToken;
              i--;
              continue;
            }
          }
          throw BuckAiException.fromStatus(401);
        }
        lastError = BuckAiException.fromStatus(response.statusCode);
        if (!_isFailoverStatus(response.statusCode)) {
          throw lastError;
        }
      } on BuckAiException {
        rethrow;
      } on TimeoutException {
        lastError = BuckAiException(timeoutMessage);
      } catch (e) {
        debugPrint('BuckAiService HTTP candidate failed ($url): $e');
        lastError = BuckAiException(unreachableMessage);
      }
    }

    throw lastError ?? BuckAiException(unreachableMessage);
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

    final advisorPath = refresh ? '/advisor/insight?refresh=true' : '/advisor/insight';
    final primaryUrl = refresh
        ? '${BuckAiConstants.advisorInsightEndpoint}?refresh=true'
        : BuckAiConstants.advisorInsightEndpoint;

    try {
      final insight = await _sendJsonWithFailover<AiInsightResponse>(
        endpoints: _endpointsFor(advisorPath, primaryUrl),
        token: effectiveToken,
        send: (uri, headers) => _client.get(uri, headers: headers),
        parse: AiInsightResponse.fromJson,
      );
      if (refresh) lastRegeneratedAt = DateTime.now();
      return insight;
    } on BuckAiException catch (e) {
      if (e.statusCode == 401 || !_canUseLiveSupabaseFallback) rethrow;
      try {
        final ctx = await _loadSupabaseAdvisorContext();
        if (refresh) lastRegeneratedAt = DateTime.now();
        return buildSupabaseInsight(ctx, refresh: refresh);
      } on BuckAiException {
        rethrow;
      } catch (fallbackErr) {
        debugPrint('BuckAiService.getInsight Supabase fallback error: $fallbackErr');
        throw e;
      }
    }
  }

  /// Fetches saved advisory history.
  Future<AiInsightResponse?> getHistory({String? token}) async {
    final effectiveToken = await _resolveToken(overrideToken: token);

    try {
      return await _sendJsonWithFailover<AiInsightResponse>(
        endpoints: _endpointsFor(
          '/advisor/history',
          BuckAiConstants.advisorHistoryEndpoint,
        ),
        token: effectiveToken,
        send: (uri, headers) => _client.get(uri, headers: headers),
        parse: AiInsightResponse.fromJson,
      );
    } on BuckAiException catch (e) {
      debugPrint('BuckAiService.getHistory warning: $e');
      if (e.statusCode == 401 || !_canUseLiveSupabaseFallback) return null;
      try {
        final ctx = await _loadSupabaseAdvisorContext();
        if (ctx.advisories.isNotEmpty) {
          return buildSupabaseInsight(ctx, refresh: false);
        }
      } catch (fallbackErr) {
        debugPrint('BuckAiService.getHistory Supabase fallback warning: $fallbackErr');
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

    final sanitizedDescriptions =
        descriptions.map(ReceiptOcrProcessor.sanitizePii).toList();

    final effectiveToken = await _resolveToken(overrideToken: token);

    final payload = jsonEncode({
      'kind': kind,
      'descriptions': sanitizedDescriptions,
    });

    try {
      return await _sendJsonWithFailover<List<String>>(
        endpoints: _endpointsFor(
          '/advisor/categorize',
          BuckAiConstants.advisorCategorizeEndpoint,
        ),
        token: effectiveToken,
        send: (uri, headers) => _client.post(uri, headers: headers, body: payload),
        parse: (data) {
          final categories = data['categories'];
          if (categories is! List) {
            throw const FormatException('Missing categories array');
          }
          return [
            for (var i = 0; i < categories.length; i++)
              mapToMobileCategory(
                categories[i].toString(),
                fallbackDescription:
                    i < sanitizedDescriptions.length ? sanitizedDescriptions[i] : '',
              ),
          ];
        },
      );
    } catch (e) {
      debugPrint('BuckAiService.categorize fallback: $e');
    }

    // Offline / fallback local keyword categorization
    return sanitizedDescriptions
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

    final body = <String, dynamic>{};
    if (goalId != null && goalId.isNotEmpty) body['goalId'] = goalId;
    if (goalName != null && goalName.isNotEmpty) body['goalName'] = goalName;
    if (targetAmount != null && targetAmount > 0) body['targetAmount'] = targetAmount;
    final payload = jsonEncode(body);

    try {
      return await _sendJsonWithFailover<String?>(
        endpoints: _endpointsFor(
          '/advisor/goal-tip',
          BuckAiConstants.advisorGoalTipEndpoint,
        ),
        token: effectiveToken,
        send: (uri, headers) => _client.post(uri, headers: headers, body: payload),
        parse: (data) => data['tip'] as String?,
        timeoutMessage: 'Buck AI request timed out. Please try again.',
        unreachableMessage: 'Unable to load AI goal tip right now.',
      );
    } on BuckAiException catch (e) {
      if (e.statusCode == 401 || !_canUseLiveSupabaseFallback) rethrow;
      try {
        final ctx = await _loadSupabaseAdvisorContext();
        return buildSupabaseGoalTip(
          ctx,
          goalId: goalId,
          goalName: goalName,
          targetAmount: targetAmount,
        );
      } on BuckAiException {
        rethrow;
      } catch (fallbackErr) {
        debugPrint('BuckAiService.getGoalTip Supabase fallback error: $fallbackErr');
        throw e;
      }
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
    Future<void> Function()? cancelCurrentAttempt;
    var isCancelled = false;

    controller = StreamController<String>(
      onCancel: () async {
        isCancelled = true;
        final cancel = cancelCurrentAttempt;
        cancelCurrentAttempt = null;
        if (cancel != null) {
          await cancel();
        }
      },
      onListen: () async {
        try {
          final effectiveToken = await _resolveToken(overrideToken: token);
          if (isCancelled || controller.isClosed) return;

          final endpoints = _endpointsFor(
            '/advisor/chat',
            BuckAiConstants.advisorChatEndpoint,
          );
          final bodyJson = jsonEncode({
            'question': _buildContextualQuestion(question, history),
          });
          BuckAiException? lastError;
          var activeToken = effectiveToken;
          var refreshedOnce = false;

          for (var i = 0; i < endpoints.length; i++) {
            final url = endpoints[i];
            if (isCancelled || controller.isClosed) return;
            final outcome = await _attemptStreamChatEndpoint(
              uri: Uri.parse(url),
              token: activeToken,
              bodyJson: bodyJson,
              controller: controller,
              isCancelled: () => isCancelled || controller.isClosed,
              registerCancel: (fn) => cancelCurrentAttempt = fn,
            );
            cancelCurrentAttempt = null;
            if (isCancelled || controller.isClosed) return;

            switch (outcome) {
              case _ChatAttemptSucceeded():
                if (!controller.isClosed) {
                  await controller.close();
                }
                return;
              case _ChatAttemptFailed(
                  :final error,
                  :final authFailure,
                  :final emittedAnyDelta,
                  :final retryable,
                ):
                if (authFailure && !emittedAnyDelta && !refreshedOnce && token == null) {
                  refreshedOnce = true;
                  final nextToken = await _resolveToken(forceRefresh: true);
                  if (isCancelled || controller.isClosed) return;
                  if (nextToken != null &&
                      nextToken.isNotEmpty &&
                      nextToken != activeToken) {
                    activeToken = nextToken;
                    i--;
                    continue;
                  }
                }
                if (authFailure || emittedAnyDelta || !retryable) {
                  if (!controller.isClosed) {
                    controller.addError(error);
                    await controller.close();
                  }
                  return;
                }
                lastError = error;
            }
          }

          if (_canUseLiveSupabaseFallback) {
            try {
              final ctx = await _loadSupabaseAdvisorContext();
              if (isCancelled || controller.isClosed) return;
              final reply = buildSupabaseChatReply(question, ctx);
              await _emitTextInChunks(
                reply,
                controller: controller,
                isCancelled: () => isCancelled || controller.isClosed,
              );
              if (!isCancelled && !controller.isClosed) {
                await controller.close();
              }
              return;
            } catch (e) {
              debugPrint('BuckAiService.streamChat Supabase fallback error: $e');
              if (e is BuckAiException) {
                lastError = e;
              }
            }
          }

          if (!isCancelled && !controller.isClosed) {
            controller.addError(
              lastError ??
                  const BuckAiException(
                    'Unable to connect to Buck AI chat right now.',
                  ),
            );
            await controller.close();
          }
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

  Future<_ChatAttemptOutcome> _attemptStreamChatEndpoint({
    required Uri uri,
    required String? token,
    required String bodyJson,
    required StreamController<String> controller,
    required bool Function() isCancelled,
    required void Function(Future<void> Function()?) registerCancel,
  }) async {
    final request = http.Request('POST', uri);
    request.headers.addAll(_buildHeaders(token, uri: uri, isSse: true));
    request.body = bodyJson;

    final http.StreamedResponse streamedResponse;
    try {
      streamedResponse = await _client.send(request).timeout(_streamTimeout);
    } on TimeoutException {
      return const _ChatAttemptFailed(
        BuckAiException('Buck AI chat connection timed out. Please try again.'),
      );
    } catch (e) {
      debugPrint('BuckAiService.streamChat send error ($uri): $e');
      return const _ChatAttemptFailed(
        BuckAiException('Unable to connect to Buck AI chat right now.'),
      );
    }

    if (isCancelled()) return const _ChatAttemptSucceeded();

    if (streamedResponse.statusCode != 200) {
      List<int> errorBytes = const [];
      try {
        errorBytes = await streamedResponse.stream
            .toBytes()
            .timeout(const Duration(seconds: 2));
      } catch (_) {}
      if (_isAuthFailureStatusOrBody(streamedResponse.statusCode, errorBytes)) {
        return _ChatAttemptFailed(
          BuckAiException.fromStatus(401),
          authFailure: true,
          retryable: false,
        );
      }
      return _ChatAttemptFailed(
        BuckAiException.fromStatus(streamedResponse.statusCode),
        retryable: _isFailoverStatus(streamedResponse.statusCode),
      );
    }

    final completer = Completer<_ChatAttemptOutcome>();
    var hasEmittedDelta = false;
    StreamSubscription<String>? lineSub;

    void finish(_ChatAttemptOutcome outcome) {
      if (!completer.isCompleted) {
        completer.complete(outcome);
      }
    }

    registerCancel(() async {
      await lineSub?.cancel();
      finish(const _ChatAttemptSucceeded());
    });

    final lineStream = streamedResponse.stream
        .timeout(_streamTimeout)
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    lineSub = lineStream.listen(
      (line) {
        if (isCancelled()) {
          lineSub?.cancel();
          finish(const _ChatAttemptSucceeded());
          return;
        }
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
            hasEmittedDelta = true;
            controller.add(text);
          }
        } else if (type == 'error') {
          final isAuth = _isAuthFailureMap(parsed);
          final rawMsg = (parsed['message'] ?? parsed['error']) as String?;
          final error = isAuth
              ? BuckAiException.fromStatus(401)
              : BuckAiException(
                  rawMsg != null && rawMsg.isNotEmpty
                      ? rawMsg
                      : 'Buck AI encountered an error while answering.',
                );
          lineSub?.cancel();
          finish(_ChatAttemptFailed(
            error,
            authFailure: isAuth,
            emittedAnyDelta: hasEmittedDelta,
            retryable: !isAuth && !hasEmittedDelta,
          ));
        } else if (type == 'done') {
          lineSub?.cancel();
          finish(const _ChatAttemptSucceeded());
        }
      },
      onError: (Object e) {
        if (isCancelled()) {
          finish(const _ChatAttemptSucceeded());
          return;
        }
        final BuckAiException ex;
        if (e is BuckAiException) {
          ex = e;
        } else if (e is TimeoutException) {
          ex = const BuckAiException(
            'Buck AI response timed out. Please try again.',
          );
        } else {
          debugPrint('BuckAiService.streamChat stream error: $e');
          ex = const BuckAiException(
            'Connection interrupted while receiving Buck AI response.',
          );
        }
        finish(_ChatAttemptFailed(
          ex,
          emittedAnyDelta: hasEmittedDelta,
          retryable: !hasEmittedDelta,
        ));
      },
      onDone: () {
        if (!hasEmittedDelta) {
          finish(const _ChatAttemptFailed(
            BuckAiException('Buck AI returned an empty response. Retrying...'),
            retryable: true,
          ));
          return;
        }
        finish(const _ChatAttemptSucceeded());
      },
      cancelOnError: true,
    );

    return completer.future;
  }

  Future<void> _emitTextInChunks(
    String text, {
    required StreamController<String> controller,
    required bool Function() isCancelled,
  }) async {
    final tokens = RegExp(r'\S+\s*').allMatches(text).map((m) => m.group(0)!).toList();
    if (tokens.isEmpty) {
      if (text.isNotEmpty && !isCancelled()) {
        controller.add(text);
      }
      return;
    }

    const chunkSize = 3;
    for (var i = 0; i < tokens.length; i += chunkSize) {
      if (isCancelled()) return;
      final end = (i + chunkSize < tokens.length) ? i + chunkSize : tokens.length;
      controller.add(tokens.sublist(i, end).join());
      if (end < tokens.length) {
        await Future<void>.delayed(const Duration(milliseconds: 8));
      }
    }
  }

  Future<SupabaseAdvisorContext> _loadSupabaseAdvisorContext() async {
    final customLoader = _liveSupabaseContextLoader;
    if (customLoader != null) {
      return customLoader();
    }

    final client = SupabaseService.client;
    final userId = client.auth.currentUser?.id;
    if (userId == null) {
      throw BuckAiException.fromStatus(401);
    }

    final now = DateTime.now();
    final monthStartStr =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-01';

    Future<Map<String, dynamic>?> loadProfile() async {
      try {
        return await client
            .from('profiles')
            .select('username, active_wallet_id')
            .eq('id', userId)
            .maybeSingle();
      } catch (e) {
        debugPrint('BuckAiService fallback profiles query warning: $e');
        return null;
      }
    }

    Future<List<Wallet>> loadWallets() async {
      try {
        final rows = await client
            .from('wallets')
            .select('id, name, budget')
            .eq('user_id', userId)
            .isFilter('deleted_at', null)
            .order('created_at', ascending: false);
        return (rows as List)
            .cast<Map<String, dynamic>>()
            .map(Wallet.fromRow)
            .toList();
      } catch (e) {
        debugPrint('BuckAiService fallback wallets query warning: $e');
        return const [];
      }
    }

    Future<List<ExpenseRecord>> loadExpenses() async {
      try {
        final rows = await client
            .from('expenses')
            .select('id, wallet_id, category_name, amount, description, spent_on')
            .eq('user_id', userId)
            .order('spent_on', ascending: false)
            .order('created_at', ascending: false)
            .limit(500);
        return (rows as List)
            .cast<Map<String, dynamic>>()
            .map(ExpenseRecord.fromRow)
            .toList();
      } catch (e) {
        debugPrint('BuckAiService fallback expenses query warning: $e');
        return const [];
      }
    }

    Future<List<IncomeRecord>> loadIncomes() async {
      try {
        final rows = await client
            .from('incomes')
            .select('id, wallet_id, source, amount, received_on')
            .eq('user_id', userId)
            .gte('received_on', monthStartStr)
            .order('received_on', ascending: false);
        return (rows as List)
            .cast<Map<String, dynamic>>()
            .map(IncomeRecord.fromRow)
            .toList();
      } catch (e) {
        debugPrint('BuckAiService fallback incomes query warning: $e');
        return const [];
      }
    }

    Future<List<GoalItem>> loadGoals() async {
      try {
        final rows = await client
            .from('goals')
            .select(
              'id, goal_name, target_amount, current_amount, completed, is_active, target_date, attitude',
            )
            .eq('user_id', userId)
            .isFilter('deleted_at', null)
            .order('is_active', ascending: false)
            .order('created_at', ascending: false);
        return (rows as List)
            .cast<Map<String, dynamic>>()
            .map(GoalItem.fromRow)
            .toList();
      } catch (e) {
        debugPrint('BuckAiService fallback goals query warning: $e');
        return const [];
      }
    }

    Future<(List<AiAdvisory>, String?)> loadAdvisories() async {
      try {
        final rows = await client
            .from('ai_advisories')
            .select('id, title, suggestion, advice, created_at')
            .eq('user_id', userId)
            .eq('is_dismissed', false)
            .order('created_at', ascending: false)
            .limit(3);
        final list = (rows as List).cast<Map<String, dynamic>>();
        final advisories = list
            .map(AiAdvisory.fromRow)
            .where((a) => a.text.isNotEmpty)
            .toList();
        final latestCreatedAt =
            list.isNotEmpty ? list.first['created_at'] as String? : null;
        return (advisories, latestCreatedAt);
      } catch (e) {
        debugPrint('BuckAiService fallback ai_advisories query warning: $e');
        return (const <AiAdvisory>[], null);
      }
    }

    final results = await Future.wait<Object?>([
      loadProfile(),
      loadWallets(),
      loadExpenses(),
      loadIncomes(),
      loadGoals(),
      loadAdvisories(),
    ]).timeout(_requestTimeout);

    final profile = results[0] as Map<String, dynamic>?;
    final advisoryPair = results[5] as (List<AiAdvisory>, String?);

    return SupabaseAdvisorContext(
      profileName: (profile?['username'] as String?)?.trim(),
      activeWalletId: profile?['active_wallet_id'] as String?,
      wallets: results[1] as List<Wallet>,
      expenses: results[2] as List<ExpenseRecord>,
      incomes: results[3] as List<IncomeRecord>,
      goals: results[4] as List<GoalItem>,
      advisories: advisoryPair.$1,
      latestAdvisoryCreatedAt: advisoryPair.$2,
      now: now,
    );
  }

  static final NumberFormat _pesoNumberFormat = NumberFormat('#,##0.00', 'en_US');

  static String _formatPeso(double amount) {
    final prefix = amount < 0 ? '-₱' : '₱';
    return '$prefix${_pesoNumberFormat.format(amount.abs())}';
  }

  /// Builds a live Markdown chat reply from the user's Supabase financial context.
  @visibleForTesting
  static String buildSupabaseChatReply(
    String question,
    SupabaseAdvisorContext ctx,
  ) {
    if (ctx.totalBalance <= 0 && ctx.expenses.isEmpty) {
      final walletHint = ctx.wallets.isNotEmpty
          ? ' in **${ctx.activeWalletName}**'
          : '';
      return 'Your **Buck** account currently has a **₱0.00** balance and no logged expenses yet.\n\n'
          'Here is how to get started so I can calculate your budget and strategy:\n'
          '- **Fund a wallet**: Open **Wallets** or tap **Add Income** to set your starting balance$walletHint.\n'
          '- **Log your first expense**: Record a transaction (or scan a receipt) to unlock category breakdowns and monthly pacing.\n'
          '- **Add a savings goal**: Create a target in **Goals** (like an Emergency Fund) to track weekly milestones.\n\n'
          'Once you add a balance or expense, ask me again for your remaining daily budget!';
    }

    final q = question.toLowerCase();
    final asksGoals = q.contains('goal') || q.contains('save') || q.contains('saving') || q.contains('target');
    final asksDaily = q.contains('daily') ||
        q.contains('limit') ||
        q.contains('afford') ||
        q.contains('tonight') ||
        q.contains('today') ||
        q.contains('cap');
    final asksSpending = q.contains('spend') ||
        q.contains('month') ||
        q.contains('expense') ||
        q.contains('category') ||
        q.contains('breakdown');

    final buf = StringBuffer();
    final activeBalanceStr = _formatPeso(ctx.activeWalletBalance);
    final totalBalanceStr = _formatPeso(ctx.totalBalance);
    final monthSpendStr = _formatPeso(ctx.monthSpend);
    final dailyBudgetStr = _formatPeso(ctx.dailyBudget);
    final daysLeft = ctx.daysRemainingInMonth;

    if (asksGoals && ctx.activeGoals.isNotEmpty) {
      final topGoal = ctx.activeGoals.first;
      final monthlyPace = topGoal.remaining / 6;
      buf.writeln(
        'You currently have **${ctx.activeGoals.length}** active goal(s) with **$activeBalanceStr** in **${ctx.activeWalletName}** ($totalBalanceStr total across wallets).',
      );
      buf.writeln();
      for (final g in ctx.activeGoals.take(3)) {
        buf.writeln(
          '- **${g.title}**: ${_formatPeso(g.currentAmount)} / ${_formatPeso(g.targetAmount)} (${g.percentage.toStringAsFixed(0)}% — ${_formatPeso(g.remaining)} remaining)',
        );
      }
      buf.writeln();
      buf.write(
        'Setting aside **${_formatPeso(monthlyPace)}/month** keeps **${topGoal.title}** on a 6-month track while maintaining your **$dailyBudgetStr/day** spending cap for the remaining $daysLeft day(s) this month.',
      );
      return buf.toString();
    }

    if (asksDaily) {
      buf.writeln(
        'Your safe remaining daily budget is **$dailyBudgetStr/day** across the remaining **$daysLeft day(s)** this month.',
      );
    } else if (asksSpending) {
      buf.writeln(
        'This month you have spent **$monthSpendStr** so far, leaving **$dailyBudgetStr/day** across the remaining **$daysLeft day(s)**.',
      );
    } else {
      buf.writeln(
        'Here is your live financial snapshot from **${ctx.activeWalletName}** ($activeBalanceStr):',
      );
    }

    buf.writeln();
    buf.writeln(
      '- **Active Wallet (${ctx.activeWalletName})**: $activeBalanceStr'
      '${ctx.wallets.length > 1 ? ' (Total across ${ctx.wallets.length} wallets: $totalBalanceStr)' : ''}',
    );
    buf.writeln(
      '- **Current-Month Spending**: $monthSpendStr'
      '${ctx.monthIncome > 0 ? ' against ${_formatPeso(ctx.monthIncome)} tracked income' : ''}',
    );
    buf.writeln(
      '- **Remaining Daily Budget**: $dailyBudgetStr/day ($daysLeft day(s) left this month)',
    );

    if (ctx.topCategories.isNotEmpty) {
      final topList = ctx.topCategories
          .take(3)
          .map((e) => '${e.key} (${_formatPeso(e.value)})')
          .join(', ');
      buf.writeln('- **Top Categories**: $topList');
    }

    if (ctx.activeGoals.isNotEmpty) {
      final g = ctx.activeGoals.first;
      buf.writeln(
        '- **Top Goal (${g.title})**: ${_formatPeso(g.currentAmount)} / ${_formatPeso(g.targetAmount)} (${_formatPeso(g.remaining)} left)',
      );
    }

    if (q.contains('afford')) {
      buf.writeln();
      buf.write(
        ctx.dailyBudget > 0
            ? 'Keep tonight\'s treat at or below **$dailyBudgetStr** so your remaining daily budget stays intact through month-end.'
            : 'Your active wallet has little buffer left right now—hold off on discretionary dining or transfer funds from another wallet first.',
      );
    } else if (ctx.activeGoals.isEmpty) {
      buf.writeln();
      buf.write(
        'Consider creating a savings goal in **Goals** to earmark part of your **$totalBalanceStr** balance.',
      );
    }

    return buf.toString();
  }

  /// Synthesizes or adapts an [AiInsightResponse] from Supabase tables.
  @visibleForTesting
  static AiInsightResponse buildSupabaseInsight(
    SupabaseAdvisorContext ctx, {
    bool refresh = false,
  }) {
    final now = ctx.now;
    final asOf =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
    final monthStart =
        '${now.year.toString().padLeft(4, '0')}-${now.month.toString().padLeft(2, '0')}-01';
    final period = AiPeriod(asOf: asOf, monthStart: monthStart);

    if (ctx.totalBalance <= 0 && ctx.expenses.isEmpty) {
      final walletAdvice = ctx.wallets.isEmpty
          ? 'Create your first wallet in the Wallets tab to start tracking balances.'
          : 'Add starting funds to ${ctx.activeWalletName} via Add Income so daily limits calculate accurately.';
      return AiInsightResponse(
        id: 'supabase-local-onboarding',
        title: 'Set Up Your First Budget',
        suggestion:
            'Add your starting wallet balance or log your first expense to unlock daily spending limits.',
        advice:
            'Your wallets currently total ₱0.00 with no logged expenses yet. Recording your active wallet balance and everyday spending lets Buck calculate your safe daily pace, top categories, and goal milestones.',
        financialHealthScore: null,
        priority: 'medium',
        focus: 'budgeting',
        walletAdvice: walletAdvice,
        period: period,
        generatedWith: 'supabase-local',
        createdAt: now.toIso8601String(),
        cached: false,
        stale: false,
      );
    }

    var score = 68;
    if (ctx.monthIncome > 0) {
      final savingsRate = (ctx.monthIncome - ctx.monthSpend) / ctx.monthIncome;
      if (savingsRate >= 0.30) {
        score += 18;
      } else if (savingsRate >= 0.15) {
        score += 10;
      } else if (savingsRate >= 0) {
        score += 4;
      } else {
        score -= 18;
      }
    } else if (ctx.totalBalance > ctx.monthSpend * 2 && ctx.totalBalance > 0) {
      score += 10;
    } else if (ctx.totalBalance >= ctx.monthSpend && ctx.totalBalance > 0) {
      score += 4;
    } else if (ctx.totalBalance <= 0 && ctx.monthSpend > 0) {
      score -= 14;
    }

    if (ctx.activeGoals.isNotEmpty) {
      final avgProgress = ctx.activeGoals
              .map((g) => g.progress)
              .fold<double>(0.0, (a, b) => a + b) /
          ctx.activeGoals.length;
      score += avgProgress >= 0.4 ? 7 : 4;
    }
    final clampedScore = score.clamp(25, 96);

    final topCategory = ctx.topCategories.isNotEmpty ? ctx.topCategories.first : null;
    final deficit = ctx.monthIncome > 0 && ctx.monthSpend > ctx.monthIncome;
    final priority = (deficit || ctx.activeWalletBalance <= 0)
        ? 'high'
        : (clampedScore >= 80 ? 'low' : 'medium');
    final focus = ctx.activeGoals.isNotEmpty && !deficit ? 'goals' : 'spending';

    final walletAdvice = ctx.wallets.length > 1
        ? 'Keep daily spending inside ${ctx.activeWalletName} (${_formatPeso(ctx.activeWalletBalance)}) while protecting the rest of your ${_formatPeso(ctx.totalBalance)} total balance across ${ctx.wallets.length} wallets.'
        : 'Pace expenses from ${ctx.activeWalletName} (${_formatPeso(ctx.activeWalletBalance)}) at no more than ${_formatPeso(ctx.dailyBudget)}/day for the remaining ${ctx.daysRemainingInMonth} day(s) this month.';

    final computedTitle = deficit
        ? 'Monthly Spending Above Tracked Income'
        : (clampedScore >= 80 ? 'Strong Financial Pacing' : 'Steady Monthly Budget Pacing');

    final computedSuggestion = topCategory != null
        ? 'Cap daily spending at ${_formatPeso(ctx.dailyBudget)}/day and trim ${topCategory.key} (${_formatPeso(topCategory.value)} this month) to build extra buffer.'
        : 'Keep daily spending under ${_formatPeso(ctx.dailyBudget)}/day across the remaining ${ctx.daysRemainingInMonth} day(s) this month.';

    final incomeClause = ctx.monthIncome > 0
        ? ' against ${_formatPeso(ctx.monthIncome)} in tracked income'
        : '';
    final topCategoryClause = topCategory != null
        ? ' Your highest category is ${topCategory.key} at ${_formatPeso(topCategory.value)}.'
        : '';
    final goalClause = ctx.activeGoals.isNotEmpty
        ? ' You have ${ctx.activeGoals.length} active goal(s), led by ${ctx.activeGoals.first.title} with ${_formatPeso(ctx.activeGoals.first.remaining)} left to reach its target.'
        : ' Adding a dedicated savings goal can help ring-fence your surplus balance.';

    final computedAdvice =
        'You have spent ${_formatPeso(ctx.monthSpend)} this month$incomeClause with ${_formatPeso(ctx.totalBalance)} available across ${ctx.wallets.length} wallet(s).'
        '$topCategoryClause$goalClause';

    if (!refresh && ctx.advisories.isNotEmpty) {
      final latest = ctx.advisories.first;
      return AiInsightResponse(
        id: latest.id,
        title: latest.title.trim().isNotEmpty ? latest.title.trim() : computedTitle,
        suggestion: latest.suggestion.trim().isNotEmpty
            ? latest.suggestion.trim()
            : computedSuggestion,
        advice: latest.advice.trim().isNotEmpty
            ? latest.advice.trim()
            : computedAdvice,
        financialHealthScore: clampedScore,
        priority: priority,
        focus: focus,
        walletAdvice: walletAdvice,
        period: period,
        generatedWith: 'supabase-local',
        createdAt: ctx.latestAdvisoryCreatedAt ?? now.toIso8601String(),
        cached: true,
        stale: false,
      );
    }

    return AiInsightResponse(
      id: 'supabase-local-${now.millisecondsSinceEpoch}',
      title: computedTitle,
      suggestion: computedSuggestion,
      advice: computedAdvice,
      financialHealthScore: clampedScore,
      priority: priority,
      focus: focus,
      walletAdvice: walletAdvice,
      period: period,
      generatedWith: 'supabase-local',
      createdAt: now.toIso8601String(),
      cached: false,
      stale: false,
    );
  }

  /// Computes a personalized goal saving tip using live wallet balance and goal target.
  @visibleForTesting
  static String buildSupabaseGoalTip(
    SupabaseAdvisorContext ctx, {
    String? goalId,
    String? goalName,
    double? targetAmount,
  }) {
    GoalItem? matchedGoal;
    for (final g in ctx.goals) {
      if (goalId != null && goalId.isNotEmpty && g.id == goalId) {
        matchedGoal = g;
        break;
      }
      if (goalName != null &&
          goalName.isNotEmpty &&
          g.title.toLowerCase() == goalName.trim().toLowerCase()) {
        matchedGoal = g;
        break;
      }
    }

    final effectiveName = (goalName != null && goalName.trim().isNotEmpty)
        ? goalName.trim()
        : (matchedGoal?.title ?? 'your goal');
    final effectiveTarget = (targetAmount != null && targetAmount > 0)
        ? targetAmount
        : (matchedGoal?.targetAmount ?? 0.0);
    final alreadySaved = matchedGoal?.currentAmount ?? 0.0;
    final remaining = (effectiveTarget - alreadySaved).clamp(0.0, double.infinity);

    if (effectiveTarget > 0 && remaining <= 0) {
      return 'Great job—$effectiveName has already reached its ${_formatPeso(effectiveTarget)} target! Keep your ${_formatPeso(ctx.activeWalletBalance)} ${ctx.activeWalletName} balance protected or roll your next savings toward another goal.';
    }

    if (effectiveTarget > 0) {
      final monthlyStep = remaining / 6;
      final weeklyStep = remaining / 24;
      if (ctx.activeWalletBalance >= remaining && remaining > 0) {
        return 'Your ${ctx.activeWalletName} balance (${_formatPeso(ctx.activeWalletBalance)}) already covers the remaining ${_formatPeso(remaining)} for $effectiveName. Allocate ${_formatPeso(monthlyStep)}/month (or ${_formatPeso(weeklyStep)}/week) while keeping an everyday buffer.';
      }
      if (ctx.totalBalance > 0) {
        final suggestedSlice = (ctx.activeWalletBalance > 0
                ? ctx.activeWalletBalance * 0.15
                : ctx.totalBalance * 0.15)
            .clamp(100.0, remaining);
        return 'To reach $effectiveName (${_formatPeso(effectiveTarget)}), set aside ${_formatPeso(weeklyStep)}/week (${_formatPeso(monthlyStep)}/month). Starting with ${_formatPeso(suggestedSlice)} from your ${_formatPeso(ctx.activeWalletBalance)} ${ctx.activeWalletName} balance gives you immediate momentum.';
      }
      return 'Once you fund ${ctx.activeWalletName}, automate ${_formatPeso(monthlyStep)}/month (${_formatPeso(weeklyStep)}/week) right after payday to hit your ${_formatPeso(effectiveTarget)} $effectiveName target in 6 months.';
    }

    return 'Set aside a consistent weekly transfer from ${ctx.activeWalletName} (${_formatPeso(ctx.activeWalletBalance)} available) right after payday to keep $effectiveName moving forward.';
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

sealed class _ChatAttemptOutcome {
  const _ChatAttemptOutcome();
}

final class _ChatAttemptSucceeded extends _ChatAttemptOutcome {
  const _ChatAttemptSucceeded();
}

final class _ChatAttemptFailed extends _ChatAttemptOutcome {
  final BuckAiException error;
  final bool authFailure;
  final bool emittedAnyDelta;
  final bool retryable;

  const _ChatAttemptFailed(
    this.error, {
    this.authFailure = false,
    this.emittedAnyDelta = false,
    this.retryable = true,
  });
}

/// Snapshot of the signed-in user's Supabase data used by the local advisor fallback.
@visibleForTesting
class SupabaseAdvisorContext {
  final String? profileName;
  final String? activeWalletId;
  final List<Wallet> wallets;
  final List<ExpenseRecord> expenses;
  final List<IncomeRecord> incomes;
  final List<GoalItem> goals;
  final List<AiAdvisory> advisories;
  final String? latestAdvisoryCreatedAt;
  final DateTime now;

  SupabaseAdvisorContext({
    this.profileName,
    this.activeWalletId,
    this.wallets = const [],
    this.expenses = const [],
    this.incomes = const [],
    this.goals = const [],
    this.advisories = const [],
    this.latestAdvisoryCreatedAt,
    DateTime? now,
  }) : now = now ?? DateTime.now();

  Wallet? get activeWallet {
    if (wallets.isEmpty) return null;
    if (activeWalletId != null) {
      for (final w in wallets) {
        if (w.id == activeWalletId) return w;
      }
    }
    return wallets.first;
  }

  double get totalBalance =>
      wallets.fold<double>(0.0, (sum, w) => sum + w.balance);

  double get activeWalletBalance => activeWallet?.balance ?? 0.0;

  String get activeWalletName => activeWallet?.name ?? 'Main Wallet';

  List<ExpenseRecord> get currentMonthExpenses => expenses
      .where((e) => e.spentOn.year == now.year && e.spentOn.month == now.month)
      .toList();

  double get monthSpend =>
      currentMonthExpenses.fold<double>(0.0, (sum, e) => sum + e.amount);

  double get monthIncome => incomes
      .where((i) =>
          i.receivedOn.year == now.year && i.receivedOn.month == now.month)
      .fold<double>(0.0, (sum, i) => sum + i.amount);

  int get daysRemainingInMonth {
    final daysInMonth = DateTime(now.year, now.month + 1, 0).day;
    return (daysInMonth - now.day + 1).clamp(1, 31);
  }

  double get spendingPower =>
      activeWalletBalance > 0 ? activeWalletBalance : totalBalance;

  double get dailyBudget =>
      spendingPower > 0 ? spendingPower / daysRemainingInMonth : 0.0;

  List<MapEntry<String, double>> get topCategories {
    final totals = <String, double>{};
    for (final e in currentMonthExpenses) {
      totals[e.categoryName] = (totals[e.categoryName] ?? 0.0) + e.amount;
    }
    final entries = totals.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return entries;
  }

  List<GoalItem> get activeGoals =>
      goals.where((g) => g.status != GoalStatus.completed).toList();
}
