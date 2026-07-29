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
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Animasyonlu göstergeler yüzünden pumpAndSettle takılmasın diye
/// sabit sayıda kare ilerletip sonra oturmasını bekler.
Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Her bölümde tek soruluk, tahmin edilebilir bir ders.
const _lessonJson = '''
{
  "vocab": [
    {"word": "commute", "meaning": "işe gidip gelmek", "example": "I commute by train."}
  ],
  "gapFill": [
    {
      "sentence": "I ___ to work every day.",
      "answer": "commute",
      "options": ["commute", "commutes"],
      "hintTr": "Her gün işe giderim."
    }
  ],
  "translate": [
    {"tr": "Mutluyum.", "en": "I am happy.", "accepted": []}
  ],
  "quiz": [
    {
      "question": "Which sentence is correct?",
      "options": ["He commute", "He commutes"],
      "answerIndex": 1,
      "explanationTr": "Üçüncü tekil şahısta fiile -s eklenir."
    }
  ]
}
''';

/// Gemini yerine sabit bir ders döndüren istemci.
http.Client _stubClient() => MockClient((request) async {
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

void main() {
  testWidgets('ders akışı: sorular çözülür, skor ve streak kaydedilir',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    // Onboarding'i tekrarlamamak için profil ve bu haftanın planı hazır.
    final repository = Repository(db);
    await repository.saveProfile(name: 'Efecan', level: 'B1', dailyMinutes: 10);
    await repository.replaceWeeklyPlan(DateTime.now(), [
      for (var i = 0; i < 7; i++)
        PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(
            GeminiService(client: _stubClient(), apiKey: 'test-key'),
          ),
        ],
        child: const PaceoraApp(onboardingDone: true),
      ),
    );
    await _advance(tester);

    expect(find.text('Merhaba, Efecan'), findsOneWidget);

    // Derse gir.
    await tester.tap(find.text('Bugünü çalış'));
    await _advance(tester);

    // 1. adım: kelimeler — puanlanmaz, doğrudan devam edilir.
    expect(find.text('KELİMELER'), findsOneWidget);
    expect(find.text('commute'), findsOneWidget);
    expect(find.text('işe gidip gelmek'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Devam'));
    await _advance(tester);

    // 2. adım: boşluk doldurma — doğru seçenek.
    expect(find.text('BOŞLUK DOLDUR'), findsOneWidget);
    expect(find.text('1. I ___ to work every day.'), findsOneWidget);
    // Cevaplanmadan devam edilemez.
    expect(
      tester.widget<FilledButton>(find.widgetWithText(FilledButton, 'Devam')).enabled,
      isFalse,
    );
    await tester.tap(find.text('commute'));
    await _advance(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Devam'));
    await _advance(tester);

    // 3. adım: çeviri — kısaltmalı yazım da doğru sayılmalı.
    expect(find.text('ÇEVİRİ'), findsOneWidget);
    await tester.enterText(find.byType(TextField), "I'm happy");
    await tester.tap(find.widgetWithText(FilledButton, 'Kontrol et'));
    await _advance(tester);
    expect(find.text('Doğru'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Devam'));
    await _advance(tester);

    // 4. adım: test — açıklama cevaptan sonra görünür.
    expect(find.text('TEST'), findsOneWidget);
    expect(find.text('Üçüncü tekil şahısta fiile -s eklenir.'), findsNothing);
    await tester.tap(find.text('He commutes'));
    await _advance(tester);
    expect(find.text('Üçüncü tekil şahısta fiile -s eklenir.'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Sonucu gör'));
    await _advance(tester);

    // Sonuç ekranı
    expect(find.text('%100'), findsOneWidget);
    expect(find.text('3/3 doğru'), findsOneWidget);
    expect(find.text('Tüm soruları doğru yaptın.'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Dersi bitir'));
    await _advance(tester);

    // Ana ekrana dönüldü: gün tamamlandı, streak arttı.
    expect(find.text('Merhaba, Efecan'), findsOneWidget);
    expect(find.text('1 gün'), findsOneWidget);
    expect(find.textContaining('Ders tamam · %100'), findsOneWidget);

    // Kalıcı taraf
    final lesson = await repository.lessonFor(DateTime.now());
    expect(lesson, isNotNull);
    expect(lesson!.completed, isTrue);
    expect(lesson.score, 100);
    expect((await repository.profile())?.streak, 1);
    // Hepsi doğru olduğu için hata defteri boş kalmalı.
    expect(await db.select(db.mistakes).get(), isEmpty);
  });

  testWidgets('yanlış cevap hata defterine yazılır ve skora yansır',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final repository = Repository(db);
    await repository.saveProfile(name: 'Efecan', level: 'B1', dailyMinutes: 10);
    await repository.replaceWeeklyPlan(DateTime.now(), [
      for (var i = 0; i < 7; i++)
        PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
    ]);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(
            GeminiService(client: _stubClient(), apiKey: 'test-key'),
          ),
        ],
        child: const PaceoraApp(onboardingDone: true),
      ),
    );
    await _advance(tester);

    await tester.tap(find.text('Bugünü çalış'));
    await _advance(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Devam'));
    await _advance(tester);

    // Boşluk doldurmada yanlış seçenek
    await tester.tap(find.text('commutes'));
    await _advance(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Devam'));
    await _advance(tester);

    // Çeviride yanlış cevap
    await tester.enterText(find.byType(TextField), 'I am sad');
    await tester.tap(find.widgetWithText(FilledButton, 'Kontrol et'));
    await _advance(tester);
    expect(find.text('Beklenen cevap'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Devam'));
    await _advance(tester);

    // Testte doğru cevap
    await tester.tap(find.text('He commutes'));
    await _advance(tester);
    await tester.tap(find.widgetWithText(FilledButton, 'Sonucu gör'));
    await _advance(tester);

    expect(find.text('%33'), findsOneWidget);
    expect(find.text('1/3 doğru'), findsOneWidget);
    expect(find.text('Tekrar edilecekler'), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Dersi bitir'));
    await _advance(tester);

    final mistakes = await db.select(db.mistakes).get();
    expect(mistakes, hasLength(2));
    expect(
      mistakes.map((m) => m.item).toSet(),
      {'commute', 'I am happy.'},
    );
    expect(mistakes.every((m) => m.resolved == false), isTrue);

    // Bu hatalar sonraki dersin promptuna beslenir.
    expect(await repository.unresolvedMistakeItems(), hasLength(2));
  });
}
