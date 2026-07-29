import 'package:drift/drift.dart';

import 'database.dart';

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
}
