import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../app/constants.dart';
import 'level_check.dart';

/// Kısa seviye testi: A2'den C1'e kademe başına iki soru.
///
/// Sorular cihazda durur; ağ ya da Gemini gerekmez. Doğru sayısı
/// [placementLevel] ile bir [DifficultyLevel]'a çevrilir.
class PlacementQuestion {
  const PlacementQuestion({
    required this.prompt,
    required this.options,
    required this.answer,
    required this.level,
  });

  /// Boşluklu cümle ya da soru.
  final String prompt;
  final List<String> options;

  /// Doğru seçeneğin [options] içindeki sırası.
  final int answer;

  /// Sorunun ölçtüğü kademe (kolaydan zora sıralı).
  final DifficultyLevel level;

  bool isCorrect(int choice) => choice == answer;

  /// Seçenekleri karıştırır; doğru cevap yeni sırasına taşınır. Böylece
  /// test tekrarlandığında cevap konumu ezberlenemez.
  PlacementQuestion shuffled(Random random) {
    final order = List.generate(options.length, (i) => i)..shuffle(random);
    return PlacementQuestion(
      prompt: prompt,
      options: [for (final i in order) options[i]],
      answer: order.indexOf(answer),
      level: level,
    );
  }

  String get correctOption => options[answer];
}

/// Kademe başına soru havuzu: seviye testinin kendi soruları ve seviye
/// önizlemesindeki kontrol soruları (kademe başına 6 soru).
List<PlacementQuestion> placementPool(DifficultyLevel level) => [
  ...placementQuestions.where((q) => q.level == level),
  ...LevelPreview.of(level).questions,
];

/// Her test için kademe başına havuzdan 2 soru çeker (kolaydan zora),
/// seçenekleri karıştırır.
List<PlacementQuestion> drawPlacementQuestions([Random? random]) {
  final r = random ?? Random();
  return [
    for (final level in DifficultyLevel.values)
      ...(placementPool(level)..shuffle(r)).take(2).map((q) => q.shuffled(r)),
  ];
}

const placementQuestions = <PlacementQuestion>[
  PlacementQuestion(
    prompt: 'My sister ___ a doctor.',
    options: ['are', 'is', 'am', 'be'],
    answer: 1,
    level: DifficultyLevel.a2,
  ),
  PlacementQuestion(
    prompt: 'We ___ to the cinema last night.',
    options: ['go', 'goes', 'went', 'going'],
    answer: 2,
    level: DifficultyLevel.a2,
  ),
  PlacementQuestion(
    prompt: 'She ___ to work by bus every day.',
    options: ['go', 'goes', 'going', 'gone'],
    answer: 1,
    level: DifficultyLevel.b1Minus,
  ),
  PlacementQuestion(
    prompt: "I haven't seen him ___ last Monday.",
    options: ['for', 'ago', 'since', 'from'],
    answer: 2,
    level: DifficultyLevel.b1Minus,
  ),
  PlacementQuestion(
    prompt: "If it ___ tomorrow, we'll stay at home.",
    options: ['rains', 'will rain', 'rained', 'would rain'],
    answer: 0,
    level: DifficultyLevel.b1,
  ),
  PlacementQuestion(
    prompt: 'This is the book ___ I told you about.',
    options: ['who', 'where', 'what', 'that'],
    answer: 3,
    level: DifficultyLevel.b1,
  ),
  PlacementQuestion(
    prompt: 'By the time we arrived, the film ___.',
    options: [
      'has already started',
      'had already started',
      'already starts',
      'was already start',
    ],
    answer: 1,
    level: DifficultyLevel.b1Plus,
  ),
  PlacementQuestion(
    prompt: "I'm not used to ___ up so early.",
    options: ['get', 'got', 'getting', 'be getting'],
    answer: 2,
    level: DifficultyLevel.b1Plus,
  ),
  PlacementQuestion(
    prompt: 'He suggested ___ a taxi to the airport.',
    options: ['taking', 'to take', 'take', 'that taking'],
    answer: 0,
    level: DifficultyLevel.b2Minus,
  ),
  PlacementQuestion(
    prompt: 'If I ___ more free time, I would learn Japanese.',
    options: ['have', 'would have', 'will have', 'had'],
    answer: 3,
    level: DifficultyLevel.b2Minus,
  ),
  PlacementQuestion(
    prompt: 'The report ___ by the time the manager arrives.',
    options: [
      'will finish',
      'will have been finished',
      'is finishing',
      'has finished',
    ],
    answer: 1,
    level: DifficultyLevel.b2,
  ),
  PlacementQuestion(
    prompt: 'Hardly ___ the house when it started to rain.',
    options: ['I had left', 'did I leave', 'had I left', 'I left'],
    answer: 2,
    level: DifficultyLevel.b2,
  ),
  PlacementQuestion(
    prompt: "I'd rather you ___ tell anyone about this yet.",
    options: ["didn't", "don't", "won't", 'not'],
    answer: 0,
    level: DifficultyLevel.b2Plus,
  ),
  PlacementQuestion(
    prompt: 'She was ___ about the results and refused to comment.',
    options: ['talkative', 'eager', 'obvious', 'reticent'],
    answer: 3,
    level: DifficultyLevel.b2Plus,
  ),
  PlacementQuestion(
    prompt: 'Little ___ that the decision would change everything.',
    options: ['they knew', 'did they know', 'knew they', 'they did know'],
    answer: 1,
    level: DifficultyLevel.c1,
  ),
  PlacementQuestion(
    prompt: 'The proposal was rejected on the ___ that it was too costly.',
    options: ['grounds', 'reasons', 'basis', 'causes'],
    answer: 0,
    level: DifficultyLevel.c1,
  ),
];

/// Testteki soru sayısı: kademe başına 2.
int get placementQuestionCount => DifficultyLevel.values.length * 2;

/// Doğru sayısından seviye (16 soru, 8 kademe):
/// 0-3 → A2, 4-5 → B1-, 6-7 → B1, 8-9 → B1+, 10-11 → B2-, 12-13 → B2,
/// 14 → B2+, 15-16 → C1.
DifficultyLevel placementLevel(int correct) {
  const thresholds = [3, 5, 7, 9, 11, 13, 14];
  for (var i = 0; i < thresholds.length; i++) {
    if (correct <= thresholds[i]) return DifficultyLevel.values[i];
  }
  return DifficultyLevel.values.last;
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
