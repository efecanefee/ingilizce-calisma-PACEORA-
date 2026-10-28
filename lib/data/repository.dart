import 'package:drift/drift.dart';

import '../app/constants.dart';
import 'database.dart';
import 'lesson_models.dart';
import 'review_models.dart';
import 'rewards.dart';
import 'srs.dart';
import 'story_models.dart';

/// Haftalık plandaki tek bir günün konusu — henüz veritabanına yazılmamış hali.
class PlanDaySpec {
  const PlanDaySpec({required this.grammarTopic, required this.vocabTheme});

  final String grammarTopic;
  final String vocabTheme;
}

/// Tarihin gün başlangıcı (00:00) — saat bilgisini atar.
DateTime dayOf(DateTime date) => DateTime(date.year, date.month, date.day);

/// Tarihin içinde bulunduğu haftanın pazartesi günü (00:00).
DateTime mondayOf(DateTime date) => DateTime(
      date.year,
      date.month,
      date.day - (date.weekday - DateTime.monday),
    );

/// İki tarih arasındaki tam gün farkı (yaz saati kaymalarından etkilenmez).
int _daysBetween(DateTime from, DateTime to) => DateTime.utc(to.year, to.month, to.day)
    .difference(DateTime.utc(from.year, from.month, from.day))
    .inDays;

/// Çalışılan günlerden en uzun kesintisiz seri.
int bestStreakOf(Set<DateTime> days) {
  final sorted = days.map(dayOf).toSet().toList()..sort();
  var best = 0;
  var run = 0;
  DateTime? previous;
  for (final day in sorted) {
    final consecutive = previous != null && _daysBetween(previous, day) == 1;
    run = consecutive ? run + 1 : 1;
    if (run > best) best = run;
    previous = day;
  }
  return best;
}

/// Bugün çalışma tamamlandığında streak'in alacağı yeni değer.
///
/// - Hiç çalışılmamışsa 1
/// - Dün çalışılmışsa +1
/// - Bugün zaten çalışılmışsa değişmez
/// - Arada gün atlanmışsa 1'e döner
int nextStreak({
  required int current,
  required DateTime? lastStudy,
  required DateTime today,
}) {
  if (lastStudy == null) return 1;
  final diff = _daysBetween(lastStudy, today);
  if (diff == 0) return current < 1 ? 1 : current;
  if (diff == 1) return current + 1;
  return 1;
}

/// Veritabanı erişimini tek yerde toplayan ince katman.
class Repository {
  Repository(this._db);

  final AppDatabase _db;

  /// Tek kullanıcı profili; onboarding tamamlanmadıysa null.
  Future<UserProfile?> profile() =>
      (_db.select(_db.userProfiles)..limit(1)).getSingleOrNull();

  /// Profili oluşturur ya da mevcut olanı günceller.
  Future<UserProfile> saveProfile({
    required String name,
    required String level,
    required int dailyMinutes,
  }) async {
    final existing = await profile();
    if (existing == null) {
      await _db.into(_db.userProfiles).insert(
            UserProfilesCompanion.insert(
              name: name,
              level: level,
              dailyMinutes: dailyMinutes,
            ),
          );
    } else {
      await (_db.update(_db.userProfiles)..where((t) => t.id.equals(existing.id)))
          .write(
        UserProfilesCompanion(
          name: Value(name),
          level: Value(level),
          dailyMinutes: Value(dailyMinutes),
        ),
      );
    }
    return (await profile())!;
  }

  /// [date]'in içinde bulunduğu haftanın planı, pazartesiden pazara sıralı.
  Future<List<WeeklyPlanDay>> planForWeek(DateTime date) {
    final start = mondayOf(date);
    return (_db.select(_db.weeklyPlanDays)
          ..where((t) => t.weekStart.equals(start))
          ..orderBy([(t) => OrderingTerm(expression: t.dayIndex)]))
        .get();
  }

  /// Haftanın planını baştan yazar (varsa eskisini siler).
  Future<void> replaceWeeklyPlan(DateTime date, List<PlanDaySpec> days) async {
    final start = mondayOf(date);
    await _db.transaction(() async {
      // Zaten çalışılmış günlerin durumu korunur; plan yenilemek ilerlemeyi
      // ve dolayısıyla streak'i silmemeli.
      final previousStatus = {
        for (final day in await planForWeek(start)) day.dayIndex: day.status,
      };

      await (_db.delete(_db.weeklyPlanDays)..where((t) => t.weekStart.equals(start)))
          .go();
      await _db.batch((batch) {
        batch.insertAll(_db.weeklyPlanDays, [
          for (var i = 0; i < days.length; i++)
            WeeklyPlanDaysCompanion.insert(
              weekStart: start,
              dayIndex: i,
              grammarTopic: days[i].grammarTopic,
              vocabTheme: days[i].vocabTheme,
              status: Value(previousStatus[i] ?? 'pending'),
            ),
        ]);
      });
    });
  }

  /// Günü tamamlandı işaretler ve profildeki streak'i günceller.
  Future<void> completeDay(WeeklyPlanDay day, {DateTime? now}) async {
    final today = dayOf(now ?? DateTime.now());
    await _db.transaction(() async {
      await (_db.update(_db.weeklyPlanDays)..where((t) => t.id.equals(day.id)))
          .write(const WeeklyPlanDaysCompanion(status: Value('completed')));

      final current = await profile();
      if (current == null) return;

      await (_db.update(_db.userProfiles)..where((t) => t.id.equals(current.id)))
          .write(
        UserProfilesCompanion(
          streak: Value(
            nextStreak(
              current: current.streak,
              lastStudy: current.lastStudyDate,
              today: today,
            ),
          ),
          lastStudyDate: Value(today),
        ),
      );
    });
  }

  // --- Günlük ders ---------------------------------------------------------

  /// [date] gününe ait ders kaydı; henüz üretilmediyse null.
  Future<Lesson?> lessonFor(DateTime date) => (_db.select(_db.lessons)
        ..where((t) => t.lessonDate.equals(dayOf(date)))
        ..limit(1))
      .getSingleOrNull();

  /// Dersi kaydeder ya da var olanı günceller.
  ///
  /// İçerik ve ilerleme tek JSON olarak `contentJson`'a yazılır; böylece ders
  /// yarıda bırakılıp geri dönüldüğünde kaldığı adımdan devam eder ve aynı gün
  /// içinde Gemini'ye ikinci kez istek gitmez.
  Future<void> saveLesson(
    DateTime date,
    LessonState state, {
    double? score,
    int? durationSeconds,
    bool? completed,
  }) async {
    final day = dayOf(date);
    final existing = await lessonFor(day);

    if (existing == null) {
      await _db.into(_db.lessons).insert(
            LessonsCompanion.insert(
              lessonDate: day,
              contentJson: state.encode(),
              score: Value(score),
              durationSeconds: Value(durationSeconds ?? 0),
              completed: Value(completed ?? false),
            ),
          );
      return;
    }

    await (_db.update(_db.lessons)..where((t) => t.id.equals(existing.id))).write(
      LessonsCompanion(
        contentJson: Value(state.encode()),
        score: score == null ? const Value.absent() : Value(score),
        durationSeconds: durationSeconds == null
            ? const Value.absent()
            : Value(durationSeconds),
        completed:
            completed == null ? const Value.absent() : Value(completed),
      ),
    );
  }

  // --- Hata defteri --------------------------------------------------------

  /// Ders sonundaki cevapları hata defterine işler.
  ///
  /// Doğru bilinen ve daha önce hiç yanlış yapılmamış bir ifade deftere
  /// girmez. `timesCorrect` **üst üste** doğru sayısıdır: yanlış yapılınca
  /// sıfırlanır ve kayıt yeniden çözülmemiş sayılır. Üç kez üst üste doğru
  /// yapılınca `resolved` olur (`database.dart` içindeki kural).
  Future<void> recordOutcomes(
    List<AnswerOutcome> outcomes, {
    DateTime? now,
  }) async {
    if (outcomes.isEmpty) return;
    final at = now ?? DateTime.now();

    await _db.transaction(() async {
      for (final outcome in outcomes) {
        final existing = await (_db.select(_db.mistakes)
              ..where((t) =>
                  t.item.equals(outcome.item) & t.type.equals(outcome.type))
              ..limit(1))
            .getSingleOrNull();

        if (existing == null) {
          if (outcome.correct) continue;
          await _db.into(_db.mistakes).insert(
                MistakesCompanion.insert(
                  item: outcome.item,
                  context: outcome.context,
                  type: outcome.type,
                  lastAskedAt: Value(at),
                ),
              );
          continue;
        }

        final correctStreak = outcome.correct ? existing.timesCorrect + 1 : 0;
        await (_db.update(_db.mistakes)
              ..where((t) => t.id.equals(existing.id)))
            .write(
          MistakesCompanion(
            timesCorrect: Value(correctStreak),
            timesWrong: Value(
              existing.timesWrong + (outcome.correct ? 0 : 1),
            ),
            lastAskedAt: Value(at),
            resolved: Value(correctStreak >= 3),
          ),
        );
      }
    });
  }

  /// Henüz pekişmemiş ifadeler — sonraki dersin promptuna beslenir.
  ///
  /// En çok yanlış yapılanlar önce, eşitlikte en uzun süredir sorulmayanlar.
  Future<List<String>> unresolvedMistakeItems({
    int limit = AppConstants.maxReviewItems,
  }) async {
    final rows = await (_db.select(_db.mistakes)
          ..where((t) => t.resolved.equals(false))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.timesWrong,
                  mode: OrderingMode.desc,
                ),
            (t) => OrderingTerm(expression: t.lastAskedAt),
          ])
          ..limit(limit))
        .get();
    return [for (final row in rows) row.item];
  }

  // --- Flash kartlar (SM-2) ------------------------------------------------

  /// Kartları desteye ekler; aynı kelime zaten varsa yeni kart açılmaz.
  ///
  /// [source] `new_word` (dersin kelimeleri) ya da `mistake` (yanlış yapılan
  /// ifade). Hatadan gelen kart zaten destedeyse bugüne çekilir: yanlış
  /// yapılan şeyin bir sonraki tekrarı ertelenmemeli.
  Future<int> addFlashcards(
    List<({String word, String meaning, String example})> cards, {
    required String source,
    DateTime? now,
  }) async {
    if (cards.isEmpty) return 0;
    final today = dayOf(now ?? DateTime.now());
    var added = 0;

    await _db.transaction(() async {
      for (final card in cards) {
        final word = card.word.trim();
        if (word.isEmpty) continue;

        final existing = await (_db.select(_db.flashcards)
              ..where((t) => t.word.lower().equals(word.toLowerCase()))
              ..limit(1))
            .getSingleOrNull();

        if (existing == null) {
          await _db.into(_db.flashcards).insert(
                FlashcardsCompanion.insert(
                  word: word,
                  meaning: card.meaning.trim(),
                  exampleSentence: card.example.trim(),
                  source: source,
                  dueDate: today,
                ),
              );
          added++;
        } else if (source == 'mistake' && existing.dueDate.isAfter(today)) {
          await (_db.update(_db.flashcards)
                ..where((t) => t.id.equals(existing.id)))
              .write(FlashcardsCompanion(dueDate: Value(today)));
        }
      }
    });
    return added;
  }

  /// Bugün (veya daha önce) tekrar zamanı gelmiş kartlar, en gecikmiş önce.
  Future<List<Flashcard>> dueFlashcards({DateTime? now, int? limit}) {
    final today = dayOf(now ?? DateTime.now());
    final query = _db.select(_db.flashcards)
      ..where((t) => t.dueDate.isSmallerOrEqualValue(today))
      ..orderBy([
        (t) => OrderingTerm(expression: t.dueDate),
        (t) => OrderingTerm(expression: t.id),
      ]);
    if (limit != null) query.limit(limit);
    return query.get();
  }

  /// Destedeki kart sayıları: toplam ve "öğrenilmiş" (aralığı 21+ gün).
  Future<({int total, int mature})> flashcardCounts() async {
    final all = await _db.select(_db.flashcards).get();
    return (
      total: all.length,
      mature: all.where((c) => c.intervalDays >= 21).length,
    );
  }

  /// Kartı değerlendirir ve SM-2'ye göre bir sonraki tekrarını yazar.
  Future<SrsSchedule> reviewFlashcard(
    Flashcard card,
    ReviewGrade grade, {
    DateTime? now,
  }) async {
    final schedule = nextSchedule(
      ease: card.ease,
      intervalDays: card.intervalDays,
      reps: card.reps,
      grade: grade,
      today: now ?? DateTime.now(),
    );
    await (_db.update(_db.flashcards)..where((t) => t.id.equals(card.id)))
        .write(
      FlashcardsCompanion(
        ease: Value(schedule.ease),
        intervalDays: Value(schedule.intervalDays),
        reps: Value(schedule.reps),
        dueDate: Value(schedule.dueDate),
      ),
    );
    return schedule;
  }

  // --- Günün hikayesi ------------------------------------------------------

  Future<Story?> storyFor(DateTime date) => (_db.select(_db.stories)
        ..where((t) => t.storyDate.equals(dayOf(date)))
        ..limit(1))
      .getSingleOrNull();

  /// Hikayeyi ve cevapları kaydeder; test bittiyse skoru da yazar.
  Future<void> saveStory(DateTime date, StoryState state) async {
    final day = dayOf(date);
    final existing = await storyFor(day);
    final score = state.isFinished ? Value(state.scorePercent) : const Value<double?>.absent();

    if (existing == null) {
      await _db.into(_db.stories).insert(
            StoriesCompanion.insert(
              storyDate: day,
              title: state.story.title,
              contentJson: state.encode(),
              quizScore: score,
            ),
          );
      return;
    }
    await (_db.update(_db.stories)..where((t) => t.id.equals(existing.id)))
        .write(
      StoriesCompanion(
        title: Value(state.story.title),
        contentJson: Value(state.encode()),
        quizScore: score,
      ),
    );
  }

  // --- İlerleme ------------------------------------------------------------

  /// Çalışılan günler: tamamlanan plan günleri ve bitirilen dersler.
  ///
  /// Gün elle işaretlenmiş olabilir (ders kaydı yok) ya da plan yenilenmiş
  /// olabilir; ikisinin birleşimi takvim için doğru kaynak.
  Future<Set<DateTime>> studiedDays() async {
    final planDays = await (_db.select(_db.weeklyPlanDays)
          ..where((t) => t.status.equals('completed')))
        .get();
    final lessons = await (_db.select(_db.lessons)
          ..where((t) => t.completed.equals(true)))
        .get();
    return {
      for (final day in planDays)
        DateTime(
          day.weekStart.year,
          day.weekStart.month,
          day.weekStart.day + day.dayIndex,
        ),
      for (final lesson in lessons) dayOf(lesson.lessonDate),
    };
  }

  /// Tamamlanmış dersler, tarihe göre artan.
  Future<List<Lesson>> completedLessons() => (_db.select(_db.lessons)
        ..where((t) => t.completed.equals(true))
        ..orderBy([(t) => OrderingTerm(expression: t.lessonDate)]))
      .get();

  /// [date]'in haftasının istatistikleri. [cardsReviewed] tekrar kaydı
  /// veritabanında tutulmadığı için dışarıdan verilir.
  Future<WeeklyStats> weeklyStats(
    DateTime date, {
    int cardsReviewed = 0,
  }) async {
    final start = mondayOf(date);
    final end = DateTime(start.year, start.month, start.day + 7);

    bool inWeek(DateTime d) => !d.isBefore(start) && d.isBefore(end);

    final plan = await planForWeek(start);
    final lessons = (await completedLessons())
        .where((l) => inWeek(l.lessonDate))
        .toList();
    final stories = (await _db.select(_db.stories).get())
        .where((s) => inWeek(s.storyDate) && s.quizScore != null)
        .toList();
    final mistakes = await (_db.select(_db.mistakes)
          ..where((t) => t.resolved.equals(false))
          ..orderBy([
            (t) => OrderingTerm(
                  expression: t.timesWrong,
                  mode: OrderingMode.desc,
                ),
          ]))
        .get();

    final scores = [for (final l in lessons) if (l.score != null) l.score!];
    final storyScores = [for (final s in stories) s.quizScore!];

    double? average(List<double> values) => values.isEmpty
        ? null
        : values.reduce((a, b) => a + b) / values.length;

    return WeeklyStats(
      weekStart: start,
      daysCompleted: plan.where((d) => d.status == 'completed').length,
      lessonsCompleted: lessons.length,
      averageLessonScore: average(scores),
      studyMinutes: (lessons.fold<int>(0, (sum, l) => sum + l.durationSeconds) / 60)
          .round(),
      storiesRead: stories.length,
      averageStoryScore: average(storyScores),
      cardsReviewed: cardsReviewed,
      openMistakes: mistakes.length,
      topMistakes: [for (final m in mistakes.take(5)) m.item],
    );
  }

  // --- Haftalık rapor ------------------------------------------------------

  /// Kayıtlı raporlar, en yeni hafta önce.
  Future<List<WeeklyReview>> weeklyReviews() => (_db.select(_db.weeklyReviews)
        ..orderBy([
          (t) => OrderingTerm(expression: t.weekStart, mode: OrderingMode.desc),
        ]))
      .get();

  /// Haftanın raporunu yazar; aynı hafta için önceki rapor değiştirilir.
  Future<void> saveWeeklyReport(WeeklyReport report) async {
    final start = mondayOf(report.stats.weekStart);
    await _db.transaction(() async {
      await (_db.delete(_db.weeklyReviews)
            ..where((t) => t.weekStart.equals(start)))
          .go();
      await _db.into(_db.weeklyReviews).insert(
            WeeklyReviewsCompanion.insert(
              weekStart: start,
              reportJson: report.encode(),
            ),
          );
    });
  }

  // --- Ödüller --------------------------------------------------------------

  /// Ödül sisteminin girdisi. [cardsReviewed] ve [levelUps] veritabanında
  /// değil SharedPreferences'ta tutulduğu için dışarıdan verilir.
  Future<GameStats> gameStats({int cardsReviewed = 0, int levelUps = 0}) async {
    final lessons = await completedLessons();
    final stories = (await _db.select(_db.stories).get())
        .where((s) => s.quizScore != null)
        .toList();
    final days = await studiedDays();
    final cards = await flashcardCounts();
    final streak = (await profile())?.streak ?? 0;
    final best = bestStreakOf(days);

    return GameStats(
      lessons: lessons.length,
      perfectLessons: lessons.where((l) => (l.score ?? 0) >= 99.5).length,
      lessonXpSum: lessons.fold(0, (sum, l) => sum + lessonXp(l.score ?? 0)),
      stories: stories.length,
      storyXpSum: stories.fold(0, (sum, s) => sum + storyXp(s.quizScore!)),
      cardsReviewed: cardsReviewed,
      cardsMature: cards.mature,
      studiedDays: days.length,
      currentStreak: streak,
      // Elle işaretlenen günler de takvimde; ikisi genelde aynıdır.
      bestStreak: best > streak ? best : streak,
      levelUps: levelUps,
    );
  }

  /// Hata defteri: henüz pekişmemiş olanlar önce, en çok yanlış yapılan üstte.
  Future<List<Mistake>> mistakes() => (_db.select(_db.mistakes)
        ..orderBy([
          (t) => OrderingTerm(expression: t.resolved),
          (t) => OrderingTerm(expression: t.timesWrong, mode: OrderingMode.desc),
          (t) => OrderingTerm(expression: t.lastAskedAt, mode: OrderingMode.desc),
        ]))
      .get();

  /// Profilin seviyesini değiştirir (adaptif seviye ayarı).
  Future<void> updateLevel(String level) async {
    final current = await profile();
    if (current == null) return;
    await (_db.update(_db.userProfiles)..where((t) => t.id.equals(current.id)))
        .write(UserProfilesCompanion(level: Value(level)));
  }

  /// Tüm kullanıcı verisini siler (Ayarlar → "Verileri sıfırla").
  Future<void> resetAll() async {
    await _db.transaction(() async {
      await _db.delete(_db.weeklyPlanDays).go();
      await _db.delete(_db.lessons).go();
      await _db.delete(_db.mistakes).go();
      await _db.delete(_db.flashcards).go();
      await _db.delete(_db.stories).go();
      await _db.delete(_db.weeklyReviews).go();
      await _db.delete(_db.userProfiles).go();
    });
  }
}
