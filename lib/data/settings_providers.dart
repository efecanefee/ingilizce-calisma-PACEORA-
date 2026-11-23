import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/constants.dart';
import '../app/motion.dart';
import '../app/sounds.dart';
import '../app/theme.dart';
import 'providers.dart';
import 'reminder_service.dart';

/// Anahtarın güvenli kasadaki adı.
const apiKeyStorageKey = 'gemini_api_key';

/// Telefonun güvenli kasası (Android Keystore / iOS Keychain).
final secureStorageProvider = Provider<FlutterSecureStorage>(
  (_) => const FlutterSecureStorage(),
);

/// Açılışta kasadan okunan anahtar; `main` bunu doldurur.
final storedApiKeyProvider = Provider<String>((_) => '');

/// Kasadaki anahtarı okur. Eski sürümler anahtarı SharedPreferences'ta düz
/// metin tutuyordu; bulunursa kasaya taşınır ve eski kayıt silinir.
Future<String> loadApiKey(
  SharedPreferences prefs,
  FlutterSecureStorage storage,
) async {
  try {
    final legacy = prefs.getString(AppConstants.prefApiKey);
    if (legacy != null) {
      if (legacy.isNotEmpty) {
        await storage.write(key: apiKeyStorageKey, value: legacy);
      }
      await prefs.remove(AppConstants.prefApiKey);
      return legacy;
    }
    return await storage.read(key: apiKeyStorageKey) ?? '';
  } catch (e) {
    // Kasa açılamazsa (bozuk anahtar deposu vb.) uygulama yine açılsın.
    debugPrint('Güvenli kasa okunamadı: $e');
    return '';
  }
}

/// Kullanıcının Ayarlar'dan girdiği Gemini anahtarı.
///
/// Boş string, "kendi anahtarım yok" demektir; bu durumda derleme zamanında
/// verilen anahtar (`--dart-define`) kullanılır. Böylece uygulama kendi
/// telefonunda kurulum istemeden çalışır, başkasına verildiğinde ise karşı
/// taraf kendi kotasını kullanabilir. Anahtar düz metin olarak değil,
/// güvenli kasada saklanır.
class ApiKeyNotifier extends Notifier<String> {
  @override
  String build() => ref.watch(storedApiKeyProvider);

  Future<void> save(String value) async {
    final storage = ref.read(secureStorageProvider);
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await storage.delete(key: apiKeyStorageKey);
    } else {
      await storage.write(key: apiKeyStorageKey, value: trimmed);
    }
    state = trimmed;
  }
}

final apiKeyProvider =
    NotifierProvider<ApiKeyNotifier, String>(ApiKeyNotifier.new);

/// Tema tercihi. Kayıt yoksa koyu temayla başlar; kullanıcının seçtiği
/// tema (sistem dahil) korunur.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored =
        ref.watch(sharedPreferencesProvider).getString(AppConstants.prefThemeMode);
    return switch (stored) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    };
  }

  Future<void> save(ThemeMode mode) async {
    await ref.read(sharedPreferencesProvider).setString(
          AppConstants.prefThemeMode,
          mode.name,
        );
    state = mode;
  }
}

final themeModeProvider =
    NotifierProvider<ThemeModeNotifier, ThemeMode>(ThemeModeNotifier.new);

/// Arayüz vurgu rengi. Varsayılan marka rengi lime.
class AccentNotifier extends Notifier<AppAccent> {
  @override
  AppAccent build() => AppAccent.fromName(
    ref.watch(sharedPreferencesProvider).getString(AppConstants.prefAccent),
  );

  Future<void> save(AppAccent accent) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(AppConstants.prefAccent, accent.name);
    state = accent;
  }
}

final accentProvider =
    NotifierProvider<AccentNotifier, AppAccent>(AccentNotifier.new);

/// Dokunsal geri bildirim (titreşim) açık mı.
class HapticsNotifier extends Notifier<bool> {
  static const _key = 'haptics_enabled';

  @override
  bool build() {
    final enabled =
        ref.watch(sharedPreferencesProvider).getBool(_key) ?? true;
    Haptics.enabled = enabled;
    return enabled;
  }

  Future<void> set(bool enabled) async {
    await ref.read(sharedPreferencesProvider).setBool(_key, enabled);
    Haptics.enabled = enabled;
    state = enabled;
    Haptics.tap();
  }
}

/// Doğru/yanlış cevap sesleri açık mı.
class SoundsNotifier extends Notifier<bool> {
  static const key = 'sound_effects_enabled';

  @override
  bool build() {
    final enabled = ref.watch(sharedPreferencesProvider).getBool(key) ?? true;
    Sounds.enabled = enabled;
    return enabled;
  }

  Future<void> set(bool enabled) async {
    await ref.read(sharedPreferencesProvider).setBool(key, enabled);
    Sounds.enabled = enabled;
    state = enabled;
    // Açılınca nasıl duyulduğunu hemen göster.
    if (enabled) Sounds.correct();
  }
}

final soundsProvider = NotifierProvider<SoundsNotifier, bool>(
  SoundsNotifier.new,
);

final hapticsProvider =
    NotifierProvider<HapticsNotifier, bool>(HapticsNotifier.new);

/// Günlük hatırlatma tercihi.
class ReminderSettings {
  const ReminderSettings({required this.enabled, required this.time});

  final bool enabled;
  final TimeOfDay time;
}

class ReminderNotifier extends Notifier<ReminderSettings> {
  @override
  ReminderSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final minutes = prefs.getInt(AppConstants.prefReminderMinutes) ??
        AppConstants.defaultReminderMinutes;
    return ReminderSettings(
      enabled: prefs.getBool(AppConstants.prefReminderEnabled) ?? false,
      time: TimeOfDay(hour: minutes ~/ 60, minute: minutes % 60),
    );
  }

  /// Hatırlatmayı açar/kapatır. İzin verilmezse kapalı kalır ve false döner.
  Future<bool> setEnabled(bool enabled) async {
    final service = ref.read(reminderServiceProvider);
    if (enabled) {
      if (!await service.requestPermission()) return false;
      await service.scheduleDaily(
        state.time,
        content: _content,
        skipToday: _skipToday,
      );
    } else {
      await service.cancel();
    }
    await ref
        .read(sharedPreferencesProvider)
        .setBool(AppConstants.prefReminderEnabled, enabled);
    state = ReminderSettings(enabled: enabled, time: state.time);
    return true;
  }

  Future<void> setTime(TimeOfDay time) async {
    await ref.read(sharedPreferencesProvider).setInt(
          AppConstants.prefReminderMinutes,
          time.hour * 60 + time.minute,
        );
    if (state.enabled) {
      await ref
          .read(reminderServiceProvider)
          .scheduleDaily(time, content: _content, skipToday: _skipToday);
    }
    state = ReminderSettings(enabled: state.enabled, time: time);
  }

  /// Açılışta zamanlamayı tazeler (saat dilimi değişmiş olabilir).
  Future<void> resync() async {
    if (state.enabled) {
      await ref
          .read(reminderServiceProvider)
          .scheduleDaily(state.time, content: _content, skipToday: _skipToday);
    }
  }

  ReminderContent _content = ReminderContent.fallback;
  bool _skipToday = false;

  /// Seri değişince bildirim metnini kişiselleştirir; bugün çalışıldıysa
  /// bugünün hatırlatması atlanır.
  Future<void> personalize({
    required int streak,
    required int nextMilestone,
    required bool doneToday,
  }) async {
    final content = reminderContentFor(streak: streak, next: nextMilestone);
    if (content.title == _content.title &&
        content.body == _content.body &&
        doneToday == _skipToday) {
      return;
    }
    _content = content;
    _skipToday = doneToday;
    await resync();
  }
}

final reminderProvider =
    NotifierProvider<ReminderNotifier, ReminderSettings>(ReminderNotifier.new);

/// Hatırlatma dışındaki bildirimler: Pazar akşamı haftalık rapor ve her
/// sabah günün kelimesi.
class ExtraNotifications {
  const ExtraNotifications({this.weekly = false, this.wordOfDay = false});

  final bool weekly;
  final bool wordOfDay;
}

/// Haftalık rapor bildirimi: Pazar 19:00.
const weeklyReportTime = TimeOfDay(hour: 19, minute: 0);

/// Günün kelimesi bildirimi: her sabah 09:00.
const wordOfDayTime = TimeOfDay(hour: 9, minute: 0);

/// Kelime destesi boşken kullanılan kelimeler.
const _starterWords = [
  ('look forward to', 'dört gözle beklemek'),
  ('get used to', 'alışmak'),
  ('figure out', 'çözmek, anlamak'),
  ('take advantage of', 'fırsatı değerlendirmek'),
  ('run out of', 'tükenmek, bitmek'),
  ('come up with', '(fikir) bulmak'),
  ('keep in touch', 'iletişimi sürdürmek'),
];

/// [date] için günün kelimesi: desteden, güne göre değişen bir kart.
({String word, String meaning}) wordOfDayFor(
  List<({String word, String meaning})> deck,
  DateTime date,
) {
  final pool = deck.isNotEmpty
      ? deck
      : [for (final (w, m) in _starterWords) (word: w, meaning: m)];
  final dayNumber = DateTime.utc(date.year, date.month, date.day)
      .difference(DateTime.utc(2026))
      .inDays;
  return pool[dayNumber.abs() % pool.length];
}

class ExtraNotificationsNotifier extends Notifier<ExtraNotifications> {
  static const weeklyKey = 'notify_weekly_report';
  static const wordKey = 'notify_word_of_day';

  @override
  ExtraNotifications build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    return ExtraNotifications(
      weekly: prefs.getBool(weeklyKey) ?? false,
      wordOfDay: prefs.getBool(wordKey) ?? false,
    );
  }

  /// İzin verilmezse kapalı kalır ve false döner.
  Future<bool> setWeekly(bool enabled) async {
    final service = ref.read(reminderServiceProvider);
    if (enabled) {
      if (!await service.requestPermission()) return false;
      await _scheduleWeekly();
    } else {
      await service.cancelId(NotificationIds.weeklyReport);
    }
    await ref.read(sharedPreferencesProvider).setBool(weeklyKey, enabled);
    state = ExtraNotifications(weekly: enabled, wordOfDay: state.wordOfDay);
    return true;
  }

  Future<bool> setWordOfDay(bool enabled) async {
    final service = ref.read(reminderServiceProvider);
    if (enabled) {
      if (!await service.requestPermission()) return false;
    } else {
      await service.cancelId(NotificationIds.wordOfDay);
    }
    await ref.read(sharedPreferencesProvider).setBool(wordKey, enabled);
    state = ExtraNotifications(weekly: state.weekly, wordOfDay: enabled);
    if (enabled) await scheduleNextWord();
    return true;
  }

  Future<void> _scheduleWeekly() => ref
      .read(reminderServiceProvider)
      .scheduleWeekly(
        id: NotificationIds.weeklyReport,
        weekday: DateTime.sunday,
        time: weeklyReportTime,
        content: const ReminderContent(
          title: 'Haftalık raporun hazır 📊',
          body:
              'Pace bu haftanı özetledi: ne kadar çalıştın, nerede '
              'zorlandın? Bir bak!',
        ),
      );

  /// Bir sonraki sabahın kelimesini kurar. Kelime destesi değiştikçe her
  /// açılışta yenilenir; bildirim içeriği kurulduğu anda sabitlenir.
  Future<void> scheduleNextWord({DateTime? now}) async {
    if (!state.wordOfDay) return;
    final at = now ?? DateTime.now();
    var next = DateTime(
      at.year,
      at.month,
      at.day,
      wordOfDayTime.hour,
      wordOfDayTime.minute,
    );
    if (!next.isAfter(at)) next = next.add(const Duration(days: 1));
    final db = ref.read(databaseProvider);
    final deck = [
      for (final c in await db.select(db.flashcards).get())
        (word: c.word, meaning: c.meaning),
    ];
    final word = wordOfDayFor(deck, next);
    await ref
        .read(reminderServiceProvider)
        .scheduleAt(
          id: NotificationIds.wordOfDay,
          at: next,
          content: ReminderContent(
            title: 'Günün kelimesi: ${word.word}',
            body: '${word.meaning} — bugün bir cümlede kullanmayı dene!',
          ),
        );
  }

  /// Açılışta zamanlamaları tazeler.
  Future<void> resync() async {
    if (state.weekly) await _scheduleWeekly();
    await scheduleNextWord();
  }
}

final extraNotificationsProvider =
    NotifierProvider<ExtraNotificationsNotifier, ExtraNotifications>(
      ExtraNotificationsNotifier.new,
    );

/// Kullanıcının genelde çalıştığı saate göre hatırlatma önerisi: son
/// derslerin başlangıç saatlerinin ortancasından yarım saat önce, çeyrek
/// saate yuvarlanmış. En az 5 ders gerekir; yoksa null.
TimeOfDay? suggestReminderTime(List<DateTime> lessonStarts) {
  if (lessonStarts.length < 5) return null;
  final minutes = [
    for (final d in lessonStarts.reversed.take(14)) d.hour * 60 + d.minute,
  ]..sort();
  final median = minutes[minutes.length ~/ 2];
  final target = ((median - 30) / 15).round() * 15;
  final clamped = target.clamp(6 * 60, 23 * 60);
  return TimeOfDay(hour: clamped ~/ 60, minute: clamped % 60);
}

/// Hatırlatma saati önerisi; mevcut saatten 45 dakikadan az farklıysa null.
final reminderSuggestionProvider = FutureProvider.autoDispose<TimeOfDay?>((
  ref,
) async {
  final current = ref.watch(reminderProvider).time;
  final lessons = await ref.read(repositoryProvider).completedLessons();
  final suggestion = suggestReminderTime([
    for (final l in lessons) l.createdAt.toLocal(),
  ]);
  if (suggestion == null) return null;
  final diff =
      (suggestion.hour * 60 + suggestion.minute) -
      (current.hour * 60 + current.minute);
  return diff.abs() < 45 ? null : suggestion;
});
