import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/constants.dart';
import '../app/motion.dart';
import 'providers.dart';

/// Kullanıcının Ayarlar'dan girdiği Gemini anahtarı.
///
/// Boş string, "kendi anahtarım yok" demektir; bu durumda derleme zamanında
/// verilen anahtar (`--dart-define`) kullanılır. Böylece uygulama kendi
/// telefonunda kurulum istemeden çalışır, başkasına verildiğinde ise karşı
/// taraf kendi kotasını kullanabilir.
class ApiKeyNotifier extends Notifier<String> {
  @override
  String build() =>
      ref.watch(sharedPreferencesProvider).getString(AppConstants.prefApiKey) ??
      '';

  Future<void> save(String value) async {
    final prefs = ref.read(sharedPreferencesProvider);
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await prefs.remove(AppConstants.prefApiKey);
    } else {
      await prefs.setString(AppConstants.prefApiKey, trimmed);
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
