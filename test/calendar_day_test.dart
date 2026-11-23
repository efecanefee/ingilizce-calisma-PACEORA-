import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/lesson_models.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/features/program/calendar_day_sheet.dart';
import 'package:paceora/features/program/month_calendar.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _lesson = DailyLesson(
  vocab: [
    VocabItem(
      word: 'commute',
      meaning: 'işe gidip gelmek',
      example: 'I commute.',
    ),
  ],
  gapFill: [],
  translate: [TranslateItem(tr: 'Mutluyum.', en: 'I am happy.', accepted: [])],
  quiz: [],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late Repository repository;
  late ProviderContainer Function(LessonNotifier Function()) containerWith;

  // Program 3 gün önce başladı; bugün 4. gün.
  final now = DateTime(2026, 11, 20, 10);
  final start = DateTime(2026, 11, 17);

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = Repository(db);
    await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 15);
    await repository.replaceWeeklyPlan(start, [
      for (var i = 0; i < 7; i++)
        PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
    ]);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    containerWith = (create) {
      final container = ProviderContainer(
        overrides: [
          databaseProvider.overrideWithValue(db),
          sharedPreferencesProvider.overrideWithValue(prefs),
          lessonProvider.overrideWith(create),
        ],
      );
      addTearDown(container.dispose);
      return container;
    };
  });

  tearDown(() => db.close());

  test('tekrar çözme sıfırdan başlar ve hiçbir şey yazmaz', () async {
    await withClock(Clock.fixed(now), () async {
      final day = DateTime(2026, 11, 17);
      final solved = LessonState(
        lesson: _lesson,
        progress: const LessonProgress().withAnswer(
          translateKey(0),
          correct: true,
          input: 'I am happy.',
        ),
      );
      await repository.saveLesson(day, solved, score: 100, completed: true);

      final container = containerWith(() => ReplayLessonNotifier(day));
      final sub = container.listen(lessonProvider, (_, _) {});
      addTearDown(sub.close);
      final state = await container.read(lessonProvider.future);
      expect(state.progress.answers, isEmpty);

      final notifier = container.read(lessonProvider.notifier);
      expect(notifier.title, 'Tekrar çöz');
      await notifier.answer(translateKey(0), correct: false, input: 'x');
      await notifier.finish();

      final row = (await repository.lessonFor(day))!;
      expect(row.score, 100);
      expect(LessonState.decode(row.contentJson)!.progress.answers.values, [
        true,
      ]);
      expect(await db.select(db.mistakes).get(), isEmpty);
      expect(await db.select(db.flashcards).get(), isEmpty);
    });
  });

  test('telafi dersi günü tamamlar ama seriyi değiştirmez', () async {
    await withClock(Clock.fixed(now), () async {
      final missed = DateTime(2026, 11, 18);
      await repository.saveLesson(missed, const LessonState(lesson: _lesson));
      await (db.update(
        db.userProfiles,
      )).write(const UserProfilesCompanion(streak: Value(4)));

      final container = containerWith(() => MakeupLessonNotifier(missed));
      final sub = container.listen(lessonProvider, (_, _) {});
      addTearDown(sub.close);
      await container.read(lessonProvider.future);
      final notifier = container.read(lessonProvider.notifier);
      expect(notifier.isToday, isFalse);
      await notifier.answer(
        translateKey(0),
        correct: true,
        input: 'I am happy.',
      );
      await notifier.finish();

      final plan = await repository.planDayOn(missed);
      expect(plan!.status, 'completed');
      expect((await repository.lessonFor(missed))!.completed, isTrue);
      expect((await repository.lessonFor(now)), isNull);
      expect((await repository.profile())!.streak, 4);
      expect((await repository.studiedDays()), contains(missed));
    });
  });

  test(
    'günün durumu: çalışıldı, bugün, kaçırıldı, gelecek, programdan önce',
    () {
      final today = DateTime(2026, 11, 20);
      WeeklyPlanDay plan(int i) => WeeklyPlanDay(
        id: i,
        weekStart: start,
        dayIndex: i,
        grammarTopic: 'K',
        vocabTheme: 'T',
        status: 'pending',
      );
      CalendarDay day(
        DateTime d, {
        bool studied = false,
        bool planned = true,
      }) => CalendarDay(
        date: d,
        plan: planned ? plan(0) : null,
        lesson: null,
        state: null,
        studied: studied,
        programStart: start,
      );

      expect(
        kindOf(day(DateTime(2026, 11, 18), studied: true), today),
        CalendarDayKind.studied,
      );
      expect(kindOf(day(today), today), CalendarDayKind.today);
      expect(
        kindOf(day(DateTime(2026, 11, 19)), today),
        CalendarDayKind.missed,
      );
      expect(
        kindOf(day(DateTime(2026, 11, 22)), today),
        CalendarDayKind.upcoming,
      );
      expect(
        kindOf(day(DateTime(2026, 11, 10)), today),
        CalendarDayKind.beforeStart,
      );
      expect(
        kindOf(day(DateTime(2026, 11, 19), planned: false), today),
        CalendarDayKind.empty,
      );
    },
  );

  test('ay özeti ders, süre, ortalama puan ve en uzun seriyi sayar', () {
    Lesson lesson(int day, double score, int seconds) => Lesson(
      id: day,
      lessonDate: DateTime(2026, 11, day),
      contentJson: '{}',
      score: score,
      durationSeconds: seconds,
      completed: true,
      createdAt: DateTime(2026, 11, day),
    );
    final data = ProgramCalendar(
      studied: {
        for (final d in [3, 4, 5, 9]) DateTime(2026, 11, d),
        DateTime(2026, 10, 30),
      },
      start: DateTime(2026, 10, 30),
      topics: const {},
      lessons: {
        DateTime(2026, 11, 3): lesson(3, 80, 600),
        DateTime(2026, 11, 4): lesson(4, 100, 900),
        DateTime(2026, 10, 30): lesson(30, 10, 60),
      },
    );
    final s = MonthSummary.of(data, DateTime(2026, 11));
    expect(s.days, 4);
    expect(s.lessons, 2);
    expect(s.minutes, 25);
    expect(s.averageScore, 90);
    expect(s.bestStreak, 3);
    expect(scoreAlpha(40), lessThan(scoreAlpha(70)));
    expect(scoreAlpha(null), 1);
  });
}
