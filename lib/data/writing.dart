import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'gemini_json.dart';

/// Yazma pratiği: kullanıcı kısa bir paragraf yazar, yapay zeka hataları
/// işaretler ve Türkçe açıklar.

/// Yazının en az ve en çok uzunluğu (karakter).
const writingMinChars = 40;
const writingMaxChars = 700;

/// Değerlendirilen bir yazının XP'si.
int writingXp(int score) => 15 + (score / 10).round();

/// Yazıdaki tek bir hata.
class WritingIssue {
  const WritingIssue({
    required this.original,
    required this.fix,
    required this.explanationTr,
    required this.type,
  });

  /// Yazıda geçen hatalı parça (birebir).
  final String original;

  /// Önerilen doğru biçim.
  final String fix;

  /// Kısa Türkçe açıklama.
  final String explanationTr;

  /// grammar | vocabulary | spelling | style
  final String type;

  static WritingIssue? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final original = '${raw['original'] ?? ''}'.trim();
    final fix = '${raw['fix'] ?? ''}'.trim();
    if (original.isEmpty || fix.isEmpty || original == fix) return null;
    return WritingIssue(
      original: original,
      fix: fix,
      explanationTr: '${raw['explanationTr'] ?? ''}'.trim(),
      type: '${raw['type'] ?? 'grammar'}'.trim(),
    );
  }

  /// Türkçe tür adı.
  String get typeLabel => switch (type) {
    'vocabulary' => 'Kelime',
    'spelling' => 'Yazım',
    'style' => 'Üslup',
    _ => 'Dilbilgisi',
  };
}

/// Yapay zekanın değerlendirmesi.
class WritingFeedback {
  const WritingFeedback({
    required this.score,
    required this.corrected,
    required this.issues,
    required this.feedbackTr,
  });

  /// 0-100.
  final int score;

  /// Yazının düzeltilmiş hali.
  final String corrected;
  final List<WritingIssue> issues;

  /// Genel Türkçe yorum (1-2 cümle).
  final String feedbackTr;

  static WritingFeedback? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final score = raw['score'];
    final corrected = '${raw['corrected'] ?? ''}'.trim();
    if (score is! num || corrected.isEmpty) return null;
    final issues = raw['issues'];
    return WritingFeedback(
      score: score.round().clamp(0, 100),
      corrected: corrected,
      issues: [
        if (issues is List)
          for (final i in issues) ?WritingIssue.tryParse(i),
      ],
      feedbackTr: '${raw['feedbackTr'] ?? ''}'.trim(),
    );
  }
}

WritingFeedback? parseWritingResponse(String responseBody) {
  final text = extractModelText(responseBody);
  if (text == null) return null;
  try {
    return WritingFeedback.tryParse(jsonDecode(text));
  } catch (_) {
    return null;
  }
}

/// Metnin bir parçası: düz ya da işaretli hata.
class WritingSpan {
  const WritingSpan(this.text, [this.issue]);

  final String text;
  final WritingIssue? issue;
}

/// Yazıyı hatalı parçalar işaretli olacak biçimde böler.
///
/// Her hata metinde ilk geçtiği yerde, çakışmayacak şekilde işaretlenir;
/// metinde bulunamayan hata yalnızca listede görünür.
List<WritingSpan> markIssues(String text, List<WritingIssue> issues) {
  final marks = <({int start, int end, WritingIssue issue})>[];
  for (final issue in issues) {
    var from = 0;
    while (true) {
      final at = text.indexOf(issue.original, from);
      if (at < 0) break;
      final end = at + issue.original.length;
      final overlaps = marks.any((m) => at < m.end && end > m.start);
      if (!overlaps) {
        marks.add((start: at, end: end, issue: issue));
        break;
      }
      from = at + 1;
    }
  }
  marks.sort((a, b) => a.start.compareTo(b.start));
  final spans = <WritingSpan>[];
  var cursor = 0;
  for (final m in marks) {
    if (m.start > cursor) {
      spans.add(WritingSpan(text.substring(cursor, m.start)));
    }
    spans.add(WritingSpan(text.substring(m.start, m.end), m.issue));
    cursor = m.end;
  }
  if (cursor < text.length) spans.add(WritingSpan(text.substring(cursor)));
  return spans;
}

/// Yazma için konu önerileri; günün kelime temasıyla da birleştirilir.
const writingPrompts = <String>[
  'Dün ne yaptığını anlat.',
  'Hafta sonu planlarını yaz.',
  'En sevdiğin yemeği ve nedenini anlat.',
  'Bir arkadaşına kısa bir e-posta yaz: onu bir etkinliğe davet et.',
  'Yaşadığın şehrin iyi ve kötü yanlarını yaz.',
  'Unutamadığın bir yolculuğu anlat.',
  'Gelecekte nerede yaşamak isterdin? Neden?',
  'Teknolojinin hayatını nasıl değiştirdiğini yaz.',
];

/// Yazma kayıtları (SharedPreferences, `writing_` önekli).
class WritingRecords {
  const WritingRecords({this.count = 0, this.xp = 0, this.bestScore = 0});

  static const countKey = 'writing_count';
  static const xpKey = 'writing_xp';
  static const bestKey = 'writing_best';

  final int count;
  final int xp;
  final int bestScore;

  factory WritingRecords.read(SharedPreferences prefs) => WritingRecords(
    count: prefs.getInt(countKey) ?? 0,
    xp: prefs.getInt(xpKey) ?? 0,
    bestScore: prefs.getInt(bestKey) ?? 0,
  );

  /// Değerlendirilen yazıyı kaydeder, kazanılan XP'yi döner.
  static Future<int> save(SharedPreferences prefs, int score) async {
    final old = WritingRecords.read(prefs);
    final xp = writingXp(score);
    await prefs.setInt(countKey, old.count + 1);
    await prefs.setInt(xpKey, old.xp + xp);
    if (score > old.bestScore) await prefs.setInt(bestKey, score);
    return xp;
  }
}
