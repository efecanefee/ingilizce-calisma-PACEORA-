import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/lesson_models.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/data/story_models.dart';
import 'package:paceora/data/word_lookup.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tekrarlayan animasyonlar yüzünden pumpAndSettle oturmaz; sabit kare.
Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _scrollTo(WidgetTester tester, Finder finder) async {
  await tester.scrollUntilVisible(
    finder,
    300,
    scrollable: find.byType(Scrollable).first,
  );
  await _advance(tester);
}

void main() {
  late AppDatabase db;
  late Repository repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = Repository(db);
    await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
    await repository.replaceWeeklyPlan(DateTime.now(), [
      for (var i = 0; i < 7; i++)
        PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
    ]);
  });

  tearDown(() => db.close());

  Future<void> pumpApp(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: const PaceoraApp(onboardingDone: true),
      ),
    );
    await _advance(tester);
  }

  testWidgets('günün hikayesi: okunur, cevaplanır, skor gösterilir', (
    tester,
  ) async {
    // Kayıtlı hikaye: ekran Gemini'ye gitmeden kaldığı yerden açar.
    await repository.saveStory(
      DateTime.now(),
      const StoryState(
        story: DailyStory(
          title: 'The Lost Key',
          paragraphs: ['Ali lost his key in the park.'],
          glossary: [GlossaryItem(word: 'lose', meaning: 'kaybetmek')],
          questions: [
            QuizItem(
              question: 'Where did Ali lose his key?',
              options: ['At home', 'In the park'],
              answer: 'In the park',
              explanationTr: 'Metin parkta kaybettiğini söylüyor.',
            ),
          ],
        ),
      ),
    );
    await pumpApp(tester);

    // "Günün hikayesi" hem hedef listesinde hem kutucukta geçer; kutucuğun
    // alt başlığı tekildir.
    await _scrollTo(tester, find.text('Oku ve anla'));
    await tester.tap(find.text('Oku ve anla'));
    await _advance(tester);

    expect(find.text('The Lost Key'), findsOneWidget);
    expect(find.text('Ali lost his key in the park.'), findsOneWidget);
    expect(find.text('0/1'), findsOneWidget);

    await _scrollTo(tester, find.text('In the park'));
    await tester.tap(find.text('In the park'));
    await _advance(tester);

    expect(find.text('Metin parkta kaybettiğini söylüyor.'), findsOneWidget);
    await _scrollTo(tester, find.textContaining('soruyu doğru cevapladın'));
    expect(find.text('%100'), findsOneWidget);

    final saved = await repository.storyFor(DateTime.now());
    expect(saved!.quizScore, 100);
  });

  group('günün hikayesi: dokun-çevir', () {
    Future<void> openStory(WidgetTester tester) async {
      await repository.saveStory(
        DateTime.now(),
        const StoryState(
          story: DailyStory(
            title: 'The Lost Key',
            paragraphs: ['Ali lost his key in the park. He was sad.'],
            glossary: [GlossaryItem(word: 'key', meaning: 'anahtar')],
            questions: [
              QuizItem(
                question: 'Where?',
                options: ['Home', 'Park'],
                answer: 'Park',
                explanationTr: '',
              ),
            ],
          ),
          lookups: {
            'lost': WordMeaning(
              word: 'lose',
              meaning: 'kaybetmek',
              partOfSpeech: 'fiil',
            ),
          },
        ),
      );
      await pumpApp(tester);
      await _scrollTo(tester, find.text('Oku ve anla'));
      await tester.tap(find.text('Oku ve anla'));
      await _advance(tester);
    }

    Future<void> tapWord(WidgetTester tester, String word) async {
      await tester.tapOnText(find.textRange.ofSubstring(word).first);
      await _advance(tester);
    }

    testWidgets('sözlükçedeki kelime havuza eklenir', (tester) async {
      await openStory(tester);
      await tapWord(tester, 'key');

      expect(find.text('anahtar'), findsWidgets);
      expect(find.text('“Ali lost his key in the park.”'), findsOneWidget);

      await tester.tap(find.text('Kelime havuzuna ekle'));
      await _advance(tester);

      expect(find.text('Kelime havuzunda'), findsOneWidget);
      final cards = await db.select(db.flashcards).get();
      expect(cards, hasLength(1));
      expect(cards.single.word, 'key');
      expect(cards.single.meaning, 'anahtar');
      expect(cards.single.source, 'story');
      expect(cards.single.exampleSentence, 'Ali lost his key in the park.');
    });

    testWidgets('önbellekteki çeviri sözlük biçimiyle gösterilir', (
      tester,
    ) async {
      await repository.addFlashcards([
        (word: 'lose', meaning: 'kaybetmek', example: ''),
      ], source: 'new_word');
      await openStory(tester);
      await tapWord(tester, 'lost');

      expect(find.text('kaybetmek'), findsOneWidget);
      expect(find.text('fiil'), findsOneWidget);
      expect(find.text('Sözlük biçimi: lose'), findsOneWidget);
      // Kart zaten destede.
      expect(find.text('Kelime havuzunda'), findsOneWidget);
    });

    testWidgets('anahtar yoksa hata ve tekrar dene gösterilir', (tester) async {
      await openStory(tester);
      await tapWord(tester, 'sad');

      expect(find.textContaining('GEMINI_API_KEY'), findsOneWidget);
      expect(find.text('Tekrar dene'), findsOneWidget);
      final button = tester.widget<FilledButton>(
        find.ancestor(
          of: find.text('Kelime havuzuna ekle'),
          matching: find.byWidgetPredicate((w) => w is FilledButton),
        ),
      );
      expect(button.onPressed, isNull);
    });
  });

  group('Kelime Rallisi', () {
    final pairs = {
      'apple': 'elma',
      'house': 'ev',
      'river': 'nehir',
      'cloud': 'bulut',
      'chair': 'sandalye',
      'bread': 'ekmek',
    };

    Future<void> openRally(WidgetTester tester) async {
      await pumpApp(tester);
      await _scrollTo(tester, find.text('Kelime Rallisi'));
      await tester.tap(find.text('Kelime Rallisi'));
      await _advance(tester);
    }

    testWidgets('deste küçükse yönlendirme gösterilir', (tester) async {
      await repository.addFlashcards([
        (word: 'apple', meaning: 'elma', example: ''),
      ], source: 'new_word');
      await openRally(tester);

      expect(find.textContaining('en az 6 kelime gerekli'), findsOneWidget);
      expect(find.text('Günün hikayesine git'), findsOneWidget);
    });

    testWidgets('eşleştirilir, süre dolunca sonuç kaydedilir', (tester) async {
      await repository.addFlashcards([
        for (final e in pairs.entries)
          (word: e.key, meaning: e.value, example: ''),
      ], source: 'new_word');
      // Bir kartın tekrarı ileride: karıştırılınca bugüne çekilmeli.
      await (db.update(
        db.flashcards,
      )).write(FlashcardsCompanion(dueDate: Value(DateTime(2099))));
      await openRally(tester);

      expect(find.text('60 saniyede kaç kelime?'), findsOneWidget);
      await tester.tap(find.text('Başla'));
      await _advance(tester);

      // Tahtadaki ilk İngilizce kelime ve karşılığı.
      final onBoard = [
        for (final w in pairs.keys)
          if (find.text(w).evaluate().isNotEmpty) w,
      ];
      expect(onBoard, hasLength(5));
      final first = onBoard.first;
      await tester.tap(find.text(first));
      await tester.pump();
      await tester.tap(find.text(pairs[first]!));
      await _advance(tester);
      expect(
        tester.widget<Text>(find.byKey(const ValueKey('match-score'))).data,
        '10',
      );

      // Bir yanlış: tahtadaki iki farklı çift.
      final words = [
        for (final w in pairs.keys)
          if (find.text(w).evaluate().isNotEmpty) w,
      ];
      await tester.tap(find.text(words[0]));
      await tester.pump();
      await tester.tap(find.text(pairs[words[1]]!));
      await _advance(tester);

      // Süreyi bitir.
      await tester.pump(const Duration(seconds: 61));
      await _advance(tester);

      expect(find.text('Süre doldu!'), findsOneWidget);
      expect(find.text('Yeni rekor!'), findsOneWidget);
      expect(find.text('+1'), findsOneWidget);
      expect(find.text('KARIŞTIRDIKLARIN'), findsOneWidget);

      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getInt('match_best_score'), 10);
      expect(prefs.getInt('match_games'), 1);
      expect(prefs.getInt('match_xp'), 1);

      final cards = await db.select(db.flashcards).get();
      final pulled = {
        for (final c in cards)
          if (c.dueDate.year != 2099) c.word,
      };
      expect(pulled, {words[0], words[1]});
    });
  });

  testWidgets('haftalık rapor: yüksek skorla seviye yükseltilir', (
    tester,
  ) async {
    // 3 ders, ortalama %90: kural bir kademe yukarı önerir.
    for (var i = 0; i < 3; i++) {
      await db
          .into(db.lessons)
          .insert(
            LessonsCompanion.insert(
              lessonDate: dayOf(DateTime.now()),
              contentJson: '{}',
              score: const Value(90),
              completed: const Value(true),
            ),
          );
    }
    await pumpApp(tester);

    await tester.tap(find.text('İlerleme'));
    await _advance(tester);
    await _scrollTo(tester, find.text('Değerlendirme ve seviye önerisi'));
    await tester.tap(find.text('Değerlendirme ve seviye önerisi'));
    await _advance(tester);

    await tester.tap(find.text('Raporu oluştur'));
    await _advance(tester);

    // Anahtar yok: yorum yerel şablondan, öneri cihazdaki kuraldan.
    expect(find.text('BU HAFTA'), findsOneWidget);
    await _scrollTo(tester, find.text('Seviyemi B1+ yap'));
    await tester.tap(find.text('Seviyemi B1+ yap'));
    await _advance(tester);

    expect((await repository.profile())!.level, 'B1+');
  });

  testWidgets('flash kartlar: deste boşken yönlendirme gösterilir', (
    tester,
  ) async {
    await pumpApp(tester);

    await _scrollTo(tester, find.text('Ders bitirince dolar'));
    await tester.tap(find.text('Ders bitirince dolar'));
    await _advance(tester);

    expect(find.text('Desten henüz boş'), findsOneWidget);
    expect(find.text('0 kart · 0 öğrenildi'), findsOneWidget);
  });
}
