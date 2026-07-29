import 'package:drift/drift.dart';

import '../app/constants.dart';
import 'database.dart';
import 'lesson_models.dart';

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
