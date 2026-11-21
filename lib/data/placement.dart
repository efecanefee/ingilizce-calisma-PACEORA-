import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../app/constants.dart';

/// Seviye testinde ölçülen beceri.
enum PlacementSkill {
  grammar('Dilbilgisi', 'Boşluğa uyanı seç'),
  vocabulary('Kelime', 'Boşluğa uyan kelimeyi seç'),
  reading('Okuma', 'Metni oku, soruyu cevapla'),
  listening('Dinleme', 'Dinle, soruyu cevapla');

  const PlacementSkill(this.label, this.instruction);

  /// Sonuç ekranındaki kısa ad.
  final String label;

  /// Sorunun üstündeki yönerge.
  final String instruction;

  static PlacementSkill fromName(String? name) => PlacementSkill.values
      .firstWhere((s) => s.name == name, orElse: () => PlacementSkill.grammar);
}

/// Zorluk bandı: testin blokları bu bantlarla kurulur, puan bu bantların
/// ağırlığıyla hesaplanır.
enum PlacementBand {
  easy(1),
  medium(2),
  hard(3),
  veryHard(4);

  const PlacementBand(this.weight);

  /// Doğru cevabın puanı: zor soru daha çok kazandırır.
  final int weight;

  /// A2/B1- kolay, B1/B1+ orta, B2-/B2 zor, B2+/C1 çok zor.
  static PlacementBand of(DifficultyLevel level) =>
      PlacementBand.values[level.index ~/ 2];

  PlacementBand step(int delta) =>
      PlacementBand.values[(index + delta).clamp(
        0,
        PlacementBand.values.length - 1,
      )];
}

/// Seviye testi sorusu. Sorular cihazda durur; ağ ya da Gemini gerekmez.
class PlacementQuestion {
  const PlacementQuestion({
    required this.prompt,
    required this.options,
    required this.answer,
    required this.level,
    this.skill = PlacementSkill.grammar,
    this.topic = '',
    this.passage,
  });

  /// Boşluklu cümle (dilbilgisi, kelime) ya da metinle ilgili soru.
  final String prompt;
  final List<String> options;

  /// Doğru seçeneğin [options] içindeki sırası.
  final int answer;

  /// Sorunun ölçtüğü kademe.
  final DifficultyLevel level;

  final PlacementSkill skill;

  /// Konu etiketi (ör. `present_perfect`); aynı konudan çok soru gelmesin
  /// diye kullanılır.
  final String topic;

  /// Okumada gösterilen metin; dinlemede sesli okunan, gizli metin.
  final String? passage;

  PlacementBand get band => PlacementBand.of(level);

  bool isCorrect(int choice) => choice == answer;

  String get correctOption => options[answer];

  /// Seçenekleri karıştırır; doğru cevap yeni sırasına taşınır. Böylece
  /// test tekrarlandığında cevap konumu ezberlenemez.
  PlacementQuestion shuffled(Random random) {
    final order = List.generate(options.length, (i) => i)..shuffle(random);
    return PlacementQuestion(
      prompt: prompt,
      options: [for (final i in order) options[i]],
      answer: order.indexOf(answer),
      level: level,
      skill: skill,
      topic: topic,
      passage: passage,
    );
  }

  static PlacementQuestion? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final prompt = raw['prompt'];
    final options = raw['options'];
    final answer = raw['answer'];
    final level = raw['level'];
    if (prompt is! String ||
        options is! List<dynamic> ||
        options.length < 2 ||
        options.any((o) => o is! String) ||
        answer is! int ||
        answer < 0 ||
        answer >= options.length ||
        level is! String) {
      return null;
    }
    final skill = PlacementSkill.fromName(raw['skill'] as String?);
    final passage = raw['passage'] as String?;
    final needsPassage =
        skill == PlacementSkill.reading || skill == PlacementSkill.listening;
    if (needsPassage && (passage == null || passage.trim().isEmpty)) {
      return null;
    }
    return PlacementQuestion(
      prompt: prompt,
      options: options.cast<String>(),
      answer: answer,
      level: DifficultyLevel.fromCode(level),
      skill: skill,
      topic: (raw['topic'] as String?) ?? '',
      passage: needsPassage ? passage : null,
    );
  }
}

/// Testteki soru sayısı: 16 sabit bloklu soru + 4 uyarlanan kontrol sorusu.
const placementQuestionCount = 20;

/// İlk üç blok (16 soru). Zorluk düz artmaz, dalgalanır:
/// 1) 2 kolay, 1 orta, 1 zor · 2) 3 orta, 3 zor ·
/// 3) 2 orta, 2 zor, 2 çok zor. 4. blok cevaplara göre seçilir.
const placementBlocks = [
  [
    PlacementBand.easy,
    PlacementBand.easy,
    PlacementBand.medium,
    PlacementBand.hard,
  ],
  [
    PlacementBand.medium,
    PlacementBand.medium,
    PlacementBand.medium,
    PlacementBand.hard,
    PlacementBand.hard,
    PlacementBand.hard,
  ],
  [
    PlacementBand.medium,
    PlacementBand.medium,
    PlacementBand.hard,
    PlacementBand.hard,
    PlacementBand.veryHard,
    PlacementBand.veryHard,
  ],
];

/// Sabit blokların soru sayısı.
final placementFixedCount = placementBlocks.fold<int>(
  0,
  (sum, b) => sum + b.length,
);

/// 20 soruda beceri dağılımı hedefi.
const placementSkillQuota = {
  PlacementSkill.grammar: 8,
  PlacementSkill.vocabulary: 5,
  PlacementSkill.reading: 4,
  PlacementSkill.listening: 3,
};

/// Aynı konudan en fazla kaç soru gelebilir.
const placementTopicCap = 2;

/// Cihazdaki soru havuzu.
class PlacementBank {
  PlacementBank(this.questions);

  final List<PlacementQuestion> questions;

  static const assets = [
    'assets/placement/a2_b1.json',
    'assets/placement/b2_c1.json',
  ];

  static PlacementBank parse(Iterable<String> sources) => PlacementBank([
    for (final source in sources)
      for (final raw in jsonDecode(source) as List<dynamic>)
        ?PlacementQuestion.tryParse(raw),
  ]);

  static Future<PlacementBank> load([AssetBundle? bundle]) async {
    final b = bundle ?? rootBundle;
    return parse([for (final path in assets) await b.loadString(path)]);
  }
}

final placementBankProvider = FutureProvider<PlacementBank>(
  (ref) => PlacementBank.load(),
);

/// Bir test oturumunun soru seçimi: önce 16 bloklu soru, cevaplar gelince
/// tahmini seviyenin çevresinden 4 kontrol sorusu.
class PlacementDraw {
  PlacementDraw(this.bank, [Random? random]) : _random = random ?? Random();

  final PlacementBank bank;
  final Random _random;

  final _used = <PlacementQuestion>{};
  final _skills = <PlacementSkill, int>{};
  final _topics = <String, int>{};

  /// 1-3. bloklar. 1. blok kolaydan zora sıralı kalır (ısınma), diğer
  /// blokların içi karışık gelir.
  List<PlacementQuestion> fixedBlocks() => [
    for (var b = 0; b < placementBlocks.length; b++)
      ...() {
        final block = [for (final band in placementBlocks[b]) _pick(band)];
        if (b > 0) block.shuffle(_random);
        return block;
      }(),
  ];

  /// 4. blok: ilk 16 cevaba göre tahmin edilen bandın çevresinden 2 aynı,
  /// 1 üst, 1 alt bant sorusu; sırası karışık.
  List<PlacementQuestion> finalBlock(
    List<PlacementQuestion> asked,
    List<int> answers,
  ) {
    final estimate = scorePlacement(asked, answers).level;
    final band = PlacementBand.of(estimate);
    return [_pick(band), _pick(band), _pick(band.step(1)), _pick(band.step(-1))]
      ..shuffle(_random);
  }

  /// Bandından, kotası en çok açık becerinin sorusunu seçer. Konu sınırı
  /// tutmazsa gevşetilir; bant tükenirse komşu banda bakılır.
  PlacementQuestion _pick(PlacementBand band) {
    final asked = _used.length;
    for (final relaxTopic in [false, true]) {
      for (final candidateBand in [band, band.step(-1), band.step(1)]) {
        final pool = bank.questions.where(
          (q) =>
              q.band == candidateBand &&
              !_used.contains(q) &&
              (q.passage == null ||
                  !_used.any((u) => u.passage == q.passage)) &&
              (relaxTopic ||
                  q.topic.isEmpty ||
                  (_topics[q.topic] ?? 0) < placementTopicCap),
        );
        if (pool.isEmpty) continue;

        // Becerinin şu ana kadar alması gerekenle aldığı arasındaki fark.
        double deficit(PlacementSkill s) =>
            placementSkillQuota[s]! * (asked + 1) / placementQuestionCount -
            (_skills[s] ?? 0);
        final best = pool.map((q) => deficit(q.skill)).reduce(max);
        final choices = pool.where((q) => deficit(q.skill) == best).toList();
        final q = choices[_random.nextInt(choices.length)];

        _used.add(q);
        _skills.update(q.skill, (n) => n + 1, ifAbsent: () => 1);
        if (q.topic.isNotEmpty) {
          _topics.update(q.topic, (n) => n + 1, ifAbsent: () => 1);
        }
        return q.shuffled(_random);
      }
    }
    throw StateError('Seviye testi havuzu tükendi');
  }
}

/// Test sonucu.
class PlacementResult {
  const PlacementResult({
    required this.level,
    required this.correct,
    required this.total,
    required this.percent,
    required this.bySkill,
  });

  final DifficultyLevel level;
  final int correct;
  final int total;

  /// Ağırlıklı puan yüzdesi (0-100).
  final double percent;

  /// Beceri başına (doğru, toplam).
  final Map<PlacementSkill, (int, int)> bySkill;
}

/// Ağırlıklı puan eşikleri: yüzde bu değerlerin altındaysa o kademe.
/// A2 < 18 ≤ B1- < 30 ≤ B1 < 42 ≤ B1+ < 54 ≤ B2- < 64 ≤ B2 < 74 ≤ B2+ < 84 ≤ C1
const placementThresholds = [18.0, 30.0, 42.0, 54.0, 64.0, 74.0, 84.0];

/// Sorunun zorluğuna göre ağırlıklı puan. Şansla yükselmeyi önlemek için
/// banda göre sınır konur: zor soruların yarısı doğru değilse B1+'yı,
/// çok zorların yarısı doğru değilse B2+'yı, orta soruların %40'ı doğru
/// değilse B1-'i geçemez.
PlacementResult scorePlacement(
  List<PlacementQuestion> questions,
  List<int> answers,
) {
  var earned = 0;
  var possible = 0;
  var correct = 0;
  final bandRight = <PlacementBand, int>{};
  final bandTotal = <PlacementBand, int>{};
  final skillRight = <PlacementSkill, int>{};
  final skillTotal = <PlacementSkill, int>{};

  for (var i = 0; i < answers.length && i < questions.length; i++) {
    final q = questions[i];
    final ok = q.isCorrect(answers[i]);
    possible += q.band.weight;
    bandTotal.update(q.band, (n) => n + 1, ifAbsent: () => 1);
    skillTotal.update(q.skill, (n) => n + 1, ifAbsent: () => 1);
    if (ok) {
      correct++;
      earned += q.band.weight;
      bandRight.update(q.band, (n) => n + 1, ifAbsent: () => 1);
      skillRight.update(q.skill, (n) => n + 1, ifAbsent: () => 1);
    }
  }

  final percent = possible == 0 ? 0.0 : 100 * earned / possible;
  var index = placementThresholds.indexWhere((t) => percent < t);
  if (index == -1) index = DifficultyLevel.values.length - 1;

  double accuracy(PlacementBand b) {
    final total = bandTotal[b] ?? 0;
    return total == 0 ? 1 : (bandRight[b] ?? 0) / total;
  }

  if (accuracy(PlacementBand.veryHard) < 0.5) {
    index = min(index, DifficultyLevel.b2Plus.index);
  }
  if (accuracy(PlacementBand.hard) < 0.5) {
    index = min(index, DifficultyLevel.b1Plus.index);
  }
  if (accuracy(PlacementBand.medium) < 0.4) {
    index = min(index, DifficultyLevel.b1Minus.index);
  }

  return PlacementResult(
    level: DifficultyLevel.values[index],
    correct: correct,
    total: answers.length,
    percent: percent,
    bySkill: {
      for (final s in PlacementSkill.values)
        if ((skillTotal[s] ?? 0) > 0) s: (skillRight[s] ?? 0, skillTotal[s]!),
    },
  );
}

/// Testin sonucu cihazda saklanır (ayarlardaki seviye seçimi buna bakar).
abstract class PlacementRecord {
  static const levelKey = 'placement_level';

  static DifficultyLevel? read(SharedPreferences prefs) {
    final code = prefs.getString(levelKey);
    return code == null ? null : DifficultyLevel.fromCode(code);
  }

  static Future<void> save(SharedPreferences prefs, DifficultyLevel level) =>
      prefs.setString(levelKey, level.code);
}
