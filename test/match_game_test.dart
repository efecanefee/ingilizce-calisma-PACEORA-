import 'dart:math';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/match_game.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/data/rewards.dart';
import 'package:shared_preferences/shared_preferences.dart';

List<MatchPair> _deck(int n) => [
  for (var i = 0; i < n; i++)
    MatchPair(id: i, word: 'word$i', meaning: 'anlam$i'),
];

/// Tahtanın değişmezleri: her çift tam bir kez, iki sütunda da aynı çiftler.
void _expectValid(MatchBoard board) {
  final wordIds = board.words.map((p) => p.id).toList();
  expect(wordIds.toSet(), hasLength(matchBoardRows), reason: '$wordIds');
  expect(board.meanings.map((p) => p.id).toSet(), wordIds.toSet());
}

/// [board] üzerinde [row]'dan başlayarak ilk dolu kelimeyi doğru karşılığıyla
/// eşleştirir.
MatchOutcome _matchRow(MatchBoard board, int row) {
  while (board.isVacant(MatchSide.word, row) ||
      board.cleared.contains((MatchSide.word, row))) {
    row = (row + 1) % matchBoardRows;
  }
  final id = board.words[row].id;
  final target = board.meanings.indexWhere((p) => p.id == id);
  board.tap(MatchSide.word, row);
  return board.tap(MatchSide.meaning, target);
}

void main() {
  group('MatchBoard', () {
    test('tahta beş farklı çiftle kurulur', () {
      _expectValid(MatchBoard(_deck(12), random: Random(1)));
    });

    test('doğru eşleşme puan verir, yenilenince yeni çift gelir', () {
      final board = MatchBoard(_deck(12), random: Random(2));
      final old = board.words[0].id;

      expect(_matchRow(board, 0), MatchOutcome.correct);
      expect(board.score, matchBasePoints);
      expect(board.matches, 1);
      expect(board.cleared, hasLength(2));
      // Yenilenmeyi bekleyen kutucuğa dokunmak bir şey yapmaz.
      expect(board.tap(MatchSide.word, 0), MatchOutcome.ignored);

      // Tek çift boşalınca yer boş kalır: yenisi gelse yeri belli olurdu.
      board.refill();
      expect(board.cleared, isEmpty);
      expect(board.vacant, hasLength(1));
      expect(board.isVacant(MatchSide.word, 0), isTrue);
      expect(board.tap(MatchSide.word, 0), MatchOutcome.ignored);
      expect(board.words[0].id, old);

      for (var i = 1; i < matchRefillAt; i++) {
        _matchRow(board, 0);
        board.refill();
      }
      expect(board.vacant, isEmpty);
      expect(board.words[0].id, isNot(old));
      _expectValid(board);
    });

    test('yeni çiftin iki yarısı aynı anda boşalan yerlere gelmez', () {
      for (var seed = 0; seed < 40; seed++) {
        final board = MatchBoard(_deck(40), random: Random(seed));
        final slots = <(int, int)>[];
        for (var round = 0; round < 6; round++) {
          slots.clear();
          for (var i = 0; i < matchRefillAt; i++) {
            final row = List.generate(
              matchBoardRows,
              (r) => r,
            ).firstWhere((r) => !board.isVacant(MatchSide.word, r));
            final id = board.words[row].id;
            slots.add((row, board.meanings.indexWhere((p) => p.id == id)));
            _matchRow(board, row);
            board.refill();
          }
          for (final (w, m) in slots) {
            expect(board.words[w].id, isNot(board.meanings[m].id));
          }
          _expectValid(board);
        }
      }
    });

    test('kombo çarpanı: 4. eşleşmeden x2, 7.\'den x3', () {
      final board = MatchBoard(_deck(20), random: Random(3));
      final scores = <int>[];
      for (var i = 0; i < 8; i++) {
        _matchRow(board, 0);
        board.refill();
        scores.add(board.score);
      }
      expect(scores, [10, 20, 30, 50, 70, 90, 120, 150]);
      expect(board.bestCombo, 8);
    });

    test('yanlış eşleşme komboyu sıfırlar, kartları not eder', () {
      final board = MatchBoard(_deck(12), random: Random(4));
      for (var i = 0; i < 4; i++) {
        _matchRow(board, 0);
        board.refill();
      }
      expect(board.multiplier, 2);

      bool live(MatchSide side, int row) => !board.isVacant(side, row);
      final rows = List.generate(matchBoardRows, (r) => r);
      final wordRow = rows.firstWhere((r) => live(MatchSide.word, r));
      final a = board.words[wordRow];
      final wrongRow = rows.firstWhere(
        (r) => live(MatchSide.meaning, r) && board.meanings[r].id != a.id,
      );
      final b = board.meanings[wrongRow];
      board.tap(MatchSide.word, wordRow);
      expect(board.tap(MatchSide.meaning, wrongRow), MatchOutcome.wrong);

      expect(board.combo, 0);
      expect(board.multiplier, 1);
      expect(board.mistakes, 1);
      expect(board.confusedIds, {a.id, b.id});
      expect(board.selected, isNull);
    });

    test('aynı kutucuk seçimi kaldırır, aynı sütun seçimi değiştirir', () {
      final board = MatchBoard(_deck(12), random: Random(5));
      expect(board.tap(MatchSide.word, 1), MatchOutcome.selected);
      expect(board.tap(MatchSide.word, 1), MatchOutcome.ignored);
      expect(board.selected, isNull);

      board.tap(MatchSide.word, 1);
      expect(board.tap(MatchSide.word, 3), MatchOutcome.selected);
      expect(board.selected, (MatchSide.word, 3));
    });

    test('aynı anlamlı iki kart tahtada aynı anda görünmez', () {
      final deck = [
        ..._deck(10),
        const MatchPair(id: 100, word: 'bank', meaning: 'banka'),
        const MatchPair(id: 101, word: 'Bank', meaning: 'kıyı'),
        const MatchPair(id: 102, word: 'bench', meaning: 'banka'),
      ];
      final board = MatchBoard(deck, random: Random(6));
      for (var i = 0; i < 60; i++) {
        final words = board.words.map((p) => p.word.toLowerCase());
        final meanings = board.meanings.map((p) => p.meaning);
        expect(words.toSet(), hasLength(matchBoardRows));
        expect(meanings.toSet(), hasLength(matchBoardRows));
        _matchRow(board, i % matchBoardRows);
        board.refill();
      }
    });

    test('tahtayı ancak dolduran destede (5 kart) bozulmaz', () {
      final board = MatchBoard(_deck(matchBoardRows), random: Random(7));
      for (var i = 0; i < 30; i++) {
        _matchRow(board, i % matchBoardRows);
        if (i.isEven) _matchRow(board, (i + 2) % matchBoardRows);
        board.refill();
        if (board.vacant.isEmpty) _expectValid(board);
      }
    });

    test('en küçük oynanabilir destede tahta bozulmadan sürer', () {
      final board = MatchBoard(_deck(matchMinPairs), random: Random(9));
      for (var i = 0; i < 30; i++) {
        _matchRow(board, i % matchBoardRows);
        board.refill();
        if (board.vacant.isEmpty) _expectValid(board);
      }
    });
  });

  test('özet: isabet, XP sınırı ve rekor', () {
    const s = MatchSummary(score: 400, matches: 42, mistakes: 6, bestCombo: 9);
    expect(s.accuracy, 88);
    expect(s.xp, matchMaxXp);
    expect(matchXp(7), 7);

    final board = MatchBoard(_deck(12), random: Random(8));
    _matchRow(board, 0);
    expect(board.summary(bestScoreBefore: 5).isNewBest, isTrue);
    expect(board.summary(bestScoreBefore: 10).isNewBest, isFalse);
  });

  test('kayıtlar birikir, rekor korunur; XP ve rozete yansır', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await MatchRecords.save(
      prefs,
      const MatchSummary(score: 120, matches: 12, mistakes: 1, bestCombo: 6),
    );
    final records = await MatchRecords.save(
      prefs,
      const MatchSummary(score: 80, matches: 21, mistakes: 0, bestCombo: 21),
    );
    expect(records.games, 2);
    expect(records.bestScore, 120);
    expect(records.bestMatches, 21);
    expect(records.xp, 12 + 21);
    expect(MatchRecords.read(prefs).xp, 33);

    final stats = GameStats(matchXp: records.xp, bestMatches: 21);
    expect(totalXp(stats), 33);
    expect(GameState(stats).earnedBadgeIds, contains('match_20'));
  });

  group('Repository', () {
    late AppDatabase db;
    late Repository repository;

    setUp(() {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = Repository(db);
    });
    tearDown(() => db.close());

    test(
      'karıştırılan kartlar bugüne çekilir, geçmiştekiler dokunulmaz',
      () async {
        final today = DateTime(2026, 11, 17);
        await repository.addFlashcards(
          [
            (word: 'a', meaning: '1', example: ''),
            (word: 'b', meaning: '2', example: ''),
            (word: 'c', meaning: '3', example: ''),
          ],
          source: 'new_word',
          now: today.subtract(const Duration(days: 3)),
        );
        final cards = await db.select(db.flashcards).get();
        final byWord = {for (final c in cards) c.word: c};
        // a ileride, b geçmişte kalıyor.
        await (db.update(db.flashcards)
              ..where((t) => t.id.equals(byWord['a']!.id)))
            .write(FlashcardsCompanion(dueDate: Value(DateTime(2026, 12, 1))));

        await repository.pullFlashcardsToToday([
          byWord['a']!.id,
          byWord['b']!.id,
        ], now: today);

        final after = {
          for (final c in await db.select(db.flashcards).get())
            c.word: c.dueDate,
        };
        expect(after['a'], today);
        expect(after['b'], DateTime(2026, 11, 14));
        expect(after['c'], DateTime(2026, 11, 14));
      },
    );

    test('oyun kartları: oturmamış kartlar öne alınır', () async {
      await repository.addFlashcards([
        for (var i = 0; i < 6; i++) (word: 'w$i', meaning: 'm$i', example: ''),
      ], source: 'new_word');
      await (db.update(db.flashcards)..where((t) => t.word.isIn(['w0', 'w1'])))
          .write(const FlashcardsCompanion(intervalDays: Value(30)));

      final cards = await repository.matchCards(limit: 4, random: Random(1));
      expect(cards, hasLength(4));
      expect(cards.map((c) => c.word), isNot(contains('w0')));
      expect(cards.map((c) => c.word), isNot(contains('w1')));
    });
  });
}
