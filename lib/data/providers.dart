import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';
import 'gemini_service.dart';
import 'lesson_models.dart';
import 'repository.dart';
import 'settings_providers.dart';

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
  // Ayarlar'dan anahtar girildiyse o kullanılır; boşsa derleme zamanı anahtarı.
  final override = ref.watch(apiKeyProvider);
  final service = GeminiService(apiKey: override.isEmpty ? null : override);
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

  /// Planın hangi güne göre yüklendiği — gece yarısını geçtiğimizi anlamak için.
  DateTime? _loadedDay;

  @override
  Future<WeekPlan> build() => _loadOrGenerate();

  Future<WeekPlan> _load() async {
    final now = DateTime.now();
    final days = await ref.read(repositoryProvider).planForWeek(now);
    final offline =
        ref.read(sharedPreferencesProvider).getBool(_offlineKey()) ?? false;
    _loadedDay = dayOf(now);
    return WeekPlan(days: days, offline: offline);
  }

  /// Plan yoksa kendiliğinden üretir.
  ///
  /// Yeni haftaya geçildiğinde kullanıcıyı boş bir ekranla karşılayıp elle
  /// "programımı oluştur"a bastırmak yerine program hazır gelir.
  Future<WeekPlan> _loadOrGenerate() async {
    final plan = await _load();
    if (plan.days.isNotEmpty) return plan;

    final profile = await ref.read(repositoryProvider).profile();
    if (profile == null) return plan;

    await _generate(profile);
    return _load();
  }

  String _offlineKey() =>
      '$_offlinePrefix${mondayOf(DateTime.now()).toIso8601String()}';

  Future<WeeklyPlanResult> _generate(UserProfile profile) async {
    final result = await ref.read(geminiServiceProvider).generateWeeklyPlan(
          name: profile.name,
          level: profile.level,
          dailyMinutes: profile.dailyMinutes,
        );
    await ref
        .read(repositoryProvider)
        .replaceWeeklyPlan(DateTime.now(), result.days);
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_offlineKey(), result.offline);
    return result;
  }

  /// Gemini'den bu hafta için yeni bir program üretip kaydeder.
  ///
  /// Gemini'ye ulaşılamazsa yedek program yazılır; sonuç [WeeklyPlanResult]
  /// içinde `offline` olarak bildirilir.
  Future<WeeklyPlanResult> regenerate() async {
    final profile = await ref.read(repositoryProvider).profile();
    if (profile == null) {
      throw StateError('Plan üretmek için önce profil oluşturulmalı');
    }

    state = const AsyncValue.loading();
    final result = await _generate(profile);
    state = await AsyncValue.guard(_load);
    return result;
  }

  /// Uygulama öne geldiğinde çağrılır; gün değiştiyse planı tazeler.
  ///
  /// Uygulama açık bırakılıp gece yarısı geçildiğinde "bugün" dünde takılı
  /// kalıyordu; hafta da değişmişse yeni program burada üretilir.
  Future<void> refreshIfDayChanged() async {
    if (_loadedDay == dayOf(DateTime.now())) return;
    state = await AsyncValue.guard(_loadOrGenerate);
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

/// Bugünkü ders kaydı — ana ekranda skor/süre göstermek için.
///
/// Plan durumu değiştiğinde (gün tamamlanınca) yeniden okunur.
final todayLessonProvider = FutureProvider<Lesson?>((ref) async {
  ref.watch(weekPlanProvider);
  return ref.read(repositoryProvider).lessonFor(DateTime.now());
});

/// Ders üretilemediğinde fırlatılır.
///
/// Kullanıcıya ham hata yerine ne yapabileceğini söyleyen bir ekran gösterilsin
/// diye ayrı bir tip: mesajı doğrudan arayüzde gösterilebilir.
class LessonUnavailable implements Exception {
  const LessonUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// Bugünkü ders: varsa veritabanından devam eder, yoksa Gemini'den üretir.
class LessonNotifier extends AsyncNotifier<LessonState> {
  DateTime? _sessionStart;

  @override
  Future<LessonState> build() async {
    _sessionStart = DateTime.now();

    final existing =
        await ref.read(repositoryProvider).lessonFor(DateTime.now());
    if (existing != null) {
      final decoded = LessonState.decode(existing.contentJson);
      // Kayıt bozuksa sessizce yeniden üretilir.
      if (decoded != null) return decoded;
    }
    return _generate();
  }

  Future<LessonState> _generate() async {
    final repository = ref.read(repositoryProvider);

    final profile = await repository.profile();
    if (profile == null) {
      throw const LessonUnavailable('Önce profilini oluşturman gerekiyor.');
    }

    final today = (await ref.read(weekPlanProvider.future)).today;
    if (today == null) {
      throw const LessonUnavailable(
        'Bugün için plan bulunamadı. Ana ekrandan programı yenile.',
      );
    }

    final result = await ref.read(geminiServiceProvider).generateDailyLesson(
          name: profile.name,
          level: profile.level,
          dailyMinutes: profile.dailyMinutes,
          grammarTopic: today.grammarTopic,
          vocabTheme: today.vocabTheme,
          reviewItems: await repository.unresolvedMistakeItems(),
        );

    final lesson = result.lesson;
    if (lesson == null) {
      throw LessonUnavailable(result.error ?? 'Ders üretilemedi.');
    }

    final lessonState = LessonState(lesson: lesson);
    await repository.saveLesson(DateTime.now(), lessonState);
    return lessonState;
  }

  /// Üretim başarısız olduysa yeniden dener.
  Future<void> retry() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_generate);
  }

  /// Bir soruyu cevaplar ve ilerlemeyi kalıcı yazar.
  Future<void> answer(
    String key, {
    required bool correct,
    required String input,
  }) async {
    final current = state.value;
    if (current == null || current.progress.answers.containsKey(key)) return;

    await _persist(
      current.copyWith(
        progress:
            current.progress.withAnswer(key, correct: correct, input: input),
      ),
    );
  }

  /// Akıştaki adımı değiştirir; yarıda bırakılırsa buradan devam edilir.
  Future<void> goToStep(int index) async {
    final current = state.value;
    if (current == null || current.progress.stepIndex == index) return;

    await _persist(
      current.copyWith(progress: current.progress.copyWith(stepIndex: index)),
    );
  }

  Future<void> _persist(LessonState next) async {
    state = AsyncValue.data(next);
    await ref.read(repositoryProvider).saveLesson(DateTime.now(), next);
  }

  /// Dersi bitirir: skoru ve süreyi yazar, hataları deftere işler, günü kapatır.
  Future<void> finish() async {
    final current = state.value;
    if (current == null) return;

    final repository = ref.read(repositoryProvider);
    final now = DateTime.now();

    // Ders yarıda bırakılıp geri dönülmüş olabilir; süreler toplanır.
    final previous = (await repository.lessonFor(now))?.durationSeconds ?? 0;
    final elapsed =
        _sessionStart == null ? 0 : now.difference(_sessionStart!).inSeconds;

    await repository.saveLesson(
      now,
      current,
      score: current.scorePercent,
      durationSeconds: previous + elapsed,
      completed: true,
    );
    await repository.recordOutcomes(current.outcomes(), now: now);

    final today = (await ref.read(weekPlanProvider.future)).today;
    if (today != null && today.status != 'completed') {
      await ref.read(weekPlanProvider.notifier).completeDay(today);
    }
    ref.invalidate(todayLessonProvider);
  }
}

/// Ders ekranı kapanınca durum atılır: her açılışta veritabanından tazelenir,
/// böylece gün değiştiğinde dünün dersi ekranda kalmaz. İlerleme zaten
/// veritabanında olduğu için hiçbir şey kaybolmaz.
///
/// Otomatik yeniden deneme kapalı: anahtar yoksa ya da kota dolduysa arka planda
/// sessizce tekrar tekrar istek atmak kotayı tüketir. Hata ekranda gösterilir,
/// yeniden denemeyi kullanıcı [LessonNotifier.retry] ile başlatır.
final lessonProvider = AsyncNotifierProvider<LessonNotifier, LessonState>(
  LessonNotifier.new,
  isAutoDispose: true,
  retry: (_, _) => null,
);
