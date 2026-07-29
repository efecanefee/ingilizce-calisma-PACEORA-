import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/gemini_service.dart';
import 'package:paceora/data/lesson_models.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lessonJson = '''
{
  "vocab": [],
  "gapFill": [
    {
      "sentence": "I ___ tea.",
      "answer": "drink",
      "options": ["drink", "drinks"],
      "hintTr": "Çay içerim."
    }
  ],
  "translate": [],
  "quiz": []
}
''';

/// İstek sayısını da tutan sahte Gemini istemcisi.
class _StubGemini {
  int requestCount = 0;

  http.Client get client => MockClient((request) async {
        requestCount++;
        final body = jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': _lessonJson},
                ],
              },
            },
          ],
        });
        return http.Response.bytes(utf8.encode(body), 200);
      });
}

Future<ProviderContainer> _container({
  required AppDatabase db,
  GeminiService? gemini,
}) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();

  return ProviderContainer.test(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      databaseProvider.overrideWithValue(db),
      if (gemini != null) geminiServiceProvider.overrideWithValue(gemini),
    ],
  );
}

void main() {
  late AppDatabase db;
  late Repository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = Repository(db);
  });

  tearDown(() => db.close());

  group('weekPlanProvider', () {
    test('plan yoksa kendiliğinden üretilir', () async {
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      expect(await repository.planForWeek(DateTime.now()), isEmpty);

      final container = await _container(db: db);
      final plan = await container.read(weekPlanProvider.future);

      // Anahtar yok → yerleşik yedek program yazıldı.
      expect(plan.days, hasLength(7));
      expect(plan.offline, isTrue);
      expect(await repository.planForWeek(DateTime.now()), hasLength(7));
    });

    test('profil yoksa üretmeye kalkışmaz', () async {
      final container = await _container(db: db);
      final plan = await container.read(weekPlanProvider.future);

      expect(plan.days, isEmpty);
      expect(await db.select(db.weeklyPlanDays).get(), isEmpty);
    });

    test('mevcut plan varsa yeniden üretilmez', () async {
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      await repository.replaceWeeklyPlan(DateTime.now(), [
        const PlanDaySpec(grammarTopic: 'Mevcut', vocabTheme: 'Tema'),
      ]);

      final container = await _container(db: db);
      final plan = await container.read(weekPlanProvider.future);

      expect(plan.days, hasLength(1));
      expect(plan.days.single.grammarTopic, 'Mevcut');
    });
  });

  group('lessonProvider', () {
    test('aynı gün ikinci açılışta Gemini\'ye tekrar gitmez', () async {
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      await repository.replaceWeeklyPlan(DateTime.now(), [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
      ]);

      final stub = _StubGemini();
      final container = await _container(
        db: db,
        gemini: GeminiService(client: stub.client, apiKey: 'test-key'),
      );
      // lessonProvider auto-dispose; dinleyici olmadan okuma arasında atılıyor.
      container.listen(lessonProvider, (_, _) {});

      final first = await container.read(lessonProvider.future);
      expect(first.lesson.questionCount, 1);
      expect(stub.requestCount, 1);

      // Ders ekranı kapanıp yeniden açılmış gibi provider'ı tazele.
      container.invalidate(lessonProvider);
      final second = await container.read(lessonProvider.future);

      expect(second.lesson.questionCount, 1);
      expect(stub.requestCount, 1, reason: 'veritabanındaki ders kullanılmalı');
    });

    test('yarıda bırakılan ders kaldığı adımdan devam eder', () async {
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      await repository.replaceWeeklyPlan(DateTime.now(), [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
      ]);

      final stub = _StubGemini();
      final container = await _container(
        db: db,
        gemini: GeminiService(client: stub.client, apiKey: 'test-key'),
      );
      // lessonProvider auto-dispose; dinleyici olmadan okuma arasında atılıyor.
      container.listen(lessonProvider, (_, _) {});

      await container.read(lessonProvider.future);
      await container
          .read(lessonProvider.notifier)
          .answer(gapFillKey(0), correct: true, input: 'drink');
      await container.read(lessonProvider.notifier).goToStep(1);

      container.invalidate(lessonProvider);
      final resumed = await container.read(lessonProvider.future);

      expect(resumed.progress.stepIndex, 1);
      expect(resumed.correctCount, 1);
      expect(stub.requestCount, 1);
    });

    test('anahtar yokken ders üretilemez ve anlaşılır hata döner', () async {
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      await repository.replaceWeeklyPlan(DateTime.now(), [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
      ]);

      final container = await _container(db: db);
      container.listen(lessonProvider, (_, _) {});

      await expectLater(
        container.read(lessonProvider.future),
        throwsA(
          isA<LessonUnavailable>().having(
            (e) => e.message,
            'message',
            contains('GEMINI_API_KEY'),
          ),
        ),
      );
    });
  });
}
