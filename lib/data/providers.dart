import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/constants.dart';
import 'database.dart';
import 'gemini_service.dart';
import 'lesson_models.dart';
import 'reminder_service.dart';
import 'repository.dart';
import 'review_models.dart';
import 'rewards.dart';
import 'srs.dart';
import 'settings_providers.dart';
import 'story_models.dart';

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

    // Dersin kelimeleri ve yanlış yapılanlar aralıklı tekrar destesine girer.
    await repository.addFlashcards(
      [
        for (final v in current.lesson.vocab)
          (word: v.word, meaning: v.meaning, example: v.example),
      ],
      source: 'new_word',
      now: now,
    );
    await repository.addFlashcards(
      [
        for (final o in current.outcomes().where((o) => !o.correct))
          (word: o.item, meaning: o.context, example: ''),
      ],
      source: 'mistake',
      now: now,
    );

    final today = (await ref.read(weekPlanProvider.future)).today;
    if (today != null && today.status != 'completed') {
      await ref.read(weekPlanProvider.notifier).completeDay(today);
    }
    ref.invalidate(todayLessonProvider);
    ref.invalidate(flashcardSummaryProvider);
    ref.invalidate(progressProvider);
    ref.invalidate(gameProvider);
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

// --- Hatırlatma -------------------------------------------------------------

/// main() içinde gerçek servisle override edilir; testlerde sessiz kalır.
final reminderServiceProvider =
    Provider<ReminderService>((ref) => const NoopReminderService());

// --- Flash kartlar ----------------------------------------------------------

/// Ana ekrandaki rozet ve kart ekranı başlığı için deste özeti.
final flashcardSummaryProvider =
    FutureProvider<({int due, int total, int mature})>((ref) async {
  final repository = ref.read(repositoryProvider);
  final due = await repository.dueFlashcards();
  final counts = await repository.flashcardCounts();
  return (due: due.length, total: counts.total, mature: counts.mature);
});

/// Haftalık rapor için bu hafta tekrar edilen kart sayısının anahtarı.
///
/// Tekrar geçmişi tabloda tutulmadığından sayaç SharedPreferences'ta.
String cardsReviewedKey(DateTime date) =>
    'cards_reviewed_${mondayOf(date).toIso8601String()}';

/// Bir tekrar oturumu: o an vadesi gelen kartlar sırayla gösterilir.
///
/// "Tekrar" denilen kart oturumun sonuna eklenir; böylece kullanıcı bilemediği
/// kartı aynı oturumda bir kez daha görür.
class FlashcardSession {
  const FlashcardSession({required this.queue, this.reviewed = 0});

  final List<Flashcard> queue;
  final int reviewed;

  Flashcard? get current => queue.isEmpty ? null : queue.first;
  bool get isDone => queue.isEmpty;
}

class FlashcardSessionNotifier extends AsyncNotifier<FlashcardSession> {
  @override
  Future<FlashcardSession> build() async => FlashcardSession(
        queue: await ref.read(repositoryProvider).dueFlashcards(limit: 50),
      );

  Future<void> grade(ReviewGrade grade) async {
    final session = state.value;
    final card = session?.current;
    if (session == null || card == null) return;

    await ref.read(repositoryProvider).reviewFlashcard(card, grade);
    final prefs = ref.read(sharedPreferencesProvider);
    final key = cardsReviewedKey(DateTime.now());
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);

    final rest = session.queue.skip(1).toList();
    state = AsyncValue.data(
      FlashcardSession(
        queue: grade == ReviewGrade.again ? [...rest, card] : rest,
        reviewed: session.reviewed + 1,
      ),
    );
    ref.invalidate(flashcardSummaryProvider);
    // XP/rozetler oturum bitince bir kez hesaplanır, her kartta değil.
    if (state.value?.isDone ?? false) ref.invalidate(gameProvider);
  }
}

final flashcardSessionProvider =
    AsyncNotifierProvider<FlashcardSessionNotifier, FlashcardSession>(
  FlashcardSessionNotifier.new,
  isAutoDispose: true,
);

// --- Günün hikayesi ---------------------------------------------------------

/// Bugünün hikayesi: varsa kayıttan devam eder, yoksa üretir.
///
/// Gemini'ye ulaşılamazsa yedek hikayeye düşer; ders gibi kilitlenmez.
class StoryNotifier extends AsyncNotifier<StoryState> {
  @override
  Future<StoryState> build() async {
    final repository = ref.read(repositoryProvider);
    final existing = await repository.storyFor(DateTime.now());
    if (existing != null) {
      final decoded = StoryState.decode(existing.contentJson);
      if (decoded != null) return decoded;
    }
    return _generate();
  }

  Future<StoryState> _generate() async {
    final repository = ref.read(repositoryProvider);
    final profile = await repository.profile();
    if (profile == null) {
      throw const LessonUnavailable('Önce profilini oluşturman gerekiyor.');
    }
    final today = (await ref.read(weekPlanProvider.future)).today;

    // Bugünün dersi üretildiyse kelimeleri hikayede de geçsin.
    final lesson = await repository.lessonFor(DateTime.now());
    final words = lesson == null
        ? const <String>[]
        : [
            for (final v
                in LessonState.decode(lesson.contentJson)?.lesson.vocab ??
                    const <VocabItem>[])
              v.word,
          ];

    final result = await ref.read(geminiServiceProvider).generateDailyStory(
          name: profile.name,
          level: profile.level,
          dailyMinutes: profile.dailyMinutes,
          grammarTopic: today?.grammarTopic ?? 'Mixed tenses',
          vocabTheme: today?.vocabTheme ?? 'Günlük hayat',
          targetWords: words,
        );

    final state = StoryState(story: result.story, offline: result.offline);
    await repository.saveStory(DateTime.now(), state);
    return state;
  }

  /// Çevrimdışı hikayenin yerine Gemini'den yenisini dener.
  Future<void> regenerate() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_generate);
  }

  Future<void> answer(int index, String option) async {
    final current = state.value;
    if (current == null || current.answers.containsKey(index)) return;
    final next = current.withAnswer(index, option);
    state = AsyncValue.data(next);
    await ref.read(repositoryProvider).saveStory(DateTime.now(), next);
    if (next.isFinished) {
      ref.invalidate(progressProvider);
      ref.invalidate(gameProvider);
    }
  }
}

final storyProvider = AsyncNotifierProvider<StoryNotifier, StoryState>(
  StoryNotifier.new,
  isAutoDispose: true,
  retry: (_, _) => null,
);

// --- İlerleme ---------------------------------------------------------------

/// İlerleme ekranının verisi.
class ProgressData {
  const ProgressData({
    required this.studiedDays,
    required this.weeklyScores,
    required this.currentStreak,
    required this.bestStreak,
    required this.lessonsCompleted,
    required this.totalMinutes,
    required this.cardsTotal,
    required this.cardsMature,
  });

  final Set<DateTime> studiedDays;

  /// Son haftaların ortalama ders skoru, eskiden yeniye. Ders yoksa null.
  final List<({DateTime weekStart, double? average})> weeklyScores;
  final int currentStreak;
  final int bestStreak;
  final int lessonsCompleted;
  final int totalMinutes;
  final int cardsTotal;
  final int cardsMature;
}

final progressProvider = FutureProvider<ProgressData>((ref) async {
  ref.watch(weekPlanProvider);
  final repository = ref.read(repositoryProvider);
  final profile = await repository.profile();
  final days = await repository.studiedDays();
  final lessons = await repository.completedLessons();
  final cards = await repository.flashcardCounts();

  const weeks = 8;
  final thisMonday = mondayOf(DateTime.now());
  final weeklyScores = [
    for (var i = weeks - 1; i >= 0; i--)
      () {
        final start =
            DateTime(thisMonday.year, thisMonday.month, thisMonday.day - 7 * i);
        final end = DateTime(start.year, start.month, start.day + 7);
        final scores = [
          for (final l in lessons)
            if (l.score != null &&
                !l.lessonDate.isBefore(start) &&
                l.lessonDate.isBefore(end))
              l.score!,
        ];
        return (
          weekStart: start,
          average: scores.isEmpty
              ? null
              : scores.reduce((a, b) => a + b) / scores.length,
        );
      }(),
  ];

  return ProgressData(
    studiedDays: days,
    weeklyScores: weeklyScores,
    currentStreak: profile?.streak ?? 0,
    bestStreak: bestStreakOf(days),
    lessonsCompleted: lessons.length,
    totalMinutes:
        (lessons.fold<int>(0, (sum, l) => sum + l.durationSeconds) / 60).round(),
    cardsTotal: cards.total,
    cardsMature: cards.mature,
  );
});

// --- Haftalık rapor ---------------------------------------------------------

/// Kayıtlı haftalık raporlar, en yeni önce.
class WeeklyReportsNotifier extends AsyncNotifier<List<WeeklyReport>> {
  @override
  Future<List<WeeklyReport>> build() async {
    final rows = await ref.read(repositoryProvider).weeklyReviews();
    return [
      for (final row in rows) ?WeeklyReport.decode(row.reportJson),
    ];
  }

  /// [date]'in haftası için raporu üretir (varsa yeniler).
  Future<WeeklyReport> generate({DateTime? date}) async {
    final repository = ref.read(repositoryProvider);
    final profile = await repository.profile();
    if (profile == null) {
      throw StateError('Rapor için önce profil oluşturulmalı');
    }

    final when = date ?? DateTime.now();
    final reviewed =
        ref.read(sharedPreferencesProvider).getInt(cardsReviewedKey(when)) ?? 0;
    final stats = await repository.weeklyStats(when, cardsReviewed: reviewed);
    final delta = recommendLevelDelta(stats);

    final result = await ref.read(geminiServiceProvider).generateWeeklyReport(
          name: profile.name,
          level: profile.level,
          stats: stats,
          levelDelta: delta,
        );

    final report = WeeklyReport(
      stats: stats,
      summary: result.commentary.summary,
      strengths: result.commentary.strengths,
      focus: result.commentary.focus,
      tip: result.commentary.tip,
      fromLevel: profile.level,
      suggestedLevel: shiftLevel(profile.level, delta),
      offline: result.offline,
    );
    await repository.saveWeeklyReport(report);
    state = await AsyncValue.guard(build);
    return report;
  }

  /// Raporun seviye önerisini profile uygular.
  Future<void> applyLevel(WeeklyReport report) async {
    if (!report.suggestsChange || report.applied) return;
    final repository = ref.read(repositoryProvider);
    await repository.updateLevel(report.suggestedLevel);
    await repository.saveWeeklyReport(report.copyWith(applied: true));
    // Yükseliş ayrı sayılır: aynı haftanın raporu yenilenirse "uygulandı"
    // bilgisi kaybolur, ödül kaybolmamalı.
    if (DifficultyLevel.fromCode(report.suggestedLevel).index >
        DifficultyLevel.fromCode(report.fromLevel).index) {
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setInt(levelUpsKey, (prefs.getInt(levelUpsKey) ?? 0) + 1);
    }
    await ref.read(profileProvider.notifier).refresh();
    state = await AsyncValue.guard(build);
    ref.invalidate(gameProvider);
  }
}

// --- Ödüller ----------------------------------------------------------------

/// Tüm haftalardaki flash kart tekrarlarının toplamı.
int totalCardsReviewed(SharedPreferences prefs) => [
      for (final key in prefs.getKeys())
        if (key.startsWith('cards_reviewed_')) prefs.getInt(key) ?? 0,
    ].fold(0, (a, b) => a + b);

/// XP, oyuncu seviyesi ve rozetler.
///
/// Plan değişince kendiliğinden yeniden hesaplanır. Tüm geçmişi taradığı
/// için her kart notunda değil; ders/hikaye bitişi, tekrar oturumu sonu ve
/// seviye değişimi gibi olaylarda açıkça geçersiz kılınır.
final gameProvider = FutureProvider<GameState>((ref) async {
  ref.watch(weekPlanProvider);
  final prefs = ref.read(sharedPreferencesProvider);
  final stats = await ref.read(repositoryProvider).gameStats(
        cardsReviewed: totalCardsReviewed(prefs),
        levelUps: prefs.getInt(levelUpsKey) ?? 0,
      );
  return GameState(stats);
});

/// Bugünkü hedef: ders, hikaye ve (deste doluysa) kart tekrarı.
final dailyGoalProvider = FutureProvider<DailyGoal>((ref) async {
  ref.watch(gameProvider);
  final week = await ref.watch(weekPlanProvider.future);
  final cards = await ref.watch(flashcardSummaryProvider.future);
  final repository = ref.read(repositoryProvider);
  final now = DateTime.now();

  final story = await repository.storyFor(now);
  final lessonDone = week.today?.status == 'completed';

  return DailyGoal(
    tasks: [
      DailyTask.lesson,
      DailyTask.story,
      if (cards.total > 0) DailyTask.cards,
    ],
    done: {
      if (lessonDone) DailyTask.lesson,
      if (story?.quizScore != null) DailyTask.story,
      if (cards.total > 0 && cards.due == 0) DailyTask.cards,
    },
  );
});

/// Hata defteri listesi.
final mistakesProvider = FutureProvider<List<Mistake>>((ref) {
  ref.watch(progressProvider);
  return ref.read(repositoryProvider).mistakes();
});

final weeklyReportsProvider =
    AsyncNotifierProvider<WeeklyReportsNotifier, List<WeeklyReport>>(
  WeeklyReportsNotifier.new,
);
