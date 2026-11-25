import 'dart:convert';
import 'dart:math';

import 'package:flutter/services.dart';

import '../app/constants.dart';
import 'match_game.dart';

/// Uygulamayla gelen, seviyelere ayrılmış kelime listesi (Kelime Rallisi).
class LevelWords {
  LevelWords(this._byLevel);

  static const asset = 'assets/words/level_words.json';

  final Map<String, List<({String word, String meaning})>> _byLevel;

  static Future<LevelWords> load(AssetBundle bundle) async =>
      LevelWords.parse(await bundle.loadString(asset));

  factory LevelWords.parse(String json) {
    final raw = jsonDecode(json) as Map<String, dynamic>;
    return LevelWords({
      for (final MapEntry(:key, :value) in raw.entries)
        key: [
          for (final pair in (value as List<dynamic>).cast<List<dynamic>>())
            (word: pair[0] as String, meaning: pair[1] as String),
        ],
    });
  }

  List<({String word, String meaning})> of(DifficultyLevel level) =>
      _byLevel[level.code] ?? const [];
}

/// Rallide bir alt seviyeden gelen pekiştirme kelimesi sayısı.
const matchReviewWords = 12;

/// Rallide kullanıcının kendi destesinden gelen kelime sayısı.
const matchOwnWords = 10;

/// Rallinin kelimeleri: seviyenin bütün listesi, biraz alt seviye ve
/// kullanıcının kendi kartlarından birkaç tane. Böylece oyun o günkü derse
/// değil seviyeye göre kurulur.
///
/// [own]: kullanıcının kısa kartları. Aynı kelime listede de varsa kart öne
/// geçer (karıştırılınca tekrarı bugüne çekilebilsin). Listeden gelenlerin
/// kimliği eksidir; flash kartlarla çakışmaz.
List<MatchPair> levelMatchDeck({
  required LevelWords words,
  required String level,
  required List<MatchPair> own,
  Random? random,
}) {
  final current = DifficultyLevel.fromCode(level);
  final below = [if (current.index > 0) ...words.of(current.step(-1))]
    ..shuffle(random);
  final mine = [
    for (final p in own)
      if (_fitsTile(p)) p,
  ]..shuffle(random);

  final seen = <String>{};
  final deck = <MatchPair>[
    for (final p in mine.take(matchOwnWords))
      if (seen.add(p.word.trim().toLowerCase())) p,
  ];
  for (final w in [...words.of(current), ...below.take(matchReviewWords)]) {
    if (!seen.add(w.word.toLowerCase())) continue;
    deck.add(MatchPair(id: -deck.length - 1, word: w.word, meaning: w.meaning));
  }
  return deck;
}

/// Hata kartlarında kelime yerine bütün cümle olabilir; kutucuğa sığmaz.
bool _fitsTile(MatchPair p) =>
    p.word.length <= 24 &&
    p.meaning.length <= 32 &&
    !p.word.contains('___') &&
    !p.meaning.contains('___') &&
    !p.meaning.trim().endsWith('?');
