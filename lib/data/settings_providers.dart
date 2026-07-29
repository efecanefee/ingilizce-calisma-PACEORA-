import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../app/constants.dart';
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
