import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/lesson_models.dart';
import 'package:paceora/data/repository.dart';

void main() {
  group('nextStreak', () {
    final today = DateTime(2026, 7, 28);

    test('ilk çalışmada 1 olur', () {
      expect(nextStreak(current: 0, lastStudy: null, today: today), 1);
    });

    test('dün çalışıldıysa artar', () {
      expect(
        nextStreak(current: 4, lastStudy: DateTime(2026, 7, 27), today: today),
        5,
      );
    });

    test('aynı gün ikinci kez tamamlamak streak\'i değiştirmez', () {
      expect(
        nextStreak(
          current: 4,
          lastStudy: DateTime(2026, 7, 28, 9, 30),
          today: today,
        ),
        4,
      );
    });

    test('gün atlanırsa 1\'e döner', () {
      expect(
        nextStreak(current: 9, lastStudy: DateTime(2026, 7, 25), today: today),
        1,
      );
    });
  });

  group('mondayOf', () {
    test('hafta içi bir günü pazartesiye çeker', () {
      // 2026-07-28 salı
      expect(mondayOf(DateTime(2026, 7, 28, 22)), DateTime(2026, 7, 27));
    });

    test('pazar gününü aynı haftanın pazartesisine çeker', () {
      // 2026-08-02 pazar
      expect(mondayOf(DateTime(2026, 8, 2)), DateTime(2026, 7, 27));
    });

    test('pazartesi olduğu gibi kalır', () {
      expect(mondayOf(DateTime(2026, 7, 27, 13, 45)), DateTime(2026, 7, 27));
    });
  });

  group('Repository', () {
    late AppDatabase db;
    late Repository repository;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = Repository(db);
    });

    tearDown(() => db.close());

    test('profil oluşturur ve günceller, ikinci satır açmaz', () async {
      expect(await repository.profile(), isNull);

      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 15);
      var profile = await repository.profile();
      expect(profile?.name, 'Efe');
      expect(profile?.streak, 0);

      await repository.saveProfile(name: 'Efecan', level: 'B2', dailyMinutes: 20);
      profile = await repository.profile();
      expect(profile?.name, 'Efecan');
      expect(profile?.level, 'B2');
      expect(profile?.dailyMinutes, 20);
      expect(await db.select(db.userProfiles).get(), hasLength(1));
    });

    test('haftalık planı yazar, sıralı okur ve üzerine yazar', () async {
      final week = DateTime(2026, 7, 29); // çarşamba

      await repository.replaceWeeklyPlan(week, [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
      ]);

      final days = await repository.planForWeek(week);
      expect(days, hasLength(7));
      expect(days.map((d) => d.dayIndex), [0, 1, 2, 3, 4, 5, 6]);
      expect(days.first.grammarTopic, 'Konu 0');
      expect(days.every((d) => d.weekStart == DateTime(2026, 7, 27)), isTrue);

      // Aynı haftaya ikinci yazım eskisini siler, çoğaltmaz.
      await repository.replaceWeeklyPlan(week, [
        const PlanDaySpec(grammarTopic: 'Yeni', vocabTheme: 'Yeni tema'),
      ]);
      final replaced = await repository.planForWeek(week);
      expect(replaced, hasLength(1));
      expect(replaced.single.grammarTopic, 'Yeni');
    });

    test('plan yenilenince tamamlanmış günlerin durumu korunur', () async {
      final week = DateTime(2026, 7, 27);
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      await repository.replaceWeeklyPlan(week, [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
      ]);

      final monday = (await repository.planForWeek(week)).first;
      await repository.completeDay(monday, now: DateTime(2026, 7, 27));

      // Yeni bir program üretilse bile pazartesi tamamlanmış kalmalı.
      await repository.replaceWeeklyPlan(week, [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'Yeni $i', vocabTheme: 'Yeni tema $i'),
      ]);

      final refreshed = await repository.planForWeek(week);
      expect(refreshed, hasLength(7));
      expect(refreshed.first.grammarTopic, 'Yeni 0');
      expect(refreshed.first.status, 'completed');
      expect(refreshed[1].status, 'pending');
    });

    test('completeDay günü işaretler ve streak\'i günceller', () async {
      final week = DateTime(2026, 7, 27);
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      await repository.replaceWeeklyPlan(week, [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
      ]);

      final monday = (await repository.planForWeek(week)).first;
      await repository.completeDay(monday, now: DateTime(2026, 7, 27, 20));

      expect(
        (await repository.planForWeek(week)).first.status,
        'completed',
      );
      var profile = await repository.profile();
      expect(profile?.streak, 1);
      expect(profile?.lastStudyDate, DateTime(2026, 7, 27));

      // Ertesi gün tamamlanınca streak 2 olur.
      final tuesday = (await repository.planForWeek(week))[1];
      await repository.completeDay(tuesday, now: DateTime(2026, 7, 28, 9));
      profile = await repository.profile();
      expect(profile?.streak, 2);
    });

    group('günlük ders', () {
      final lesson = DailyLesson(
        vocab: const [],
        gapFill: const [
          GapFillItem(
            sentence: 'I ___ tea.',
            answer: 'drink',
            options: ['drink', 'drinks'],
            hintTr: '',
          ),
        ],
        translate: const [],
        quiz: const [],
      );

      test('gün için ders yoksa null döner', () async {
        expect(await repository.lessonFor(DateTime(2026, 7, 29)), isNull);
      });

      test('ders kaydedilir ve saat fark etmeksizin aynı gün bulunur', () async {
        await repository.saveLesson(
          DateTime(2026, 7, 29, 8, 30),
          LessonState(lesson: lesson),
        );

        final saved = await repository.lessonFor(DateTime(2026, 7, 29, 23, 15));
        expect(saved, isNotNull);
        expect(saved!.completed, isFalse);
        expect(saved.score, isNull);
        expect(LessonState.decode(saved.contentJson)?.lesson.questionCount, 1);
      });

      test('aynı güne ikinci kayıt yeni satır açmaz, ilerlemeyi günceller',
          () async {
        final date = DateTime(2026, 7, 29, 9);
        await repository.saveLesson(date, LessonState(lesson: lesson));

        await repository.saveLesson(
          date,
          LessonState(lesson: lesson).copyWith(
            progress: const LessonProgress(stepIndex: 1)
                .withAnswer(gapFillKey(0), correct: true, input: 'drink'),
          ),
        );

        expect(await db.select(db.lessons).get(), hasLength(1));
        final saved = await repository.lessonFor(date);
        final restored = LessonState.decode(saved!.contentJson)!;
        expect(restored.progress.stepIndex, 1);
        expect(restored.correctCount, 1);
      });

      test('skor ve süre yazılmayan alanları ezmez', () async {
        final date = DateTime(2026, 7, 29, 9);
        await repository.saveLesson(
          date,
          LessonState(lesson: lesson),
          score: 80,
          durationSeconds: 600,
          completed: true,
        );

        // İlerleme güncellemesi skor/süreyi silmemeli.
        await repository.saveLesson(date, LessonState(lesson: lesson));

        final saved = await repository.lessonFor(date);
        expect(saved!.score, 80);
        expect(saved.durationSeconds, 600);
        expect(saved.completed, isTrue);
      });
    });

    test('resetAll tüm tabloları boşaltır', () async {
      final week = DateTime(2026, 7, 27);
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      await repository.replaceWeeklyPlan(week, [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
      ]);
      await repository.recordOutcomes([
        const AnswerOutcome(
          item: 'drink',
          context: 'I ___ tea.',
          type: 'vocabulary',
          correct: false,
        ),
      ]);

      await repository.resetAll();

      expect(await repository.profile(), isNull);
      expect(await repository.planForWeek(week), isEmpty);
      expect(await db.select(db.mistakes).get(), isEmpty);
    });
  });
}
