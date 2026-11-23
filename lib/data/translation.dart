import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'providers.dart';

/// İngilizce metinlerin Türkçesi: yardım ("Türkçesi") düğmeleri için.
///
/// Aynı metin ikinci kez sorulmasın diye çeviriler cihazda saklanır
/// (SharedPreferences, en çok [maxEntries] kayıt; en eskiler atılır).
class TranslationCache {
  const TranslationCache(this._prefs);

  static const key = 'translation_cache';
  static const maxEntries = 400;

  final SharedPreferences _prefs;

  Map<String, String> _read() {
    try {
      final raw = jsonDecode(_prefs.getString(key) ?? '{}');
      if (raw is! Map<String, dynamic>) return {};
      return {
        for (final e in raw.entries)
          if (e.value is String) e.key: e.value as String,
      };
    } catch (_) {
      return {};
    }
  }

  String? get(String english) => _read()[english.trim()];

  Future<void> put(String english, String turkish) async {
    final map = _read()..remove(english.trim());
    map[english.trim()] = turkish;
    while (map.length > maxEntries) {
      map.remove(map.keys.first);
    }
    await _prefs.setString(key, jsonEncode(map));
  }
}

/// Çeviri alınamadığında fırlatılır; mesaj ekranda gösterilebilir.
class TranslationUnavailable implements Exception {
  const TranslationUnavailable(this.message);

  final String message;

  @override
  String toString() => message;
}

/// [english] metninin Türkçesi; önce önbellek, yoksa yapay zeka.
///
/// Otomatik yeniden deneme kapalı: kota dolduysa ya da internet yoksa arka
/// planda tekrar istek atılmasın. Düğme kapatılıp açılınca yeniden denenir.
final turkishProvider = FutureProvider.autoDispose.family<String, String>(
  retry: (_, _) => null,
  (ref, english) async {
    final cache = TranslationCache(ref.read(sharedPreferencesProvider));
    final cached = cache.get(english);
    if (cached != null) return cached;
    final result = await ref
        .read(geminiServiceProvider)
        .translateToTurkish(english);
    final text = result.text;
    if (text == null) {
      // Gerçek sebep gösterilir: her hata internet kaynaklı değil (kota,
      // yanıt vermeyen model).
      throw TranslationUnavailable(result.error ?? 'Çeviri şu an alınamadı.');
    }
    await cache.put(english, text);
    return text;
  },
);
