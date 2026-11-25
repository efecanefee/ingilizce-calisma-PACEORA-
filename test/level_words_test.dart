import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/constants.dart';
import 'package:paceora/data/level_words.dart';
import 'package:paceora/data/match_game.dart';

void main() {
  final words = LevelWords.parse(File(LevelWords.asset).readAsStringSync());
  String norm(String s) => s.trim().toLowerCase();

  test('her seviyede yeterli, tekrarsız ve kutucuğa sığan kelime var', () {
    final all = <String>{};
    for (final level in DifficultyLevel.values) {
      final list = words.of(level);
      expect(list.length, greaterThanOrEqualTo(50), reason: level.code);
      expect({for (final w in list) norm(w.meaning)}, hasLength(list.length));
      for (final w in list) {
        expect(all.add(norm(w.word)), isTrue, reason: '${w.word} iki kez');
        expect(w.word.length, lessThanOrEqualTo(20), reason: w.word);
        expect(w.meaning.length, lessThanOrEqualTo(28), reason: w.meaning);
      }
    }
  });

  List<MatchPair> deck(String level, [List<MatchPair> own = const []]) =>
      levelMatchDeck(words: words, level: level, own: own, random: Random(1));

  test('deste seviyeye göre kurulur, alt seviyeden biraz pekiştirme gelir', () {
    final b1 = deck('B1');
    final own = words.of(DifficultyLevel.b1).map((w) => w.word);
    expect(b1.map((p) => p.word), containsAll(own));
    expect(b1, hasLength(own.length + matchReviewWords));
    expect(deck('A2'), hasLength(words.of(DifficultyLevel.a2).length));
    expect(
      deck('C1').map((p) => p.word),
      isNot(contains(words.of(DifficultyLevel.a2).first.word)),
    );
  });

  test('kendi kartları sınırlıdır; cümle ve soru kartları girmez', () {
    final mine = [
      for (var i = 0; i < 30; i++)
        MatchPair(id: i + 1, word: 'kart$i', meaning: 'anlam$i'),
      const MatchPair(
        id: 90,
        word: 'had',
        meaning: 'If I ___ a better grip, I would apply.',
      ),
      const MatchPair(
        id: 91,
        word: 'If he spoke English well, he would have gotten the job.',
        meaning: 'Cümle',
      ),
    ];
    final result = deck('B2', mine);
    expect(result.where((p) => p.id > 0), hasLength(matchOwnWords));
    expect(result.map((p) => p.id), isNot(contains(90)));
    expect(result.map((p) => p.id), isNot(contains(91)));
    expect(result.map((p) => p.id).toSet(), hasLength(result.length));
    expect(MatchBoard(result).words, hasLength(matchBoardRows));
  });

  test('listede olan kelimenin kartı varsa kart öne geçer', () {
    final w = words.of(DifficultyLevel.b1).first;
    final result = deck('B1', [
      MatchPair(id: 7, word: w.word, meaning: w.meaning),
    ]);
    expect(result.where((p) => p.word == w.word).single.id, 7);
  });
}
