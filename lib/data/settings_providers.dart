import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/constants.dart';
import '../app/motion.dart';
import '../app/theme.dart';
import 'providers.dart';

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

/// Tema tercihi. Varsayılan sistem ayarını izler.
class ThemeModeNotifier extends Notifier<ThemeMode> {
  @override
  ThemeMode build() {
    final stored =
        ref.watch(sharedPreferencesProvider).getString(AppConstants.prefThemeMode);
    return switch (stored) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
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
      await service.scheduleDaily(state.time);
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
      await ref.read(reminderServiceProvider).scheduleDaily(time);
    }
    state = ReminderSettings(enabled: state.enabled, time: time);
  }

  /// Açılışta zamanlamayı tazeler (saat dilimi değişmiş olabilir).
  Future<void> resync() async {
    if (state.enabled) {
      await ref.read(reminderServiceProvider).scheduleDaily(state.time);
    }
  }
}

final reminderProvider =
    NotifierProvider<ReminderNotifier, ReminderSettings>(ReminderNotifier.new);
