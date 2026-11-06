import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../../../../core/constants/buck_ai_constants.dart';
import '../../../../core/services/supabase_service.dart';
import '../models/ai_insight_response.dart';

/// Service interfacing with the Buck AI FastAPI service.
///
/// Sends user queries with the user's Supabase JWT access token for
/// authenticated, RLS-bounded AI analytics and financial advisory.
class BuckAiService {
  final http.Client _client;

  BuckAiService({http.Client? client}) : _client = client ?? http.Client();

  /// Gets the bearer token for current authenticated user.
  String? get _userToken {
    if (!SupabaseService.isInitialized) return null;
    return SupabaseService.client.auth.currentSession?.accessToken;
  }

  Map<String, String> _buildHeaders({String? token}) {
    final effectiveToken = token ?? _userToken;
    final headers = <String, String>{
      'Content-Type': 'application/json',
    };
    if (effectiveToken != null && effectiveToken.isNotEmpty) {
      headers['Authorization'] = 'Bearer $effectiveToken';
    }
    return headers;
  }

  /// Fetches the latest financial strategy insight.
  ///
  /// Set [refresh] to true to force Gemini regeneration (subject to rate limit cooldowns).
  Future<AiInsightResponse> getInsight({bool refresh = false, String? token}) async {
    final uri = Uri.parse(
      refresh
          ? '${BuckAiConstants.advisorInsightEndpoint}?refresh=true'
          : BuckAiConstants.advisorInsightEndpoint,
    );

    final response = await _client.get(
      uri,
      headers: _buildHeaders(token: token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return AiInsightResponse.fromJson(data);
    }

    throw Exception('Failed to load AI insight (${response.statusCode}): ${response.body}');
  }

  /// Fetches saved advisory history.
  Future<AiInsightResponse?> getHistory({String? token}) async {
    final uri = Uri.parse(BuckAiConstants.advisorHistoryEndpoint);
    final response = await _client.get(
      uri,
      headers: _buildHeaders(token: token),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return AiInsightResponse.fromJson(data);
    }
    return null;
  }

  /// Auto-categorizes an expense or list of expenses using Gemini NLP embeddings.
  Future<List<String>> categorize({
    required List<String> descriptions,
    String kind = 'expense',
    String? token,
  }) async {
    if (descriptions.isEmpty) return const [];

    final uri = Uri.parse(BuckAiConstants.advisorCategorizeEndpoint);
    final response = await _client.post(
      uri,
      headers: _buildHeaders(token: token),
      body: jsonEncode({
        'kind': kind,
        'descriptions': descriptions,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      final categories = data['categories'];
      if (categories is List) {
        return categories.map((e) => e.toString()).toList();
      }
    }

    return const [];
  }

  /// Generates a customized AI saving or execution tip for a financial goal.
  Future<String?> getGoalTip({
    String? goalId,
    String? goalName,
    double? targetAmount,
    String? token,
  }) async {
    final uri = Uri.parse(BuckAiConstants.advisorGoalTipEndpoint);
    final body = <String, dynamic>{};
    if (goalId != null && goalId.isNotEmpty) body['goalId'] = goalId;
    if (goalName != null && goalName.isNotEmpty) body['goalName'] = goalName;
    if (targetAmount != null && targetAmount > 0) body['targetAmount'] = targetAmount;

    final response = await _client.post(
      uri,
      headers: _buildHeaders(token: token),
      body: jsonEncode(body),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(utf8.decode(response.bodyBytes)) as Map<String, dynamic>;
      return data['tip'] as String?;
    }

    return null;
  }

  /// Streams real-time financial advisor chat responses token-by-token.
  Stream<String> streamChat(String question, {String? token}) async* {
    final uri = Uri.parse(BuckAiConstants.advisorChatEndpoint);
    final request = http.Request('POST', uri);
    request.headers.addAll(_buildHeaders(token: token));
    request.body = jsonEncode({'question': question});

    final streamedResponse = await _client.send(request);
    if (streamedResponse.statusCode != 200) {
      final body = await streamedResponse.stream.bytesToString();
      throw Exception('AI Chat error (${streamedResponse.statusCode}): $body');
    }

    // Process SSE stream line-by-line
    final lineStream = streamedResponse.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter());

    await for (final line in lineStream) {
      final trimmed = line.trim();
      if (!trimmed.startsWith('data:')) continue;

      final jsonPayload = trimmed.substring(5).trim();
      if (jsonPayload.isEmpty) continue;

      try {
        final parsed = jsonDecode(jsonPayload) as Map<String, dynamic>;
        final type = parsed['type'] as String?;
        if (type == 'delta') {
          final text = parsed['text'] as String?;
          if (text != null && text.isNotEmpty) {
            yield text;
          }
        } else if (type == 'error') {
          final errorMsg = parsed['message'] as String? ?? 'AI error occurred';
          throw Exception(errorMsg);
        } else if (type == 'done') {
          break;
        }
      } catch (e) {
        if (e is Exception && e.toString().contains('AI error occurred')) {
          rethrow;
        }
        debugPrint('SSE parse warning: $e');
      }
    }
  }

  void dispose() {
    _client.close();
  }
}
