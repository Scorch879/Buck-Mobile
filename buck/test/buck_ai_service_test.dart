import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:buck/core/constants/dev_config.dart';
import 'package:buck/features/ai/data/models/ai_insight_response.dart';
import 'package:buck/features/ai/data/services/buck_ai_service.dart';
import 'package:buck/features/ai/presentation/screens/ai_chat_sheet.dart';
import 'package:buck/features/ai/presentation/widgets/ai_report_dialog.dart';
import 'package:buck/features/expenses/presentation/add_expense_dialog.dart';
import 'package:buck/features/finance/data/finance_models.dart';

class _FakeHttpClient extends http.BaseClient {
  final Future<http.StreamedResponse> Function(http.BaseRequest request) streamHandler;

  _FakeHttpClient(Future<http.Response> Function(http.BaseRequest request) handler)
      : streamHandler = ((request) async {
          final response = await handler(request);
          return http.StreamedResponse(
            Stream.value(response.bodyBytes),
            response.statusCode,
            headers: response.headers,
          );
        });

  _FakeHttpClient.chunked(this.streamHandler);

  @override
  Future<http.StreamedResponse> send(http.BaseRequest request) =>
      streamHandler(request);
}

void main() {
  tearDown(() {
    DevConfig.mockAdminSessionActive.value = false;
  });

  group('BuckAiService Unit Tests', () {
    test('getInsight parses valid AI insight response and preserves nullable score', () async {
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

      final unscored = AiInsightResponse.fromJson(const {'title': 'Unscored'});
      expect(unscored.financialHealthScore, isNull);
    });

    test('categorize maps AI synonyms like Gas Money and Bills to mobile categories', () async {
      final fakeClient = _FakeHttpClient((request) async {
        expect(request.url.path, contains('/advisor/categorize'));
        return http.Response(
          jsonEncode({
            'categories': ['Food', 'Gas Money', 'Bills', 'Dining Out'],
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final service = BuckAiService(client: fakeClient);
      final categories = await service.categorize(
        descriptions: ['Starbucks', 'Shell V-Power', 'Meralco', 'Jollibee'],
        token: 'test_token',
      );

      expect(categories, [
        'Food',
        'Transportation',
        'Bills & Utilities',
        'Food',
      ]);
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

    test('streamChat emits multi-chunk delta tokens in sequence', () async {
      final fakeClient = _FakeHttpClient.chunked((request) async {
        expect(request.url.path, contains('/advisor/chat'));
        final chunks = <List<int>>[
          utf8.encode('data: {"type": "meta", "source": "ai"}\n\n'),
          utf8.encode('data: {"type": "delta", "text": "Hello "}\n\n'),
          utf8.encode('data: {"type": "delta", "text": "**world**!"}\n\n'),
          utf8.encode('data: {"type": "done"}\n\n'),
        ];
        return http.StreamedResponse(
          Stream.fromIterable(chunks),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final service = BuckAiService(client: fakeClient);
      final tokens = await service.streamChat('Hello', token: 'test_token').toList();

      expect(tokens, ['Hello ', '**world**!']);
    });

    test('streamChat surfaces server SSE error events without swallowing them', () async {
      final fakeClient = _FakeHttpClient.chunked((request) async {
        final chunks = <List<int>>[
          utf8.encode('data: {"type": "error", "message": "Daily quota reached for all models."}\n\n'),
        ];
        return http.StreamedResponse(
          Stream.fromIterable(chunks),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final service = BuckAiService(client: fakeClient);
      expect(
        () => service.streamChat('Hello', token: 'test_token').toList(),
        throwsA(
          isA<BuckAiException>().having(
            (e) => e.message,
            'message',
            'Daily quota reached for all models.',
          ),
        ),
      );
    });

    test('Dev Mode session returns simulated insights and categories offline', () async {
      DevConfig.mockAdminSessionActive.value = true;
      final fakeClient = _FakeHttpClient((_) async => http.Response('Unauthorized', 401));
      final service = BuckAiService(client: fakeClient);

      final insight = await service.getInsight();
      expect(insight.generatedWith, 'dev-preview');
      expect(insight.financialHealthScore, isNotNull);

      final cats = await service.categorize(descriptions: ['Shell gas station']);
      expect(cats, ['Transportation']);
    });
  });

  group('Buck AI Widget Tests', () {
    testWidgets('AiMarkdownText strips raw ** markers and renders bold spans', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: AiMarkdownText(
              text: 'Daily cap is **₱2,701.34** per day.\n- Keep under **₱2,700**',
            ),
          ),
        ),
      );

      final richTexts = tester.widgetList<RichText>(find.byType(RichText)).toList();
      final combinedPlain = richTexts.map((r) => r.text.toPlainText()).join(' ');
      expect(combinedPlain, contains('₱2,701.34'));
      expect(combinedPlain, isNot(contains('**')));
    });

    testWidgets('AddExpenseDialog reveals AI Detect button while typing description', (tester) async {
      final fakeClient = _FakeHttpClient((request) async {
        return http.Response(
          jsonEncode({'categories': ['Gas Money']}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final aiService = BuckAiService(client: fakeClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: AddExpenseDialog(
              wallet: const Wallet(id: 'w1', name: 'Main', balance: 5000),
              aiService: aiService,
              onSubmit: (_) async {},
            ),
          ),
        ),
      );

      expect(find.text('AI Detect'), findsNothing);

      final descField = find.widgetWithText(TextField, 'Enter Description (optional)');
      await tester.enterText(descField, 'Shell V-Power Fuel');
      await tester.pump();

      expect(find.text('AI Detect'), findsOneWidget);

      await tester.ensureVisible(find.text('AI Detect'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('AI Detect'));
      await tester.pumpAndSettle();

      expect(find.text('Transportation'), findsOneWidget);
    });

    testWidgets('AiReportDialog handles unscored report and enforces regenerate cooldown', (tester) async {
      final fakeClient = _FakeHttpClient((request) async {
        return http.Response(
          jsonEncode({
            'id': 'ins-1',
            'title': 'Fresh Report',
            'suggestion': 'Keep saving',
            'advice': 'Good progress',
            'financialHealthScore': null,
            'priority': 'low',
            'focus': 'savings',
            'walletAdvice': 'Use Main Wallet',
            'generatedWith': 'gemini',
            'createdAt': '2026-11-06T10:00:00Z',
          }),
          200,
          headers: {'content-type': 'application/json'},
        );
      });
      final aiService = BuckAiService(client: fakeClient);
      aiService.lastRegeneratedAt = DateTime.now();

      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (ctx) => ElevatedButton(
              onPressed: () => showAiReportDialog(
                context: ctx,
                aiService: aiService,
                initialInsight: const AiInsightResponse(
                  id: 'init',
                  title: 'Initial Report',
                  suggestion: 'Save weekly',
                  advice: 'Detailed analysis text',
                  financialHealthScore: null,
                  priority: 'medium',
                  focus: 'goal',
                  walletAdvice: 'Wallet directive',
                  generatedWith: 'rules',
                  createdAt: '',
                ),
              ),
              child: const Text('Open Report'),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Report'));
      await tester.pumpAndSettle();

      expect(find.text('—'), findsOneWidget);
      expect(find.text('Unscored'), findsOneWidget);
      expect(find.textContaining('Regenerate ('), findsOneWidget);
    });
  });
}
