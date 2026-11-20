import 'dart:convert';

import 'package:flutter/services.dart';

import 'lesson_models.dart';

/// Uygulamanın içinde gelen hazır dersler.
///
/// Gemini anahtarı yoksa, ağ yoksa ya da kota dolduysa kullanıcı günün
/// dersini yine çalışabilsin diye: B1 ve B2 için yedek haftalık programın
/// her konusuna bir ders, haftanın tekrar günü için de bunlardan karışık bir
/// ders.
class OfflineLessonBank {
  OfflineLessonBank(this._entries);

  static const asset = 'assets/lessons/offline_lessons.json';

  final List<_Entry> _entries;

  static Future<OfflineLessonBank> load(AssetBundle bundle) async =>
      OfflineLessonBank.parse(await bundle.loadString(asset));

  factory OfflineLessonBank.parse(String json) {
    final raw = jsonDecode(json) as Map<String, dynamic>;
    final entries = <_Entry>[];
    for (final item in raw['lessons'] as List<dynamic>) {
      final map = item as Map<String, dynamic>;
      final lesson = DailyLesson.tryParse(map['lesson']);
      if (lesson == null) continue;
      entries.add(
        _Entry(
          group: map['level'] as String,
          grammarTopic: map['grammarTopic'] as String,
          lesson: lesson,
        ),
      );
    }
    return OfflineLessonBank(entries);
  }

  int get length => _entries.length;

  /// Günün dersi: konu birebir eşleşirse o, tekrar gününde karışık ders,
  /// aksi hâlde aynı seviye grubundan haftanın gününe göre bir ders.
  DailyLesson? lessonFor({
    required String level,
    required String grammarTopic,
    required int dayIndex,
  }) {
    // A2 en yakın B1 grubuna, C1 B2 grubuna düşer.
    final upper = level.startsWith('B2') || level.startsWith('C');
    final group = upper ? 'B2' : 'B1';
    final pool = _entries.where((e) => e.group == group).toList();
    if (pool.isEmpty) return null;

    final topic = grammarTopic.trim().toLowerCase();
    for (final e in pool) {
      if (e.grammarTopic.toLowerCase() == topic) return e.lesson;
    }
    if (dayIndex == 6 || topic.contains('tekrar')) return _review(pool);
    return pool[dayIndex % pool.length].lesson;
  }

  /// Haftanın tekrarı: her dersten birer parça.
  DailyLesson _review(List<_Entry> pool) {
    final lessons = [for (final e in pool) e.lesson];
    return DailyLesson(
      vocab: [for (final l in lessons) l.vocab.first],
      gapFill: [
        for (var i = 0; i < lessons.length && i < 4; i++) lessons[i].gapFill[1],
      ],
      translate: [
        for (var i = lessons.length - 3; i < lessons.length; i++)
          if (i >= 0) lessons[i].translate.first,
      ],
      quiz: [
        for (var i = 0; i < lessons.length && i < 4; i++)
          lessons[lessons.length - 1 - i].quiz.first,
      ],
    );
  }
}

class _Entry {
  const _Entry({
    required this.group,
    required this.grammarTopic,
    required this.lesson,
  });

  final String group;
  final String grammarTopic;
  final DailyLesson lesson;
}
