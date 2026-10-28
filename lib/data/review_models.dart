import 'dart:convert';

import '../app/constants.dart';
import 'gemini_json.dart';

/// Bir haftanın ölçülebilir özeti — rapor ve seviye önerisi bunun üzerine kurulur.
class WeeklyStats {
  const WeeklyStats({
    required this.weekStart,
    required this.daysCompleted,
    required this.lessonsCompleted,
    required this.averageLessonScore,
    required this.studyMinutes,
    required this.storiesRead,
    required this.averageStoryScore,
    required this.cardsReviewed,
    required this.openMistakes,
    required this.topMistakes,
  });

  final DateTime weekStart;
  final int daysCompleted;
  final int lessonsCompleted;

  /// Tamamlanan derslerin ortalama skoru (0-100); ders yoksa null.
  final double? averageLessonScore;
  final int studyMinutes;
  final int storiesRead;
  final double? averageStoryScore;
  final int cardsReviewed;
  final int openMistakes;

  /// En çok yanlış yapılan, henüz çözülmemiş ifadeler.
  final List<String> topMistakes;

  Map<String, dynamic> toJson() => {
        'weekStart': weekStart.toIso8601String(),
        'daysCompleted': daysCompleted,
        'lessonsCompleted': lessonsCompleted,
        'averageLessonScore': averageLessonScore,
        'studyMinutes': studyMinutes,
        'storiesRead': storiesRead,
        'averageStoryScore': averageStoryScore,
        'cardsReviewed': cardsReviewed,
        'openMistakes': openMistakes,
        'topMistakes': topMistakes,
      };

  static WeeklyStats? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final weekStart = DateTime.tryParse('${raw['weekStart']}');
    if (weekStart == null) return null;
    int readInt(String key) => (raw[key] as num?)?.toInt() ?? 0;
    double? readDouble(String key) => (raw[key] as num?)?.toDouble();
    return WeeklyStats(
      weekStart: weekStart,
      daysCompleted: readInt('daysCompleted'),
      lessonsCompleted: readInt('lessonsCompleted'),
      averageLessonScore: readDouble('averageLessonScore'),
      studyMinutes: readInt('studyMinutes'),
      storiesRead: readInt('storiesRead'),
      averageStoryScore: readDouble('averageStoryScore'),
      cardsReviewed: readInt('cardsReviewed'),
      openMistakes: readInt('openMistakes'),
      topMistakes: readStringList(raw, 'topMistakes'),
    );
  }
}

/// Haftanın verisine göre önerilen seviye değişimi: -1, 0 ya da +1 kademe.
///
/// Kural kasıtlı olarak tutucu: tek iyi ya da kötü bir gün seviyeyi
/// oynatmasın diye en az birkaç ders bitmiş olması gerekir.
/// - En az 3 ders, ortalama %85+ ve (okunduysa) hikayelerde %70+ → bir kademe yukarı
/// - En az 2 ders ve ortalama %55'in altı → bir kademe aşağı
int recommendLevelDelta(WeeklyStats stats) {
  final average = stats.averageLessonScore;
  if (average == null) return 0;

  final storyOk =
      stats.averageStoryScore == null || stats.averageStoryScore! >= 70;
  if (stats.lessonsCompleted >= 3 && average >= 85 && storyOk) return 1;
  if (stats.lessonsCompleted >= 2 && average < 55) return -1;
  return 0;
}

/// Haftalık değerlendirme raporu. `WeeklyReviews.reportJson` içine yazılır.
class WeeklyReport {
  const WeeklyReport({
    required this.stats,
    required this.summary,
    required this.strengths,
    required this.focus,
    required this.tip,
    required this.fromLevel,
    required this.suggestedLevel,
    this.applied = false,
    this.offline = false,
  });

  final WeeklyStats stats;

  /// Türkçe genel değerlendirme
  final String summary;
  final List<String> strengths;
  final List<String> focus;
  final String tip;

  /// Rapor üretildiğindeki seviye kodu
  final String fromLevel;

  /// Önerilen seviye kodu; [fromLevel] ile aynıysa değişiklik önerilmiyor.
  final String suggestedLevel;

  /// Öneri profile uygulandı mı?
  final bool applied;

  /// true ise yorum Gemini'den değil yerel şablondan geldi.
  final bool offline;

  bool get suggestsChange => suggestedLevel != fromLevel;

  WeeklyReport copyWith({bool? applied}) => WeeklyReport(
        stats: stats,
        summary: summary,
        strengths: strengths,
        focus: focus,
        tip: tip,
        fromLevel: fromLevel,
        suggestedLevel: suggestedLevel,
        applied: applied ?? this.applied,
        offline: offline,
      );

  String encode() => jsonEncode({
        'stats': stats.toJson(),
        'summary': summary,
        'strengths': strengths,
        'focus': focus,
        'tip': tip,
        'fromLevel': fromLevel,
        'suggestedLevel': suggestedLevel,
        'applied': applied,
        'offline': offline,
      });

  static WeeklyReport? decode(String json) {
    try {
      final raw = jsonDecode(json);
      if (raw is! Map<String, dynamic>) return null;
      final stats = WeeklyStats.fromJson(raw['stats']);
      if (stats == null) return null;
      return WeeklyReport(
        stats: stats,
        summary: readString(raw, 'summary'),
        strengths: readStringList(raw, 'strengths'),
        focus: readStringList(raw, 'focus'),
        tip: readString(raw, 'tip'),
        fromLevel: readString(raw, 'fromLevel'),
        suggestedLevel: readString(raw, 'suggestedLevel'),
        applied: raw['applied'] == true,
        offline: raw['offline'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Gemini'nin yazdığı yorum kısmı.
class ReportCommentary {
  const ReportCommentary({
    required this.summary,
    required this.strengths,
    required this.focus,
    required this.tip,
  });

  final String summary;
  final List<String> strengths;
  final List<String> focus;
  final String tip;
}

/// Gemini rapor yanıtını okur; özet yoksa null.
ReportCommentary? parseReportResponse(String responseBody) {
  final text = extractModelText(responseBody);
  if (text == null) return null;
  try {
    final raw = jsonDecode(text);
    if (raw is! Map<String, dynamic>) return null;
    final summary = readString(raw, 'summary');
    if (summary.isEmpty) return null;
    return ReportCommentary(
      summary: summary,
      strengths: readStringList(raw, 'strengths'),
      focus: readStringList(raw, 'focus'),
      tip: readString(raw, 'tip'),
    );
  } catch (_) {
    return null;
  }
}

/// Gemini'ye ulaşılamadığında istatistiklerden kurulan yorum.
ReportCommentary localCommentary(WeeklyStats stats, int levelDelta) {
  final average = stats.averageLessonScore?.round();

  final summary = switch (stats.lessonsCompleted) {
    0 when stats.daysCompleted == 0 =>
      'Bu hafta henüz çalışma kaydın yok. Küçük bir adımla başlamak bile seriyi '
          'yeniden kurar.',
    0 => 'Bu hafta ${stats.daysCompleted} gün çalıştın ama ders testini '
        'tamamlamadın; skorlu dersler ilerlemeni daha iyi ölçer.',
    _ => 'Bu hafta ${stats.daysCompleted} gün çalıştın, '
        '${stats.lessonsCompleted} ders bitirdin ve ortalama %$average '
        'başarı yakaladın.',
  };

  final strengths = <String>[
    if (stats.daysCompleted >= 5) 'Düzenli çalışma: haftanın çoğunu boş geçmedin.',
    if (average != null && average >= 80) 'Ders testlerinde yüksek doğruluk.',
    if ((stats.averageStoryScore ?? 0) >= 75) 'Okuduğunu anlama güçlü.',
    if (stats.cardsReviewed >= 20) 'Flash kart tekrarlarını aksatmadın.',
  ];
  if (strengths.isEmpty) strengths.add('Uygulamayı açıp devam etmen bile önemli bir adım.');

  final focus = <String>[
    if (stats.daysCompleted < 4) 'Daha düzenli çalış: hedef haftada en az 5 gün.',
    if (average != null && average < 65) 'Dersteki konuları tekrar et; hata defterindeki ifadeler sana yardımcı olur.',
    if (stats.storiesRead == 0) 'Günün hikayesini oku; okuma pratiği kelime dağarcığını genişletir.',
    if (stats.openMistakes > 0)
      '${stats.openMistakes} ifade hâlâ pekişmedi: ${stats.topMistakes.take(3).join(', ')}.',
  ];
  if (focus.isEmpty) focus.add('Böyle devam et; bir sonraki seviyeye hazırlanıyorsun.');

  final tip = switch (levelDelta) {
    1 => 'Sonuçların seviyenin üstünde. Bir kademe zorlaştırmayı deneyebilirsin.',
    -1 => 'Bu hafta zorlandın. Bir kademe kolaylaştırıp temeli sağlamlaştırmak iyi olur.',
    _ => 'Her gün 5 dakikalık flash kart tekrarı kalıcı öğrenmeyi çok hızlandırır.',
  };

  return ReportCommentary(
    summary: summary,
    strengths: strengths,
    focus: focus,
    tip: tip,
  );
}

/// [code] seviyesinden [delta] kademe ötedeki seviye kodu (B1- ile B2+ arası).
String shiftLevel(String code, int delta) =>
    DifficultyLevel.fromCode(code).step(delta).code;
