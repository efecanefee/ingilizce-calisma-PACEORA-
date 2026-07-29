import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';
import 'gemini_service.dart';
import 'repository.dart';

/// main() içinde gerçek örnekle override edilir.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError(
    'sharedPreferencesProvider main() içinde override edilmeli',
  ),
);

final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(db.close);
  return db;
});

final repositoryProvider = Provider<Repository>(
  (ref) => Repository(ref.watch(databaseProvider)),
);

final geminiServiceProvider = Provider<GeminiService>((ref) {
  final service = GeminiService();
  ref.onDispose(service.dispose);
  return service;
});

/// Tek kullanıcı profili. Onboarding tamamlanmadıysa değer null.
class ProfileNotifier extends AsyncNotifier<UserProfile?> {
  @override
  Future<UserProfile?> build() => ref.read(repositoryProvider).profile();

  Future<UserProfile> save({
    required String name,
    required String level,
    required int dailyMinutes,
  }) async {
    final profile = await ref.read(repositoryProvider).saveProfile(
          name: name,
          level: level,
          dailyMinutes: dailyMinutes,
        );
    state = AsyncValue.data(profile);
    return profile;
  }

  Future<void> refresh() async {
    state = await AsyncValue.guard(() => ref.read(repositoryProvider).profile());
  }
}

final profileProvider =
    AsyncNotifierProvider<ProfileNotifier, UserProfile?>(ProfileNotifier.new);

/// İçinde bulunulan haftanın planı + planın kaynağı.
class WeekPlan {
  const WeekPlan({required this.days, required this.offline});

  final List<WeeklyPlanDay> days;

  /// true ise plan Gemini'den değil yerleşik yedek programdan geldi.
  final bool offline;

  /// Bugüne denk gelen gün; plan boşsa null.
  WeeklyPlanDay? get today {
    final index = DateTime.now().weekday - DateTime.monday;
    for (final day in days) {
      if (day.dayIndex == index) return day;
    }
    return null;
  }
}

class WeekPlanNotifier extends AsyncNotifier<WeekPlan> {
  static const _offlinePrefix = 'plan_offline_';

  @override
  Future<WeekPlan> build() => _load();

  Future<WeekPlan> _load() async {
    final days = await ref.read(repositoryProvider).planForWeek(DateTime.now());
    final offline =
        ref.read(sharedPreferencesProvider).getBool(_offlineKey()) ?? false;
    return WeekPlan(days: days, offline: offline);
  }

  String _offlineKey() =>
      '$_offlinePrefix${mondayOf(DateTime.now()).toIso8601String()}';

  /// Gemini'den bu hafta için yeni bir program üretip kaydeder.
  ///
  /// Gemini'ye ulaşılamazsa yedek program yazılır; sonuç [WeeklyPlanResult]
  /// içinde `offline` olarak bildirilir.
  Future<WeeklyPlanResult> regenerate() async {
    final repository = ref.read(repositoryProvider);
    final profile = await repository.profile();
    if (profile == null) {
      throw StateError('Plan üretmek için önce profil oluşturulmalı');
    }

    state = const AsyncValue.loading();
    final result = await ref.read(geminiServiceProvider).generateWeeklyPlan(
          name: profile.name,
          level: profile.level,
          dailyMinutes: profile.dailyMinutes,
        );
    await repository.replaceWeeklyPlan(DateTime.now(), result.days);
    await ref.read(sharedPreferencesProvider).setBool(_offlineKey(), result.offline);

    state = await AsyncValue.guard(_load);
    return result;
  }

  /// Günü tamamlandı işaretler, streak'i günceller.
  Future<void> completeDay(WeeklyPlanDay day) async {
    await ref.read(repositoryProvider).completeDay(day);
    await ref.read(profileProvider.notifier).refresh();
    state = await AsyncValue.guard(_load);
  }
}

final weekPlanProvider =
    AsyncNotifierProvider<WeekPlanNotifier, WeekPlan>(WeekPlanNotifier.new);
