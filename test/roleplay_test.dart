import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/gemini_service.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/data/rewards.dart';
import 'package:paceora/data/roleplay.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scroll_helper.dart';

String _content(Object json) => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': jsonEncode(json)},
        ],
      },
    },
  ],
});

String _modelList() => jsonEncode({
  'models': [
    {
      'name': 'models/gemini-3.5-flash-lite',
      'supportedGenerationMethods': ['generateContent'],
    },
  ],
});

/// Gönderilen istemi döner.
String _promptOf(http.Request r) {
  final body = jsonDecode(r.body) as Map<String, dynamic>;
  final parts = ((body['contents'] as List).first as Map)['parts'] as List;
  return (parts.first as Map)['text'] as String;
}

Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('RoleplayTurn', () {
    test('hatalı mesaj düzeltmeyle gelir', () {
      final t = parseRoleplayResponse(
        _content({
          'reply': 'Sure! Anything else?',
          'hasError': true,
          'corrected': 'I would like a coffee.',
          'explanationTr': '"coffe" değil "coffee" yazılır.',
          'goalReached': false,
        }),
      )!;
      expect(t.reply, 'Sure! Anything else?');
      expect(t.correction?.corrected, 'I would like a coffee.');
      expect(t.goalReached, isFalse);
    });

    test('hata yoksa ya da düzeltme boşsa correction null', () {
      final ok = parseRoleplayResponse(
        _content({'reply': 'Great.', 'hasError': false, 'goalReached': true}),
      )!;
      expect(ok.correction, isNull);
      expect(ok.goalReached, isTrue);
      final empty = parseRoleplayResponse(
        _content({'reply': 'Hm.', 'hasError': true, 'corrected': ''}),
      )!;
      expect(empty.correction, isNull);
    });

    test('cevapsız yanıt reddedilir', () {
      expect(parseRoleplayResponse(_content({'hasError': false})), isNull);
      expect(parseRoleplayResponse('{}'), isNull);
    });
  });

  test('senaryolar benzersiz ve dolu', () {
    final ids = roleplayScenarios.map((s) => s.id).toSet();
    expect(ids, hasLength(roleplayScenarios.length));
    for (final s in roleplayScenarios) {
      expect(s.opening, isNotEmpty);
      expect(s.task, isNotEmpty);
      expect(scenarioById(s.id), same(s));
    }
    expect(scenarioById('yok'), isNull);
  });

  test('kayıtlar: kısa sohbet XP vermez, görev bonusu ve rozet', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(
      await RoleplayRecords.save(
        prefs,
        scenarioId: 'cafe',
        userMessages: roleplayMinMessages - 1,
        goalReached: true,
      ),
      0,
    );
    expect(RoleplayRecords.read(prefs).completed, 0);

    for (var i = 0; i < 5; i++) {
      await RoleplayRecords.save(
        prefs,
        scenarioId: i.isEven ? 'cafe' : 'hotel',
        userMessages: 6,
        goalReached: i < 2,
      );
    }
    final r = RoleplayRecords.read(prefs);
    expect(r.completed, 5);
    expect(r.xp, 25 + 25 + 15 * 3);
    expect(r.goalScenarios, {'cafe', 'hotel'});

    final game = GameState(GameStats(roleplayXp: r.xp, roleplays: r.completed));
    expect(totalXp(game.stats), 95);
    expect(game.earnedBadgeIds, contains('chatter_5'));
  });

  test('istem karakteri, görevi ve konuşmayı içerir', () async {
    String? prompt;
    final service = GeminiService(
      apiKey: 'k',
      retryDelay: Duration.zero,
      client: MockClient((r) async {
        if (r.method == 'GET') return http.Response(_modelList(), 200);
        prompt = _promptOf(r);
        return http.Response.bytes(
          utf8.encode(_content({'reply': 'Sure.', 'hasError': false})),
          200,
        );
      }),
    );
    addTearDown(service.dispose);
    final scenario = scenarioById('cafe')!;

    final result = await service.roleplayTurn(
      scenario: scenario,
      level: 'B1',
      history: [
        ChatMessage(Speaker.ai, scenario.opening),
        const ChatMessage(Speaker.user, 'A latte please'),
      ],
    );
    expect(result.turn?.reply, 'Sure.');
    expect(prompt, contains(scenario.aiRole));
    expect(prompt, contains(scenario.task));
    expect(prompt, contains('STUDENT: A latte please'));
    expect(prompt, contains('CHARACTER: ${scenario.opening}'));
  });

  group('ekran', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = Repository(db);
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      await repository.replaceWeeklyPlan(DateTime.now(), [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
      ]);
    });
    tearDown(() => db.close());

    /// Sahte Gemini: [replies] sırayla döner; null öğe 500 hatası verir.
    Future<SharedPreferences> openCafe(
      WidgetTester tester,
      List<Map<String, Object>?> replies,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      var turn = 0;
      final service = GeminiService(
        apiKey: 'k',
        retryDelay: Duration.zero,
        client: MockClient((r) async {
          if (r.method == 'GET') return http.Response(_modelList(), 200);
          final reply = replies[turn++];
          if (reply == null) return http.Response('down', 500);
          return http.Response.bytes(utf8.encode(_content(reply)), 200);
        }),
      );
      addTearDown(service.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
            geminiServiceProvider.overrideWithValue(service),
          ],
          child: const PaceoraApp(onboardingDone: true),
        ),
      );
      await _advance(tester);
      await openPracticeTab(tester);
      await tester.scrollUntilVisible(
        find.text('AI ile sohbet'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await _advance(tester);
      await tester.tap(find.text('AI ile sohbet'));
      await _advance(tester);
      await tester.tap(find.text('Kafede sipariş'));
      await _advance(tester);
      return prefs;
    }

    Future<void> say(WidgetTester tester, String text) async {
      await tester.enterText(find.byType(TextField), text);
      await tester.pump();
      await tester.tap(find.byTooltip('Gönder'));
      await _advance(tester);
    }

    testWidgets('sohbet: düzeltme, görev ve bitiriş', (tester) async {
      final prefs = await openCafe(tester, [
        {
          'reply': 'Of course. Anything to eat?',
          'hasError': true,
          'corrected': 'I would like a coffee.',
          'explanationTr': '"coffe" değil "coffee".',
          'goalReached': false,
        },
        {'reply': 'A muffin, great.', 'hasError': false, 'goalReached': false},
        {'reply': 'That is 6 pounds.', 'hasError': false, 'goalReached': false},
        {'reply': 'Thank you, enjoy!', 'hasError': false, 'goalReached': true},
      ]);

      expect(
        find.text(scenarioById('cafe')!.opening),
        findsOneWidget,
        reason: 'karakter ilk cümleyle başlar',
      );

      await say(tester, 'I would like a coffe.');
      expect(find.text('Of course. Anything to eat?'), findsOneWidget);
      expect(find.text('I would like a coffee.'), findsOneWidget);
      expect(find.text('"coffe" değil "coffee".'), findsOneWidget);

      await say(tester, 'A blueberry muffin, please.');
      await say(tester, 'How much is it?');
      await say(tester, 'Here you are.');
      expect(find.textContaining('Görev tamamlandı'), findsOneWidget);

      await tester.tap(find.text('Bitir'));
      await _advance(tester);
      expect(find.text('Görev tamamlandı!'), findsOneWidget);
      expect(find.text('+25 XP · 4 mesaj'), findsOneWidget);

      expect(prefs.getInt(RoleplayRecords.completedKey), 1);
      expect(prefs.getStringList(RoleplayRecords.goalsKey), ['cafe']);
      final mistakes = await db.select(db.mistakes).get();
      expect(mistakes, hasLength(1));
      expect(mistakes.single.type, 'chat');
      expect(mistakes.single.item, 'I would like a coffee.');
      expect(mistakes.single.context, contains('I would like a coffe.'));
    });

    testWidgets('hata olunca tekrar denenir; bitirmeden çıkarken sorulur', (
      tester,
    ) async {
      // Servis 5xx'te aynı modeli bir kez daha dener: iki hata = başarısız tur.
      final prefs = await openCafe(tester, [
        null,
        null,
        {'reply': 'Sure thing.', 'hasError': false, 'goalReached': false},
      ]);

      await say(tester, 'A tea, please.');
      expect(find.text('Tekrar dene'), findsOneWidget);
      await tester.tap(find.text('Tekrar dene'));
      await _advance(tester);
      expect(find.text('Sure thing.'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsNothing);

      // Geri tuşu: kayıt yapılmadan çıkmadan önce sorar.
      final navigator = tester.state<NavigatorState>(
        find.byType(Navigator).last,
      );
      await navigator.maybePop();
      await _advance(tester);
      expect(find.text('Sohbeti bitirelim mi?'), findsOneWidget);
      await tester.tap(find.text('Kaydetmeden çık'));
      await _advance(tester);
      expect(find.text('Kafede sipariş'), findsOneWidget);
      expect(prefs.getInt(RoleplayRecords.completedKey), isNull);
    });
  });
}
