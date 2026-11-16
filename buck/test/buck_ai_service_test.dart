import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:buck/core/constants/buck_ai_constants.dart';
import 'package:buck/core/constants/supabase_constants.dart';
import 'package:buck/features/ai/data/models/ai_chat_message.dart';
import 'package:buck/features/ai/data/models/ai_insight_response.dart';
import 'package:buck/features/ai/data/services/buck_ai_service.dart';
import 'package:buck/features/ai/presentation/screens/ai_chat_sheet.dart';
import 'package:buck/features/ai/presentation/widgets/ai_floating_chat_bubble.dart';
import 'package:buck/features/ai/presentation/widgets/ai_report_dialog.dart';
import 'package:buck/features/expenses/presentation/add_expense_dialog.dart';
import 'package:buck/features/finance/data/finance_models.dart';
import 'package:buck/features/goals/data/goal_model.dart';

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

    test('categorize falls back locally when endpoints fail without session token', () async {
      final fakeClient = _FakeHttpClient((_) async => http.Response('Unauthorized', 401));
      final service = BuckAiService(client: fakeClient);

      final cats = await service.categorize(descriptions: ['Shell gas station']);
      expect(cats, ['Transportation']);

      await expectLater(
        () => service.getInsight(),
        throwsA(isA<BuckAiException>().having((e) => e.statusCode, 'statusCode', 401)),
      );
    });

    test('mapToMobileCategory uses whole-word boundaries and avoids substring false positives', () {
      expect(
        BuckAiService.mapToMobileCategory('', fallbackDescription: 'Business consulting fee'),
        'Other',
      );
      expect(
        BuckAiService.mapToMobileCategory('', fallbackDescription: 'Facebook Ads boost'),
        'Other',
      );
      expect(
        BuckAiService.mapToMobileCategory('', fallbackDescription: 'Parent allowance'),
        'Other',
      );
      expect(
        BuckAiService.mapToMobileCategory('', fallbackDescription: 'Bus ticket to work'),
        'Transportation',
      );
      expect(
        BuckAiService.mapToMobileCategory('', fallbackDescription: 'Clean Code book'),
        'Education',
      );
    });

    test('resetSessionState clears chatHistory and lastRegeneratedAt', () {
      final service = BuckAiService(
        client: _FakeHttpClient((_) async => http.Response('{}', 200)),
      );
      service.chatHistory.add(
        AiChatMessage(
          id: '1',
          text: 'Secret question',
          isUser: true,
          timestamp: DateTime.now(),
        ),
      );
      service.lastRegeneratedAt = DateTime.now();

      service.resetSessionState();

      expect(service.chatHistory, isEmpty);
      expect(service.lastRegeneratedAt, isNull);
    });

    test('streamChat throws BuckAiException on idle stream timeout', () async {
      final controller = StreamController<List<int>>();
      addTearDown(controller.close);

      final fakeClient = _FakeHttpClient.chunked((_) async {
        controller.add(utf8.encode('data: {"type": "delta", "text": "Part 1"}\n\n'));
        // Never emit 'done' or close controller so stream stalls.
        return http.StreamedResponse(
          controller.stream,
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final service = BuckAiService(
        client: fakeClient,
        requestTimeout: const Duration(milliseconds: 50),
      );

      expect(
        () => service.streamChat('Hello', token: 'test_token').toList(),
        throwsA(
          isA<BuckAiException>().having(
            (e) => e.message,
            'message',
            contains('timed out'),
          ),
        ),
      );
    });

    test('streamChat includes recent conversation turns on follow-up questions', () async {
      String? sentQuestion;
      final fakeClient = _FakeHttpClient.chunked((request) async {
        final body = jsonDecode((request as http.Request).body) as Map<String, dynamic>;
        sentQuestion = body['question'] as String?;
        return http.StreamedResponse(
          Stream.value(utf8.encode('data: {"type": "done"}\n\n')),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final service = BuckAiService(client: fakeClient);
      service.chatHistory.addAll([
        AiChatMessage(
          id: 'u1',
          text: 'What is my daily spending limit?',
          isUser: true,
          timestamp: DateTime.now(),
        ),
        AiChatMessage(
          id: 'a1',
          text: 'Your daily spending limit is ₱1,200.',
          isUser: false,
          timestamp: DateTime.now(),
        ),
      ]);

      await service.streamChat('What about next week?', token: 'test_token').toList();

      expect(sentQuestion, contains('Previous conversation:'));
      expect(sentQuestion, contains('User: What is my daily spending limit?'));
      expect(sentQuestion, contains('Advisor: Your daily spending limit is ₱1,200.'));
      expect(sentQuestion, contains('Current question: What about next week?'));
    });
  });

  group('BuckAiConstants Tests', () {
    test('aiUrl defaults to universal Supabase proxy URL and ignores trailing slash in .env', () {
      expect(
        BuckAiConstants.aiUrl,
        BuckAiConstants.supabaseAiProxyUrl,
      );
      expect(
        BuckAiConstants.resolveAiUrl('https://buck-web-ai.vercel.app/'),
        BuckAiConstants.supabaseAiProxyUrl,
      );
      expect(
        BuckAiConstants.resolveAiUrl('https://buck-web-ai.vercel.app'),
        BuckAiConstants.supabaseAiProxyUrl,
      );
      expect(
        BuckAiConstants.resolveAiUrl(''),
        BuckAiConstants.supabaseAiProxyUrl,
      );
      expect(
        BuckAiConstants.resolveAiUrl('https://custom-ai.example.com///'),
        'https://custom-ai.example.com',
      );
    });

    test('candidateEndpoints normalizes path, prioritizes Supabase proxy, and deduplicates', () {
      final fromLeadingSlash = BuckAiConstants.candidateEndpoints('/advisor/chat');
      final fromNoSlash = BuckAiConstants.candidateEndpoints('advisor/chat');

      expect(fromLeadingSlash, fromNoSlash);
      expect(
        fromLeadingSlash.first,
        '${BuckAiConstants.supabaseAiProxyUrl}/advisor/chat',
      );
      expect(
        Uri.parse(fromLeadingSlash.first).path,
        contains('/advisor/chat'),
      );
      expect(
        fromLeadingSlash.last,
        'https://buck-web-ai.vercel.app/advisor/chat',
      );
      expect(fromLeadingSlash.toSet().length, fromLeadingSlash.length);

      final webTunnelEndpoints = BuckAiConstants.buildCandidateEndpoints(
        'advisor/chat',
        isWeb: true,
        baseUri: Uri.parse('https://buck-phone.loca.lt/home'),
      );
      expect(webTunnelEndpoints, [
        '${BuckAiConstants.supabaseAiProxyUrl}/advisor/chat',
        'https://buck-phone.loca.lt/advisor/chat',
        'https://buck-web-ai.vercel.app/advisor/chat',
      ]);

      final webVercelEndpoints = BuckAiConstants.buildCandidateEndpoints(
        '/advisor/chat',
        isWeb: true,
        baseUri: Uri.parse('https://bucktbt.vercel.app/'),
      );
      expect(webVercelEndpoints, [
        '${BuckAiConstants.supabaseAiProxyUrl}/advisor/chat',
        'https://buck-web-ai.vercel.app/advisor/chat',
      ]);
    });
  });

  group('BuckAiService Failover & Live Supabase Fallback Tests', () {
    SupabaseAdvisorContext buildSampleContext({
      List<AiAdvisory> advisories = const [],
      bool emptyAccount = false,
    }) {
      final now = DateTime(2026, 11, 15, 10, 0);
      if (emptyAccount) {
        return SupabaseAdvisorContext(
          profileName: 'New User',
          activeWalletId: 'w-empty',
          wallets: const [Wallet(id: 'w-empty', name: 'Cash', balance: 0)],
          now: now,
        );
      }
      return SupabaseAdvisorContext(
        profileName: 'Alex',
        activeWalletId: 'w-main',
        wallets: const [
          Wallet(id: 'w-main', name: 'Main Wallet', balance: 8000),
          Wallet(id: 'w-sav', name: 'Savings', balance: 12000),
        ],
        expenses: [
          ExpenseRecord(
            id: 'e1',
            walletId: 'w-main',
            categoryName: 'Food',
            amount: 2500,
            description: 'Groceries and lunch',
            spentOn: DateTime(2026, 11, 10),
          ),
          ExpenseRecord(
            id: 'e2',
            walletId: 'w-main',
            categoryName: 'Transportation',
            amount: 900,
            description: 'Grab rides',
            spentOn: DateTime(2026, 11, 12),
          ),
        ],
        incomes: [
          IncomeRecord(
            id: 'i1',
            walletId: 'w-main',
            source: 'Salary',
            amount: 20000,
            receivedOn: DateTime(2026, 11, 5),
          ),
        ],
        goals: const [
          GoalItem(
            id: 'g1',
            title: 'Emergency Fund',
            targetDate: 'Target: Jun 2027',
            status: GoalStatus.onTrack,
            currentAmount: 5000,
            targetAmount: 20000,
            icon: Icons.shield_outlined,
            themeColor: Colors.orange,
            gradientColors: [Colors.orange, Colors.deepOrange],
          ),
        ],
        advisories: advisories,
        latestAdvisoryCreatedAt: '2026-11-14T08:00:00Z',
        now: now,
      );
    }

    test('getInsight fails over across candidate endpoints on 403 and sends apikey to non-vercel endpoints', () async {
      final visitedHosts = <String>[];
      final seenApiKeys = <String, String?>{};
      final fakeClient = _FakeHttpClient((request) async {
        visitedHosts.add(request.url.host);
        seenApiKeys[request.url.host] = request.headers['apikey'];
        if (request.url.host.endsWith('.supabase.co')) {
          return http.Response('{"error":"gateway blocked"}', 403);
        }
        return http.Response(
          jsonEncode({
            'id': 'ins-failover',
            'title': 'Recovered Insight',
            'suggestion': 'Keep pacing steady',
            'advice': 'Fallback endpoint responded',
            'financialHealthScore': 82,
            'priority': 'low',
            'focus': 'savings',
            'walletAdvice': 'Protect Savings wallet',
            'generatedWith': 'gemini',
            'createdAt': '2026-11-15T06:00:00Z',
          }),
          200,
        );
      });

      final service = BuckAiService(
        client: fakeClient,
        useCandidateEndpoints: true,
      );
      final insight = await service.getInsight(token: 'jwt-123');

      expect(insight.id, 'ins-failover');
      expect(visitedHosts, [
        'glnuzqmnmzuxgujmxigx.supabase.co',
        'buck-web-ai.vercel.app',
      ]);
      expect(
        seenApiKeys['glnuzqmnmzuxgujmxigx.supabase.co'],
        SupabaseConstants.anonKey,
      );
      expect(seenApiKeys['buck-web-ai.vercel.app'], isNull);
    });

    test('getInsight rethrows 401 immediately without failing over or falling back to Supabase', () async {
      var requestCount = 0;
      var fallbackCalled = false;
      final fakeClient = _FakeHttpClient((_) async {
        requestCount++;
        return http.Response('{"detail":"Invalid JWT"}', 401);
      });

      final service = BuckAiService(
        client: fakeClient,
        useCandidateEndpoints: true,
        liveSupabaseContextLoader: () async {
          fallbackCalled = true;
          return buildSampleContext();
        },
      );

      await expectLater(
        () => service.getInsight(token: 'expired-jwt'),
        throwsA(
          isA<BuckAiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
      expect(requestCount, 1);
      expect(fallbackCalled, isFalse);
    });

    test('streamChat fails over cleanly on SSE error before deltas and falls back to Live Supabase Advisor when all HTTP endpoints fail', () async {
      // Case 1: SSE error on candidate 1 before any delta -> failover to candidate 2
      var attempt = 0;
      final failoverClient = _FakeHttpClient.chunked((request) async {
        attempt++;
        if (attempt == 1) {
          return http.StreamedResponse(
            Stream.value(
              utf8.encode('data: {"type":"error","message":"Upstream down"}\n\n'),
            ),
            200,
            headers: {'content-type': 'text/event-stream'},
          );
        }
        return http.StreamedResponse(
          Stream.fromIterable([
            utf8.encode('data: {"type":"delta","text":"Recovered "}\n\n'),
            utf8.encode('data: {"type":"delta","text":"reply"}\n\n'),
            utf8.encode('data: {"type":"done"}\n\n'),
          ]),
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });

      final failoverService = BuckAiService(
        client: failoverClient,
        useCandidateEndpoints: true,
      );
      final tokens = await failoverService
          .streamChat('How is my spending?', token: 'jwt-123')
          .toList();
      expect(tokens.join(), 'Recovered reply');
      expect(attempt, 2);

      // Case 2: All HTTP endpoints fail -> Live Supabase Advisor streams real context
      final offlineClient = _FakeHttpClient.chunked((_) async {
        return http.StreamedResponse(
          Stream.value(utf8.encode('Bad Gateway')),
          502,
        );
      });
      final fallbackService = BuckAiService(
        client: offlineClient,
        useCandidateEndpoints: true,
        liveSupabaseContextLoader: () async => buildSampleContext(),
      );
      final fallbackText = (await fallbackService
              .streamChat("What's my daily spending limit?", token: 'jwt-123')
              .toList())
          .join();

      expect(fallbackText, contains('Main Wallet'));
      expect(fallbackText, contains('₱8,000.00'));
      expect(fallbackText, contains('₱20,000.00'));
      expect(fallbackText, contains('₱3,400.00'));
      expect(fallbackText, contains('₱500.00/day'));
      expect(fallbackText, contains('Food'));
      expect(fallbackText, contains('Emergency Fund'));
    });

    test('Live Supabase Advisor fallback handles onboarding, advisories/synthesis in getInsight, and getGoalTip', () async {
      final failingClient = _FakeHttpClient((_) async => http.Response('Down', 503));

      // 1) Empty ₱0.00 account onboarding guidance
      final emptyCtx = buildSampleContext(emptyAccount: true);
      final emptyReply = BuckAiService.buildSupabaseChatReply('Help', emptyCtx);
      expect(emptyReply, contains('₱0.00'));
      expect(emptyReply, contains('Fund a wallet'));

      final emptyInsight = BuckAiService.buildSupabaseInsight(emptyCtx);
      expect(emptyInsight.generatedWith, 'supabase-local');
      expect(emptyInsight.financialHealthScore, isNull);

      // 2) Saved ai_advisories row used when refresh=false; synthesized when refresh=true
      final serviceWithAdvisory = BuckAiService(
        client: failingClient,
        useCandidateEndpoints: true,
        liveSupabaseContextLoader: () async => buildSampleContext(
          advisories: const [
            AiAdvisory(
              id: 'adv-99',
              title: 'Trim Dining Out',
              suggestion: 'Cook twice a week to save ₱1,000.',
              advice: 'Food is your largest expense this month.',
            ),
          ],
        ),
      );

      final cachedFallback = await serviceWithAdvisory.getInsight(token: 'jwt-123');
      expect(cachedFallback.id, 'adv-99');
      expect(cachedFallback.title, 'Trim Dining Out');
      expect(cachedFallback.generatedWith, 'supabase-local');
      expect(cachedFallback.financialHealthScore, isNotNull);

      final refreshedFallback = await serviceWithAdvisory.getInsight(
        refresh: true,
        token: 'jwt-123',
      );
      expect(refreshedFallback.generatedWith, 'supabase-local');
      expect(refreshedFallback.cached, isFalse);
      expect(serviceWithAdvisory.lastRegeneratedAt, isNotNull);

      // 3) getGoalTip uses targetAmount, goalName, and live wallet balance
      final goalTip = await serviceWithAdvisory.getGoalTip(
        goalId: 'g1',
        goalName: 'Emergency Fund',
        targetAmount: 20000,
        token: 'jwt-123',
      );
      expect(goalTip, contains('Emergency Fund'));
      expect(goalTip, contains('Main Wallet'));
      expect(goalTip, contains('₱8,000.00'));
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

    testWidgets('Closing AiChatSheet mid-stream finalizes message so reopening is not stuck', (tester) async {
      final streamController = StreamController<List<int>>();
      addTearDown(streamController.close);

      final fakeClient = _FakeHttpClient.chunked((_) async {
        return http.StreamedResponse(
          streamController.stream,
          200,
          headers: {'content-type': 'text/event-stream'},
        );
      });
      final aiService = BuckAiService(client: fakeClient);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (ctx) => ElevatedButton(
                onPressed: () => showAiChatSheet(ctx, aiService: aiService),
                child: const Text('Open Chat'),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('Open Chat'));
      await tester.pumpAndSettle();

      // Tap a quick prompt to start streaming
      await tester.tap(find.text('How is my spending looking this month?'));
      await tester.pump();

      expect(find.text('Buck AI is thinking...'), findsOneWidget);

      // Dismiss the sheet mid-stream via the close button
      await tester.tap(find.byIcon(Icons.close));
      await tester.pumpAndSettle();

      // Verify no message in chatHistory is stuck with isStreaming == true
      expect(aiService.chatHistory.any((m) => m.isStreaming), isFalse);

      // Reopen the sheet and verify 'Buck AI is thinking...' is not stuck
      await tester.tap(find.text('Open Chat'));
      await tester.pumpAndSettle();
      expect(find.text('Buck AI is thinking...'), findsNothing);
    });

    testWidgets('AiFloatingChatBubble eases to closest horizontal edge on release', (tester) async {
      tester.view.physicalSize = const Size(800, 600);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: Stack(
              children: [
                Positioned.fill(
                  child: AiFloatingChatBubble(),
                ),
              ],
            ),
          ),
        ),
      );

      final visualBubbleFinder = find.descendant(
        of: find.byType(AiFloatingChatBubble),
        matching: find.byType(GestureDetector),
      );
      expect(tester.getCenter(visualBubbleFinder).dx, closeTo(756.0, 0.5));

      // Drag into the left half of the screen and release.
      await tester.drag(visualBubbleFinder, const Offset(-450, -100));
      // Mid-animation check: should still be easing toward the left edge (18 + 26 = 44).
      await tester.pump(const Duration(milliseconds: 120));
      final midDx = tester.getCenter(visualBubbleFinder).dx;
      expect(midDx, greaterThan(44.0));
      expect(midDx, lessThan(400.0));

      // After easing completes, it settles cleanly at the left edge.
      await tester.pumpAndSettle();
      expect(tester.getCenter(visualBubbleFinder).dx, closeTo(44.0, 0.5));

      // Drag slightly toward the center (staying in left half) -> returns to left edge.
      await tester.drag(visualBubbleFinder, const Offset(150, 0));
      await tester.pumpAndSettle();
      expect(tester.getCenter(visualBubbleFinder).dx, closeTo(44.0, 0.5));

      // Drag past the midline into the right half -> eases to right edge.
      await tester.drag(visualBubbleFinder, const Offset(500, 0));
      await tester.pumpAndSettle();
      expect(tester.getCenter(visualBubbleFinder).dx, closeTo(756.0, 0.5));
    });
  });
}
