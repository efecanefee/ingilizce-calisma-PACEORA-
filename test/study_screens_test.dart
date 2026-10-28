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
