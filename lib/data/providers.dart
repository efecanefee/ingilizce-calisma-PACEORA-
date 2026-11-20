import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/constants.dart';
import 'database.dart';
import 'gemini_service.dart';
import 'lesson_models.dart';
import 'match_game.dart';
import 'offline_lessons.dart';
import 'pronunciation.dart';
import 'reminder_service.dart';
import 'repository.dart';
import 'review_models.dart';
import 'rewards.dart';
import 'roleplay.dart';
import 'settings_providers.dart';
import 'srs.dart';
import 'story_models.dart';
import 'streak_freeze.dart';
import 'wardrobe.dart';
import 'word_lookup.dart';

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
    final index = clock.now().weekday - DateTime.monday;
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
    final now = clock.now();
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
      '$_offlinePrefix${mondayOf(clock.now()).toIso8601String()}';

  Future<WeeklyPlanResult> _generate(UserProfile profile) async {
    final result = await ref.read(geminiServiceProvider).generateWeeklyPlan(
          name: profile.name,
          level: profile.level,
          dailyMinutes: profile.dailyMinutes,
        );
    await ref
        .read(repositoryProvider)
        .replaceWeeklyPlan(clock.now(), result.days);
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
    if (_loadedDay == dayOf(clock.now())) return;
    state = await AsyncValue.guard(_loadOrGenerate);
  }

  /// Günü tamamlandı işaretler, streak'i günceller. Kaçırılan günler seri
  /// dondurma haklarıyla karşılanırsa haklar harcanır.
  Future<void> completeDay(WeeklyPlanDay day) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final bridged = await ref
        .read(repositoryProvider)
        .completeDay(day, freezes: FreezeState.read(prefs).owned);
    await FreezeState.consume(prefs, bridged);
    if (bridged.isNotEmpty) ref.invalidate(freezeProvider);
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
  return ref.read(repositoryProvider).lessonFor(clock.now());
});

/// Uygulamanın içinde gelen hazır dersler (Gemini'ye ulaşılamadığında).
final offlineLessonBankProvider = FutureProvider<OfflineLessonBank>(
  (ref) => OfflineLessonBank.load(rootBundle),
);

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
    _sessionStart = clock.now();

    final existing =
        await ref.read(repositoryProvider).lessonFor(clock.now());
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
    await repository.saveLesson(clock.now(), lessonState);
    return lessonState;
  }

  /// Gemini'ye ulaşılamadığında günün dersini hazır ders havuzundan açar.
  Future<void> useOfflineLesson() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(() async {
      final repository = ref.read(repositoryProvider);
      final profile = await repository.profile();
      final today = (await ref.read(weekPlanProvider.future)).today;
      if (profile == null || today == null) {
        throw const LessonUnavailable('Bugün için plan bulunamadı.');
      }
      final bank = await ref.read(offlineLessonBankProvider.future);
      final lesson = bank.lessonFor(
        level: profile.level,
        grammarTopic: today.grammarTopic,
        dayIndex: today.dayIndex,
      );
      if (lesson == null) {
        throw const LessonUnavailable('Hazır ders bulunamadı.');
      }
      final lessonState = LessonState(lesson: lesson, offline: true);
      await repository.saveLesson(clock.now(), lessonState);
      return lessonState;
    });
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
    await ref.read(repositoryProvider).saveLesson(clock.now(), next);
  }

  /// Dersi bitirir: skoru ve süreyi yazar, hataları deftere işler, günü kapatır.
  Future<void> finish() async {
    final current = state.value;
    if (current == null) return;

    final repository = ref.read(repositoryProvider);
    final now = clock.now();

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
    final key = cardsReviewedKey(clock.now());
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

// --- Kelime Rallisi ---------------------------------------------------------

/// Oyunun kartları; deste [matchMinPairs]'ten küçükse oyun açılmaz.
final matchDeckProvider = FutureProvider.autoDispose<List<MatchPair>>((
  ref,
) async {
  final cards = await ref.read(repositoryProvider).matchCards();
  return [
    for (final c in cards)
      MatchPair(id: c.id, word: c.word, meaning: c.meaning),
  ];
});

/// Rekor ve toplamlar; tur bitince geçersiz kılınır.
final matchRecordsProvider = Provider.autoDispose<MatchRecords>(
  (ref) => MatchRecords.read(ref.read(sharedPreferencesProvider)),
);

/// Biten turu kaydeder: rekor/XP güncellenir, karıştırılan kartların
/// tekrarı bugüne çekilir.
Future<MatchSummary> finishMatchRound(WidgetRef ref, MatchBoard board) async {
  final prefs = ref.read(sharedPreferencesProvider);
  final summary = board.summary(
    bestScoreBefore: MatchRecords.read(prefs).bestScore,
  );
  await MatchRecords.save(prefs, summary);
  await ref.read(repositoryProvider).pullFlashcardsToToday(board.confusedIds);
  ref.invalidate(matchRecordsProvider);
  ref.invalidate(flashcardSummaryProvider);
  ref.invalidate(gameProvider);
  return summary;
}

// --- Konuşma ve dinle-yaz ---------------------------------------------------

/// Bir pratik turunun cümleleri: destedeki örnek cümleler ve bugünün
/// hikayesi; yetmezse yerleşik cümleler.
final practiceSentencesProvider = FutureProvider.autoDispose<List<String>>((
  ref,
) async {
  final repository = ref.read(repositoryProvider);
  final candidates = [...await repository.flashcardExamples()];
  final story = await repository.storyFor(clock.now());
  if (story != null) {
    final state = StoryState.decode(story.contentJson);
    for (final p in state?.story.paragraphs ?? const <String>[]) {
      candidates.addAll(splitSentences(p));
    }
  }
  final picked = pickPracticeSentences(candidates);
  if (picked.length >= 5) return picked;
  return [
    ...picked,
    ...pickPracticeSentences(
      fallbackPracticeSentences.where((s) => !picked.contains(s)),
      count: 5 - picked.length,
    ),
  ];
});

/// Başarılı bir cümleyi kaydeder; XP ve rozetler yenilenir.
Future<void> recordGoodSentence(WidgetRef ref, {required bool spoken}) async {
  await SpeechRecords.addGood(
    ref.read(sharedPreferencesProvider),
    spoken: spoken,
  );
  ref.invalidate(gameProvider);
}

// --- Seri dondurma -----------------------------------------------------------

/// Eldeki haklar ve korunan günler; satın alma ve harcamada geçersiz kılınır.
final freezeProvider = Provider<FreezeState>(
  (ref) => FreezeState.read(ref.read(sharedPreferencesProvider)),
);

/// Ana ekranda gösterilecek seri ve durumu.
final streakDisplayProvider =
    Provider<({int streak, StreakStatus status, int freezesNeeded})>((ref) {
      final profile = ref.watch(profileProvider).value;
      final freezes = ref.watch(freezeProvider).owned;
      return displayStreak(
        stored: profile?.streak ?? 0,
        lastStudy: profile?.lastStudyDate,
        today: clock.now(),
        freezes: freezes,
      );
    });

/// Bir hak satın alır; harcanabilir XP yetmezse ya da sınırdaysa false.
Future<bool> buyFreeze(WidgetRef ref) async {
  final game = await ref.read(gameProvider.future);
  final ok = await FreezeState.buy(
    ref.read(sharedPreferencesProvider),
    totalXp: game.level.xp,
  );
  if (ok) ref.invalidate(freezeProvider);
  return ok;
}

/// Pace'in formaları; satın alma ve giydirmede geçersiz kılınır.
final wardrobeProvider = Provider<WardrobeState>(
  (ref) => WardrobeState.read(ref.read(sharedPreferencesProvider)),
);

/// Bir forma satın alıp giydirir; harcanabilir XP yetmezse false.
Future<bool> buyKit(WidgetRef ref, PaceKit kit) async {
  final game = await ref.read(gameProvider.future);
  final ok = await WardrobeState.buy(
    ref.read(sharedPreferencesProvider),
    kit,
    totalXp: game.level.xp,
  );
  if (ok) {
    ref.invalidate(wardrobeProvider);
    // Bakiye seri dondurma sayacıyla ortak.
    ref.invalidate(freezeProvider);
  }
  return ok;
}

/// Sahip olunan formayı giydirir.
Future<void> equipKit(WidgetRef ref, PaceKit kit) async {
  if (await WardrobeState.equip(ref.read(sharedPreferencesProvider), kit)) {
    ref.invalidate(wardrobeProvider);
  }
}

// --- Rol yapma sohbeti -------------------------------------------------------

class RoleplayState {
  const RoleplayState({
    required this.scenario,
    required this.messages,
    this.pending = false,
    this.error,
    this.goalReached = false,
    this.xpEarned,
  });

  final RoleplayScenario scenario;
  final List<ChatMessage> messages;

  /// Karakterin cevabı bekleniyor.
  final bool pending;

  /// Son istek başarısızsa açıklama; [RoleplayNotifier.retry] yeniden dener.
  final String? error;
  final bool goalReached;

  /// Sohbet bitirildiyse kazanılan XP (kısa sohbette 0); null = sürüyor.
  final int? xpEarned;

  bool get finished => xpEarned != null;

  int get userMessages =>
      messages.where((m) => m.speaker == Speaker.user).length;

  List<ChatMessage> get corrected => [
    for (final m in messages)
      if (m.correction != null) m,
  ];

  RoleplayState copyWith({
    List<ChatMessage>? messages,
    bool? pending,
    String? Function()? error,
    bool? goalReached,
    int? xpEarned,
  }) => RoleplayState(
    scenario: scenario,
    messages: messages ?? this.messages,
    pending: pending ?? this.pending,
    error: error != null ? error() : this.error,
    goalReached: goalReached ?? this.goalReached,
    xpEarned: xpEarned ?? this.xpEarned,
  );
}

class RoleplayNotifier extends Notifier<RoleplayState> {
  RoleplayNotifier(this.scenarioId);

  final String scenarioId;

  @override
  RoleplayState build() {
    final scenario = scenarioById(scenarioId) ?? roleplayScenarios.first;
    return RoleplayState(
      scenario: scenario,
      messages: [ChatMessage(Speaker.ai, scenario.opening)],
    );
  }

  Future<void> send(String text) async {
    final trimmed = text.trim();
    if (trimmed.isEmpty || state.pending || state.finished) return;
    state = state.copyWith(
      messages: [...state.messages, ChatMessage(Speaker.user, trimmed)],
    );
    await _ask();
  }

  /// Başarısız son isteği yeniden gönderir.
  Future<void> retry() async {
    if (state.pending || state.messages.last.speaker != Speaker.user) return;
    await _ask();
  }

  Future<void> _ask() async {
    state = state.copyWith(pending: true, error: () => null);
    final profile = await ref.read(repositoryProvider).profile();
    final result = await ref
        .read(geminiServiceProvider)
        .roleplayTurn(
          scenario: state.scenario,
          level: profile?.level ?? 'B1',
          name: profile?.name ?? 'Student',
          history: state.messages,
        );
    if (!ref.mounted) return;

    final turn = result.turn;
    if (turn == null) {
      state = state.copyWith(
        pending: false,
        error: () => result.error ?? 'Cevap alınamadı',
      );
      return;
    }
    final messages = [...state.messages];
    messages.last = messages.last.withCorrection(turn.correction);
    state = state.copyWith(
      messages: [...messages, ChatMessage(Speaker.ai, turn.reply)],
      pending: false,
      goalReached: state.goalReached || turn.goalReached,
    );
  }

  /// Sohbeti bitirir: XP kaydedilir, düzeltmeler hata defterine işlenir.
  Future<void> finish() async {
    if (state.finished || state.pending) return;
    final current = state;
    final xp = await RoleplayRecords.save(
      ref.read(sharedPreferencesProvider),
      scenarioId: current.scenario.id,
      userMessages: current.userMessages,
      goalReached: current.goalReached,
    );
    await ref.read(repositoryProvider).recordOutcomes([
      for (final m in current.corrected)
        AnswerOutcome(
          item: m.correction!.corrected,
          context:
              'Yazdığın: ${m.text}'
              '${m.correction!.explanationTr.isEmpty ? '' : ' — ${m.correction!.explanationTr}'}',
          type: 'chat',
          correct: false,
        ),
    ]);
    if (!ref.mounted) return;
    state = state.copyWith(xpEarned: xp);
    ref.invalidate(gameProvider);
    ref.invalidate(mistakesProvider);
    ref.invalidate(roleplayRecordsProvider);
  }
}

final roleplayProvider = NotifierProvider.autoDispose
    .family<RoleplayNotifier, RoleplayState, String>(RoleplayNotifier.new);

final roleplayRecordsProvider = Provider.autoDispose<RoleplayRecords>(
  (ref) => RoleplayRecords.read(ref.read(sharedPreferencesProvider)),
);

// --- Günün hikayesi ---------------------------------------------------------

/// Bugünün hikayesi: varsa kayıttan devam eder, yoksa üretir.
///
/// Gemini'ye ulaşılamazsa yedek hikayeye düşer; ders gibi kilitlenmez.
class StoryNotifier extends AsyncNotifier<StoryState> {
  @override
  Future<StoryState> build() async {
    final repository = ref.read(repositoryProvider);
    final existing = await repository.storyFor(clock.now());
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
    final lesson = await repository.lessonFor(clock.now());
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
    await repository.saveStory(clock.now(), state);
    return state;
  }

  /// Çevrimdışı hikayenin yerine Gemini'den yenisini dener.
  Future<void> regenerate() async {
    state = const AsyncValue.loading();
    state = await AsyncValue.guard(_generate);
  }

  /// Dokunulan kelimenin anlamı: önce sözlükçe, sonra önbellek, en son Gemini.
  ///
  /// Hata fırlatmaz; anlam bulunamazsa `error` dolu döner.
  Future<({WordMeaning? meaning, String? error})> lookup(
    String word,
    String sentence,
  ) async {
    final current = state.value;
    if (current == null) return (meaning: null, error: 'Hikaye yüklenmedi');

    if (glossaryMatch(current.story.glossary, word) case final g?) {
      return (
        meaning: WordMeaning(word: g.word, meaning: g.meaning),
        error: null,
      );
    }
    if (current.lookups[normalizeWord(word)] case final cached?) {
      return (meaning: cached, error: null);
    }

    final profile = await ref.read(repositoryProvider).profile();
    final result = await ref.read(geminiServiceProvider).translateWord(
          word: word,
          sentence: sentence,
          level: profile?.level ?? 'B1',
        );
    final meaning = result.meaning;
    // Ekran bu arada kapandıysa sağlayıcı atılmıştır; kayda dokunulmaz.
    if (meaning != null && ref.mounted) {
      final latest = state.value ?? current;
      final next = latest.withLookup(word, meaning);
      state = AsyncValue.data(next);
      await ref.read(repositoryProvider).saveStory(clock.now(), next);
    }
    return result;
  }

  /// Kelimeyi flash kart destesine ekler; zaten varsa false.
  Future<bool> addToPool(WordMeaning meaning, String sentence) async {
    final added = await ref.read(repositoryProvider).addFlashcards([
      (word: meaning.word, meaning: meaning.meaning, example: sentence),
    ], source: 'story');
    if (added > 0 && ref.mounted) {
      ref.invalidate(flashcardSummaryProvider);
      ref.invalidate(gameProvider);
    }
    return added > 0;
  }

  Future<void> answer(int index, String option) async {
    final current = state.value;
    if (current == null || current.answers.containsKey(index)) return;
    final next = current.withAnswer(index, option);
    state = AsyncValue.data(next);
    await ref.read(repositoryProvider).saveStory(clock.now(), next);
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
    this.frozenDays = const {},
    required this.weeklyScores,
    required this.currentStreak,
    required this.bestStreak,
    required this.lessonsCompleted,
    required this.totalMinutes,
    required this.cardsTotal,
    required this.cardsMature,
  });

  final Set<DateTime> studiedDays;

  /// Seri dondurma hakkıyla korunan günler.
  final Set<DateTime> frozenDays;

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
  final thisMonday = mondayOf(clock.now());
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

  final freeze = ref.watch(freezeProvider);
  final shown = displayStreak(
    stored: profile?.streak ?? 0,
    lastStudy: profile?.lastStudyDate,
    today: clock.now(),
    freezes: freeze.owned,
  );

  return ProgressData(
    studiedDays: days,
    frozenDays: freeze.frozenDays,
    weeklyScores: weeklyScores,
    currentStreak: shown.streak,
    // Hakla korunan günler takvimde boşluk bırakır; profildeki seri de
    // hesaba katılır.
    bestStreak: max(bestStreakOf(days), profile?.streak ?? 0),
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

    final when = date ?? clock.now();
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
  final match = MatchRecords.read(prefs);
  final speech = SpeechRecords.read(prefs);
  final roleplay = RoleplayRecords.read(prefs);
  final stats = await ref.read(repositoryProvider).gameStats(
        cardsReviewed: totalCardsReviewed(prefs),
        levelUps: prefs.getInt(levelUpsKey) ?? 0,
        matchXp: match.xp,
        bestMatches: match.bestMatches,
        speechXp: speech.xp,
        spokenGood: speech.spokenGood,
        roleplayXp: roleplay.xp,
        roleplays: roleplay.completed,
      );
  return GameState(stats);
});

/// Bugünkü hedef: ders, hikaye ve (deste doluysa) kart tekrarı.
final dailyGoalProvider = FutureProvider<DailyGoal>((ref) async {
  ref.watch(gameProvider);
  final week = await ref.watch(weekPlanProvider.future);
  final cards = await ref.watch(flashcardSummaryProvider.future);
  final repository = ref.read(repositoryProvider);
  final now = clock.now();

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
