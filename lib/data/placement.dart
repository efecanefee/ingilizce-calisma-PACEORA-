import 'package:shared_preferences/shared_preferences.dart';

import '../app/constants.dart';

/// Kısa seviye testi: B1-'den B2+'ya kademe başına iki soru.
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
}

const placementQuestions = <PlacementQuestion>[
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
];

/// Doğru sayısından seviye: her kademe iki soru "değerinde".
///
/// 0-3 → B1-, 4-5 → B1, 6-7 → B1+, 8-9 → B2-, 10 → B2, 11-12 → B2+.
DifficultyLevel placementLevel(int correct) {
  if (correct <= 3) return DifficultyLevel.b1Minus;
  if (correct <= 5) return DifficultyLevel.b1;
  if (correct <= 7) return DifficultyLevel.b1Plus;
  if (correct <= 9) return DifficultyLevel.b2Minus;
  if (correct <= 10) return DifficultyLevel.b2;
  return DifficultyLevel.b2Plus;
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
