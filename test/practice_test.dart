import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/lesson_models.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/data/srs.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Animasyonlar yüzünden pumpAndSettle takılmasın diye sabit kare ilerletir.
Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late AppDatabase db;
  late Repository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = Repository(db);
  });

  tearDown(() => db.close());

  group('flash kart deposu', () {
    final today = DateTime(2026, 10, 28, 10);

    test(
      'aynı kelime ikinci kez eklenmez (büyük/küçük harf duyarsız)',
      () async {
        final added = await repository.addFlashcards(
          [
            (word: 'commute', meaning: 'işe gidip gelmek', example: ''),
            (word: 'Commute', meaning: 'tekrar', example: ''),
            (word: '  ', meaning: 'boş', example: ''),
          ],
          source: 'new_word',
          now: today,
        );
        expect(added, 1);
        expect(await db.select(db.flashcards).get(), hasLength(1));
      },
    );

    test('vadesi gelen kartlar listelenir, değerlendirme ertelenir', () async {
      await repository.addFlashcards(
        [(word: 'reliable', meaning: 'güvenilir', example: 'She is reliable.')],
        source: 'new_word',
        now: today,
      );
      final due = await repository.dueFlashcards(now: today);
      expect(due, hasLength(1));

      final schedule = await repository.reviewFlashcard(
        due.single,
        ReviewGrade.good,
        now: today,
      );
      expect(schedule.dueDate, DateTime(2026, 10, 29));
      expect(await repository.dueFlashcards(now: today), isEmpty);
      expect(
        await repository.dueFlashcards(now: DateTime(2026, 10, 29)),
        hasLength(1),
      );
    });

    test('hatadan gelen kart ileri tarihli kartı bugüne çeker', () async {
      await repository.addFlashcards(
        [(word: 'used to', meaning: 'eskiden', example: '')],
        source: 'new_word',
        now: today,
      );
      final card = (await repository.dueFlashcards(now: today)).single;
      await repository.reviewFlashcard(card, ReviewGrade.easy, now: today);
      expect(await repository.dueFlashcards(now: today), isEmpty);

      await repository.addFlashcards(
        [(word: 'used to', meaning: 'bağlam', example: '')],
        source: 'mistake',
        now: today,
      );
      expect(await repository.dueFlashcards(now: today), hasLength(1));
    });
  });

  group('ilerleme', () {
    test('en uzun seri ardışık günlerden hesaplanır', () {
      expect(bestStreakOf({}), 0);
      expect(
        bestStreakOf({
          DateTime(2026, 10, 1),
          DateTime(2026, 10, 2),
          DateTime(2026, 10, 3),
          DateTime(2026, 10, 5),
          DateTime(2026, 10, 6),
        }),
        3,
      );
      // Ay geçişi de ardışık sayılır.
      expect(bestStreakOf({DateTime(2026, 10, 31), DateTime(2026, 11, 1)}), 2);
    });

    test('çalışılan günler plan ve derslerin birleşimidir', () async {
      final monday = DateTime(2026, 10, 26);
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      await repository.replaceWeeklyPlan(monday, [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'G$i', vocabTheme: 'V$i'),
      ]);
      final plan = await repository.planForWeek(monday);
      await repository.completeDay(plan[0], now: monday);

      await db
          .into(db.lessons)
          .insert(
            LessonsCompanion.insert(
              lessonDate: DateTime(2026, 10, 28),
              contentJson: '{}',
              score: const Value(80),
              durationSeconds: const Value(600),
              completed: const Value(true),
            ),
          );

      expect(await repository.studiedDays(), {
        DateTime(2026, 10, 26),
        DateTime(2026, 10, 28),
      });

      final stats = await repository.weeklyStats(
        DateTime(2026, 10, 29),
        cardsReviewed: 7,
      );
      expect(stats.weekStart, monday);
      expect(stats.daysCompleted, 1);
      expect(stats.lessonsCompleted, 1);
      expect(stats.averageLessonScore, 80);
      expect(stats.studyMinutes, 10);
      expect(stats.cardsReviewed, 7);
      expect(stats.storiesRead, 0);
    });

    test('seviye güncellenir', () async {
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      await repository.updateLevel('B1+');
      expect((await repository.profile())!.level, 'B1+');
    });
  });

  testWidgets('flash kart oturumu: çevir, notla, bitir', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
    await repository.replaceWeeklyPlan(DateTime.now(), [
      for (var i = 0; i < 7; i++)
        PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
    ]);
    await repository.addFlashcards([
      (word: 'reliable', meaning: 'güvenilir', example: 'She is reliable.'),
    ], source: 'new_word');

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

    // Ana ekrandaki pratik alanı vadesi gelen kartı rozetle gösterir.
    await tester.scrollUntilVisible(
      find.text('1 kart seni bekliyor'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await _advance(tester);
    expect(find.text('1 kart seni bekliyor'), findsOneWidget);

    await tester.tap(find.text('1 kart seni bekliyor'));
    await _advance(tester);

    expect(find.text('reliable'), findsOneWidget);
    await tester.tap(find.text('Cevabı göster'));
    await _advance(tester);

    expect(find.text('güvenilir'), findsOneWidget);
    await tester.tap(find.text('İyi'));
    await _advance(tester);

    expect(find.text('Bugünlük bu kadar!'), findsOneWidget);
    final card = await db.select(db.flashcards).getSingle();
    expect(card.reps, 1);
    expect(card.dueDate.isAfter(dayOf(DateTime.now())), isTrue);
    expect(prefs.getInt(cardsReviewedKey(DateTime.now())), 1);
  });

  test('ders bitince kelimeler ve hatalar desteye girer', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
    await repository.replaceWeeklyPlan(DateTime.now(), [
      for (var i = 0; i < 7; i++)
        PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
    ]);

    const lesson = DailyLesson(
      vocab: [
        VocabItem(
          word: 'commute',
          meaning: 'işe gidip gelmek',
          example: 'I commute.',
        ),
      ],
      gapFill: [],
      translate: [
        TranslateItem(tr: 'Mutluyum.', en: 'I am happy.', accepted: []),
      ],
      quiz: [],
    );
    final state = LessonState(
      lesson: lesson,
      progress: const LessonProgress().withAnswer(
        translateKey(0),
        correct: false,
        input: 'happy',
      ),
    );
    await repository.saveLesson(DateTime.now(), state);

    // Sağlayıcı dinlenirken bitirilir; autoDispose durumu düşürmesin.
    final sub = container.listen(lessonProvider, (_, _) {});
    addTearDown(sub.close);
    await container.read(lessonProvider.future);
    await container.read(lessonProvider.notifier).finish();

    final words = (await db.select(db.flashcards).get()).map((c) => c.word);
    expect(words, containsAll(['commute', 'I am happy.']));
  });
}
