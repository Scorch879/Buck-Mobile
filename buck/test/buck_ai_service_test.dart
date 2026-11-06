import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:buck/features/ai/data/services/buck_ai_service.dart';

class _FakeHttpClient extends http.BaseClient {
  final Future<http.Response> Function(http.BaseRequest request) handler;
  _FakeHttpClient(this.handler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) async {
    final response = await handler(request);
    return http.StreamedResponse(
      Stream.value(response.bodyBytes),
      response.statusCode,
      headers: response.headers,
    );
  }
}

void main() {
  group('BuckAiService Tests', () {
    test('getInsight parses valid AI insight response', () async {
      final fakeClient = _FakeHttpClient((request) async {
        expect(request.url.path, contains('/advisor/insight'));
        expect(request.headers['Authorization'], 'Bearer test_token');
        return http.Response(
          jsonEncode({
            'id': 'insight-123',
            'title': 'Optimize Weekly Spending',
            'suggestion': 'Save ₱500 per week',
            'advice': 'Reduce dining out by 15%',
            'financialHealthScore': 85,
            'priority': 'high',
            'focus': 'savings',
            'walletAdvice': 'Use your primary wallet',
            'period': {'asOf': '2026-11-06', 'monthStart': '2026-11-01'},
            'generatedWith': 'gemini-3.8-flash',
            'createdAt': '2026-11-06T10:00:00Z',
            'cached': false,
            'stale': false,
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = BuckAiService(client: fakeClient);
      final insight = await service.getInsight(token: 'test_token');

      expect(insight.id, 'insight-123');
      expect(insight.title, 'Optimize Weekly Spending');
      expect(insight.financialHealthScore, 85);
      expect(insight.generatedWith, 'gemini-3.8-flash');
    });

    test('categorize maps descriptions to predicted categories', () async {
      final fakeClient = _FakeHttpClient((request) async {
        expect(request.url.path, contains('/advisor/categorize'));
        return http.Response(
          jsonEncode({
            'categories': ['Food', 'Transportation'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = BuckAiService(client: fakeClient);
      final categories = await service.categorize(
        descriptions: ['Starbucks', 'Grab taxi'],
        token: 'test_token',
      );

      expect(categories, ['Food', 'Transportation']);
    });

    test('getGoalTip returns AI personalized advice for goal', () async {
      final fakeClient = _FakeHttpClient((request) async {
        expect(request.url.path, contains('/advisor/goal-tip'));
        return http.Response(
          jsonEncode({
            'tip': 'Save ₱1,000 every payday to reach Emergency Fund in 6 months.',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = BuckAiService(client: fakeClient);
      final tip = await service.getGoalTip(
        goalName: 'Emergency Fund',
        targetAmount: 50000,
        token: 'test_token',
      );

      expect(tip, contains('Save ₱1,000 every payday'));
    });

    test('streamChat emits delta tokens in sequence', () async {
      final fakeClient = _FakeHttpClient((request) async {
        expect(request.url.path, contains('/advisor/chat'));
        const sseBody =
            'data: {"type": "meta", "source": "ai"}\n\n'
            'data: {"type": "delta", "text": "Hello "}\n\n'
            'data: {"type": "delta", "text": "there!"}\n\n'
            'data: {"type": "done"}\n\n';
        return http.Response(
          sseBody,
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final service = BuckAiService(client: fakeClient);
      final stream = service.streamChat('Hello', token: 'test_token');
      final tokens = await stream.toList();

      expect(tokens, ['Hello ', 'there!']);
    });
  });
}
