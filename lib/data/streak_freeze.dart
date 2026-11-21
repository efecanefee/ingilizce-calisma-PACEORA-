import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import 'repository.dart' show dayOf;

/// Seri dondurma: kaçırılan bir günü seriyi bozmadan geçiştiren hak.
///
/// Haklar "harcanabilir XP" ile alınır. Toplam XP ve oyuncu seviyesi
/// harcamadan etkilenmez; ayrı bir harcanan XP sayacı tutulur. Kayıtlar
/// SharedPreferences'ta `streak_` önekiyle durur.

/// Bir hakkın fiyatı (harcanabilir XP).
const freezeCost = 100;

/// Aynı anda tutulabilecek en fazla hak.
const maxFreezes = 2;

class FreezeState {
  const FreezeState({
    this.owned = 0,
    this.spentXp = 0,
    this.frozenDays = const {},
  });

  static const ownedKey = 'streak_freezes';
  static const spentKey = 'streak_freeze_spent_xp';
  static const frozenKey = 'streak_frozen_days';

  /// Elde bulunan hak sayısı.
  final int owned;

  /// Haklara harcanan toplam XP.
  final int spentXp;

  /// Hakla korunan günler (takvimde buz olarak gösterilir).
  final Set<DateTime> frozenDays;

  /// Toplam XP'den harcanabilir kalan.
  int balance(int totalXp) => max(0, totalXp - spentXp);

  bool canBuy(int totalXp) =>
      owned < maxFreezes && balance(totalXp) >= freezeCost;

  factory FreezeState.read(SharedPreferences prefs) => FreezeState(
    owned: prefs.getInt(ownedKey) ?? 0,
    spentXp: prefs.getInt(spentKey) ?? 0,
    frozenDays: {
      for (final s in prefs.getStringList(frozenKey) ?? const <String>[])
        if (DateTime.tryParse(s) case final d?) dayOf(d),
    },
  );

  /// Bir hak satın alır; alınamıyorsa false.
  static Future<bool> buy(
    SharedPreferences prefs, {
    required int totalXp,
  }) async {
    final s = FreezeState.read(prefs);
    if (!s.canBuy(totalXp)) return false;
    await prefs.setInt(ownedKey, s.owned + 1);
    await prefs.setInt(spentKey, s.spentXp + freezeCost);
    return true;
  }

  /// [days] için hak harcar ve günleri korunan olarak kaydeder.
  static Future<void> consume(
    SharedPreferences prefs,
    List<DateTime> days,
  ) async {
    if (days.isEmpty) return;
    final s = FreezeState.read(prefs);
    await prefs.setInt(ownedKey, max(0, s.owned - days.length));
    await prefs.setStringList(frozenKey, [
      for (final d in {...s.frozenDays, ...days.map(dayOf)})
        d.toIso8601String(),
    ]);
  }
}

int _daysBetween(DateTime a, DateTime b) =>
    dayOf(b).difference(dayOf(a)).inDays;

/// Bugün çalışma tamamlandığında seri ve harcanacak haklar.
///
/// Arada kaçırılan günler eldeki haklarla karşılanabiliyorsa seri devam eder
/// ve o günler [bridged] olarak döner; karşılanamıyorsa hak harcanmaz, seri
/// 1'den başlar (yetmeyen hakları boşa harcamamak için).
({int streak, List<DateTime> bridged}) nextStreakWithFreezes({
  required int current,
  required DateTime? lastStudy,
  required DateTime today,
  required int freezes,
}) {
  if (lastStudy == null) return (streak: 1, bridged: const []);
  final diff = _daysBetween(lastStudy, today);
  if (diff <= 0) return (streak: current < 1 ? 1 : current, bridged: const []);
  if (diff == 1) return (streak: current + 1, bridged: const []);

  final missed = diff - 1;
  if (missed <= freezes && current > 0) {
    return (
      streak: current + 1,
      bridged: [
        for (var i = 1; i <= missed; i++)
          DateTime(lastStudy.year, lastStudy.month, lastStudy.day + i),
      ],
    );
  }
  return (streak: 1, bridged: const []);
}

/// Seri şu an ne durumda?
enum StreakStatus {
  /// Bugün çalışıldı.
  done,

  /// Dün çalışıldı; bugün çalışılırsa seri sürer.
  pending,

  /// Gün kaçırıldı ama haklar yetiyor; bugün çalışılırsa seri sürer.
  protected,

  /// Seri koptu.
  broken,
}

/// Ekranda gösterilecek seri.
///
/// Profildeki değer yalnızca gün tamamlanınca güncellenir; gün kaçırılınca
/// eski sayı ekranda kalıyordu. Kopmuş seri 0 gösterilir.
({int streak, StreakStatus status, int freezesNeeded}) displayStreak({
  required int stored,
  required DateTime? lastStudy,
  required DateTime today,
  required int freezes,
}) {
  if (lastStudy == null || stored <= 0) {
    return (streak: 0, status: StreakStatus.broken, freezesNeeded: 0);
  }
  final diff = _daysBetween(lastStudy, today);
  if (diff <= 0) {
    return (streak: stored, status: StreakStatus.done, freezesNeeded: 0);
  }
  if (diff == 1) {
    return (streak: stored, status: StreakStatus.pending, freezesNeeded: 0);
  }
  final missed = diff - 1;
  if (missed <= freezes) {
    return (
      streak: stored,
      status: StreakStatus.protected,
      freezesNeeded: missed,
    );
  }
  return (streak: 0, status: StreakStatus.broken, freezesNeeded: missed);
}

/// Seri hedefleri: ana ekrandaki bar bir sonrakine doğru dolar, hedefe
/// ulaşılınca kutlanır.
const streakMilestones = [3, 7, 14, 30, 50, 100, 200, 365];

/// [streak] için önceki ve sıradaki hedef; son hedef aşıldıysa her 100 günde
/// bir yeni hedef.
({int from, int to}) streakMilestone(int streak) {
  var from = 0;
  for (final m in streakMilestones) {
    if (streak < m) return (from: from, to: m);
    from = m;
  }
  final to = (streak ~/ 100 + 1) * 100;
  return (from: max(from, to - 100), to: to);
}

/// [streak] ile ulaşılmış en büyük hedef; hiçbirine ulaşılmadıysa 0.
int reachedStreakMilestone(int streak) => streakMilestone(streak).from;

/// Kutlaması gösterilmiş son seri hedefi (sıfırlamada `streak_` önekiyle
/// silinir).
const seenStreakMilestoneKey = 'streak_seen_milestone';
