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

/// Testteki soru sayısı.
const placementQuestionCount = 20;

/// Bölümlerin soru sayısı. İlk bölüm herkese aynı zorlukta (kolaydan ortaya)
/// gelir; sonraki her bölüm o ana kadarki cevaplara göre seçilir.
const placementBlockSizes = [4, 6, 6, 4];

/// Isınma bölümü: 2 kolay, 2 orta.
const placementWarmup = [
  PlacementBand.easy,
  PlacementBand.easy,
  PlacementBand.medium,
  PlacementBand.medium,
];

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

/// Bir test oturumunun soru seçimi. Bölüm bölüm ilerler; her bölümün
/// zorluğu o ana kadarki cevaplara göre belirlenir, böylece zorlanan
/// öğrenciye üst düzey soru yağmaz, iyi giden de kolaylarda oyalanmaz.
class PlacementDraw {
  PlacementDraw(this.bank, [Random? random]) : _random = random ?? Random();

  final PlacementBank bank;
  final Random _random;

  final _used = <PlacementQuestion>{};
  final _skills = <PlacementSkill, int>{};
  final _topics = <String, int>{};

  /// Seçilen bölümlerin (karıştırılmamış) soruları; geri alınca iade edilir.
  final _blocks = <List<PlacementQuestion>>[];
  var _current = <PlacementQuestion>[];

  /// Sıradaki bölüm. [asked] ve [answers] o ana kadarki test.
  List<PlacementQuestion> nextBlock(
    List<PlacementQuestion> asked,
    List<int> answers,
  ) {
    final index = _blocks.length;
    final bands = index == 0
        ? placementWarmup
        : _bandsAround(
            // Aşağı yuvarlanır: az cevapla yapılan tahmin öğrenciyi boyunu
            // aşan bölüme itmesin.
            PlacementBand.of(
              DifficultyLevel.values[estimateAbility(
                asked,
                answers,
              ).floor().clamp(0, DifficultyLevel.values.length - 1)],
            ),
            placementBlockSizes[index],
          );
    _current = [];
    final block = [for (final band in bands) _pick(band)];
    _blocks.add(_current);
    // Isınma sırayla gelir; diğer bölümlerin içi karışık.
    if (index > 0) block.shuffle(_random);
    return block;
  }

  /// Bölümdeki bantlar: bir alt, bir üst, gerisi öğrencinin bandı.
  List<PlacementBand> _bandsAround(PlacementBand band, int count) => [
    band.step(-1),
    for (var i = 0; i < count - 2; i++) band,
    band.step(1),
  ];

  /// Son bölümü geri alır; sorular havuza döner (kullanıcı "Önceki" ile
  /// önceki bölüme geçti).
  void dropLastBlock() {
    for (final q in _blocks.removeLast()) {
      _used.remove(q);
      _skills.update(q.skill, (n) => n - 1);
      if (q.topic.isNotEmpty) _topics.update(q.topic, (n) => n - 1);
    }
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
        _current.add(q);
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

/// Yetenek tahmininin ızgarası ve öncülü. Kademeler 0 (A2) – 7 (C1);
/// ızgara iki uçtan taşar ki uç kademelere de ulaşılabilsin.
const _abilityMin = -2.0;
const _abilityMax = 9.0;
const _abilityStep = 0.25;
const _priorMean = 2.0;
const _priorSd = 2.6;

/// Cevaplardan öğrencinin yeteneğini tahmin eder (3 parametreli madde tepki
/// kuramı, sonsal ortalama). Uyarlanan testte herkes farklı zorlukta soru
/// gördüğü için doğru yüzdesi karşılaştırılamaz: kolay soruların hepsini
/// bilen, zorların yarısını bilenden "daha iyi" görünürdü. Burada her sorunun
/// kademesi ve şansla bilme payı (1/seçenek) hesaba katılır.
double estimateAbility(List<PlacementQuestion> questions, List<int> answers) {
  var total = 0.0;
  var weighted = 0.0;
  for (var t = _abilityMin; t <= _abilityMax; t += _abilityStep) {
    var logP = -pow((t - _priorMean) / _priorSd, 2) / 2;
    for (var i = 0; i < answers.length && i < questions.length; i++) {
      final q = questions[i];
      final guess = 1 / q.options.length;
      // Kademesindeki soruyu öğrenci ~%70 bilir.
      final p =
          guess + (1 - guess) / (1 + exp(-1.1 * (t - q.level.index + 0.4)));
      logP += log(q.isCorrect(answers[i]) ? p : 1 - p);
    }
    final weight = exp(logP);
    total += weight;
    weighted += weight * t;
  }
  return total == 0 ? _priorMean : weighted / total;
}

/// Testin sonucu: seviye [estimateAbility]'den, yüzde ağırlıklı doğrulardan.
PlacementResult scorePlacement(
  List<PlacementQuestion> questions,
  List<int> answers,
) {
  var earned = 0;
  var possible = 0;
  var correct = 0;
  final skillRight = <PlacementSkill, int>{};
  final skillTotal = <PlacementSkill, int>{};

  for (var i = 0; i < answers.length && i < questions.length; i++) {
    final q = questions[i];
    possible += q.band.weight;
    skillTotal.update(q.skill, (n) => n + 1, ifAbsent: () => 1);
    if (q.isCorrect(answers[i])) {
      correct++;
      earned += q.band.weight;
      skillRight.update(q.skill, (n) => n + 1, ifAbsent: () => 1);
    }
  }

  final index = estimateAbility(
    questions,
    answers,
  ).round().clamp(0, DifficultyLevel.values.length - 1);

  return PlacementResult(
    level: DifficultyLevel.values[index],
    correct: correct,
    total: answers.length,
    percent: possible == 0 ? 0 : 100 * earned / possible,
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
