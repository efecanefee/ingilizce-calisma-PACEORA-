import 'dart:convert';

import 'package:clock/clock.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';

/// Hesap olmadığı için telefon değişince veriler kaybolmasın diye tüm
/// ilerlemenin tek bir JSON dosyasına yedeklenmesi ve geri yüklenmesi.
///
/// Dosyada veritabanının bütün tabloları ve SharedPreferences'taki ayarlar
/// (XP sayaçları, seri hakları, formalar, tema…) bulunur. API anahtarı güvenli
/// kasada durduğu için yedeğe girmez.
abstract final class Backup {
  static const format = 'paceora-yedek';
  static const version = 1;

  /// Önerilen dosya adı: paceora-yedek-2026-11-20.json
  static String fileName([DateTime? now]) {
    final d = now ?? clock.now();
    String two(int v) => v.toString().padLeft(2, '0');
    return 'paceora-yedek-${d.year}-${two(d.month)}-${two(d.day)}.json';
  }

  static Future<String> export(AppDatabase db, SharedPreferences prefs) async {
    final tables = <String, List<Map<String, dynamic>>>{
      'userProfiles': [
        for (final r in await db.select(db.userProfiles).get()) r.toJson(),
      ],
      'weeklyPlanDays': [
        for (final r in await db.select(db.weeklyPlanDays).get()) r.toJson(),
      ],
      'lessons': [for (final r in await db.select(db.lessons).get()) r.toJson()],
      'mistakes': [
        for (final r in await db.select(db.mistakes).get()) r.toJson(),
      ],
      'flashcards': [
        for (final r in await db.select(db.flashcards).get()) r.toJson(),
      ],
      'stories': [for (final r in await db.select(db.stories).get()) r.toJson()],
      'weeklyReviews': [
        for (final r in await db.select(db.weeklyReviews).get()) r.toJson(),
      ],
    };

    final settings = <String, Map<String, Object>>{};
    for (final key in prefs.getKeys()) {
      final value = prefs.get(key);
      final entry = switch (value) {
        final bool v => {'t': 'bool', 'v': v},
        final int v => {'t': 'int', 'v': v},
        final double v => {'t': 'double', 'v': v},
        final String v => {'t': 'string', 'v': v},
        final List<Object?> v => {
          't': 'list',
          'v': [for (final e in v) '$e'],
        },
        _ => null,
      };
      if (entry != null) settings[key] = entry;
    }

    return const JsonEncoder.withIndent(' ').convert({
      'format': format,
      'version': version,
      'schemaVersion': db.schemaVersion,
      'createdAt': clock.now().toIso8601String(),
      'tables': tables,
      'settings': settings,
    });
  }

  /// Yedeği geri yükler: mevcut veriler silinir, yedektekiler yazılır.
  /// Dosya Paceora yedeği değilse ya da daha yeni bir sürümden geliyorsa
  /// [FormatException] fırlatır ve hiçbir şeye dokunmaz.
  static Future<void> restore(
    String json,
    AppDatabase db,
    SharedPreferences prefs,
  ) async {
    final Object? decoded;
    try {
      decoded = jsonDecode(json);
    } on FormatException {
      throw const FormatException('Dosya okunamadı: geçerli bir JSON değil.');
    }
    if (decoded is! Map<String, dynamic> || decoded['format'] != format) {
      throw const FormatException('Bu dosya bir Paceora yedeği değil.');
    }
    final schema = decoded['schemaVersion'];
    if (schema is! int || schema > db.schemaVersion) {
      throw const FormatException(
        'Yedek uygulamanın daha yeni bir sürümünden. Önce uygulamayı güncelle.',
      );
    }
    final tables = decoded['tables'];
    if (tables is! Map<String, dynamic>) {
      throw const FormatException('Yedekte veri bulunamadı.');
    }

    List<Map<String, dynamic>> rows(String name) => [
      for (final r in (tables[name] as List<dynamic>? ?? const []))
        r as Map<String, dynamic>,
    ];

    // Önce hepsini ayrıştır: bozuk bir satır varsa mevcut veriler silinmeden
    // hata verilir.
    final profiles = rows('userProfiles').map(UserProfile.fromJson).toList();
    final plan = rows('weeklyPlanDays').map(WeeklyPlanDay.fromJson).toList();
    final lessons = rows('lessons').map(Lesson.fromJson).toList();
    final mistakes = rows('mistakes').map(Mistake.fromJson).toList();
    final cards = rows('flashcards').map(Flashcard.fromJson).toList();
    final stories = rows('stories').map(Story.fromJson).toList();
    final reviews = rows('weeklyReviews').map(WeeklyReview.fromJson).toList();

    await db.transaction(() async {
      for (final table in db.allTables) {
        await db.delete(table).go();
      }
      await db.batch((b) {
        b.insertAll(db.userProfiles, profiles);
        b.insertAll(db.weeklyPlanDays, plan);
        b.insertAll(db.lessons, lessons);
        b.insertAll(db.mistakes, mistakes);
        b.insertAll(db.flashcards, cards);
        b.insertAll(db.stories, stories);
        b.insertAll(db.weeklyReviews, reviews);
      });
    });

    final settings = decoded['settings'];
    if (settings is Map<String, dynamic>) {
      await prefs.clear();
      for (final MapEntry(:key, :value) in settings.entries) {
        if (value is! Map<String, dynamic>) continue;
        final v = value['v'];
        switch (value['t']) {
          case 'bool' when v is bool:
            await prefs.setBool(key, v);
          case 'int' when v is int:
            await prefs.setInt(key, v);
          case 'double' when v is num:
            await prefs.setDouble(key, v.toDouble());
          case 'string' when v is String:
            await prefs.setString(key, v);
          case 'list' when v is List<dynamic>:
            await prefs.setStringList(key, [for (final e in v) '$e']);
        }
      }
    }
  }
}
