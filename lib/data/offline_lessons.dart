import 'dart:convert';

import 'package:flutter/services.dart';

import 'lesson_models.dart';

/// Uygulamanın içinde gelen hazır dersler.
///
/// Gemini anahtarı yoksa, ağ yoksa ya da kota dolduysa kullanıcı günün
/// dersini yine çalışabilsin diye: A2, B1, B2 ve C1 için yedek haftalık
/// programın her konusuna bir ders, haftanın tekrar günü için de bunlardan
/// karışık bir ders.
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

  /// Seviye kodunun ders grubu: A2, B1, B2 ya da C1. B1-/B1+ B1'e, B2-/B2+
  /// B2'ye gider.
  static String groupOf(String level) {
    if (level.startsWith('A')) return 'A2';
    if (level.startsWith('C')) return 'C1';
    return level.startsWith('B2') ? 'B2' : 'B1';
  }

  /// Günün dersi: konu birebir eşleşirse o, tekrar gününde karışık ders,
  /// aksi hâlde aynı seviye grubundan haftanın gününe göre bir ders.
  ///
  /// [size] verilirse ders günlük süreye göre kısaltılır ya da aynı seviye
  /// grubundaki diğer derslerden parça eklenerek uzatılır.
  DailyLesson? lessonFor({
    required String level,
    required String grammarTopic,
    required int dayIndex,
    LessonSize? size,
  }) {
    final base = _baseLessonFor(
      level: level,
      grammarTopic: grammarTopic,
      dayIndex: dayIndex,
    );
    if (base == null || size == null) return base;
    final group = groupOf(level);
    final extras = [
      for (final e in _entries)
        if (e.group == group && !identical(e.lesson, base)) e.lesson,
    ];
    return _fit(base, extras, size);
  }

  /// Dersi [size]'a uydurur: önce dersin kendi maddeleri, eksik kalırsa
  /// sırayla diğer derslerin maddeleri; tekrarlar atlanır.
  static DailyLesson _fit(
    DailyLesson base,
    List<DailyLesson> extras,
    LessonSize size,
  ) {
    List<T> take<T>(
      List<T> own,
      List<T> Function(DailyLesson) pick,
      Object Function(T) key,
      int count,
    ) {
      final seen = <Object>{};
      final out = <T>[];
      for (final item in [own, for (final l in extras) pick(l)].expand((x) => x)) {
        if (out.length >= count) break;
        if (seen.add(key(item))) out.add(item);
      }
      return out;
    }

    return DailyLesson(
      vocab: take(base.vocab, (l) => l.vocab, (v) => v.word, size.vocab),
      gapFill: take(
        base.gapFill,
        (l) => l.gapFill,
        (g) => g.sentence,
        size.gapFill,
      ),
      translate: take(
        base.translate,
        (l) => l.translate,
        (t) => t.tr,
        size.translate,
      ),
      quiz: take(base.quiz, (l) => l.quiz, (q) => q.question, size.quiz),
    );
  }

  DailyLesson? _baseLessonFor({
    required String level,
    required String grammarTopic,
    required int dayIndex,
  }) {
    // Her seviye kendi grubundan; grup boşsa en yakın B grubuna düşer.
    final group = groupOf(level);
    var pool = _entries.where((e) => e.group == group).toList();
    if (pool.isEmpty) {
      final nearest = group == 'A2' ? 'B1' : (group == 'C1' ? 'B2' : group);
      pool = _entries.where((e) => e.group == nearest).toList();
    }
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
