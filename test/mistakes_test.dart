import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/lesson_models.dart';
import 'package:paceora/data/repository.dart';

AnswerOutcome _outcome(
  String item, {
  required bool correct,
  String type = 'vocabulary',
}) =>
    AnswerOutcome(
      item: item,
      context: '$item geçen cümle',
      type: type,
      correct: correct,
    );

void main() {
  late AppDatabase db;
  late Repository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = Repository(db);
  });

  tearDown(() => db.close());

  group('recordOutcomes', () {
    test('yanlış cevap hata defterine yazılır', () async {
      await repository.recordOutcomes([_outcome('drink', correct: false)]);

      final rows = await db.select(db.mistakes).get();
      expect(rows, hasLength(1));
      expect(rows.single.item, 'drink');
      expect(rows.single.context, 'drink geçen cümle');
      expect(rows.single.timesWrong, 1);
      expect(rows.single.timesCorrect, 0);
      expect(rows.single.resolved, isFalse);
    });

    test('hiç yanlış yapılmamış ifade doğru bilinince deftere girmez', () async {
      await repository.recordOutcomes([_outcome('drink', correct: true)]);

      expect(await db.select(db.mistakes).get(), isEmpty);
    });

    test('aynı ifade tekrar yanlışsa yeni kayıt açılmaz', () async {
      await repository.recordOutcomes([_outcome('drink', correct: false)]);
      await repository.recordOutcomes([_outcome('drink', correct: false)]);

      final rows = await db.select(db.mistakes).get();
      expect(rows, hasLength(1));
      expect(rows.single.timesWrong, 2);
    });

    test('aynı ifade farklı türde ayrı kayıt olur', () async {
      await repository.recordOutcomes([
        _outcome('drink', correct: false),
        _outcome('drink', correct: false, type: 'grammar'),
      ]);

      expect(await db.select(db.mistakes).get(), hasLength(2));
    });

    test('üç kez üst üste doğru yapılınca çözülmüş sayılır', () async {
      await repository.recordOutcomes([_outcome('drink', correct: false)]);

      for (var i = 0; i < 2; i++) {
        await repository.recordOutcomes([_outcome('drink', correct: true)]);
        final row = await db.select(db.mistakes).getSingle();
        expect(row.resolved, isFalse, reason: '${i + 1} doğru henüz yetmez');
      }

      await repository.recordOutcomes([_outcome('drink', correct: true)]);
      final row = await db.select(db.mistakes).getSingle();
      expect(row.timesCorrect, 3);
      expect(row.resolved, isTrue);
    });

    test('araya yanlış girerse doğru serisi sıfırlanır', () async {
      await repository.recordOutcomes([_outcome('drink', correct: false)]);
      await repository.recordOutcomes([_outcome('drink', correct: true)]);
      await repository.recordOutcomes([_outcome('drink', correct: true)]);
      await repository.recordOutcomes([_outcome('drink', correct: false)]);

      final row = await db.select(db.mistakes).getSingle();
      expect(row.timesCorrect, 0);
      expect(row.timesWrong, 2);
      expect(row.resolved, isFalse);
    });

    test('çözülmüş kayıt yeniden yanlış yapılınca tekrar açılır', () async {
      await repository.recordOutcomes([_outcome('drink', correct: false)]);
      for (var i = 0; i < 3; i++) {
        await repository.recordOutcomes([_outcome('drink', correct: true)]);
      }
      expect((await db.select(db.mistakes).getSingle()).resolved, isTrue);

      await repository.recordOutcomes([_outcome('drink', correct: false)]);
      expect((await db.select(db.mistakes).getSingle()).resolved, isFalse);
    });

    test('boş liste veritabanına dokunmaz', () async {
      await repository.recordOutcomes([]);
      expect(await db.select(db.mistakes).get(), isEmpty);
    });
  });

  group('unresolvedMistakeItems', () {
    test('çözülmüşleri eler, en çok yanlış yapılanı öne alır', () async {
      await repository.recordOutcomes([
        _outcome('rarely', correct: false),
        _outcome('seldom', correct: false),
      ]);
      // "seldom" bir kez daha yanlış → listede önce gelmeli.
      await repository.recordOutcomes([_outcome('seldom', correct: false)]);

      await db.into(db.mistakes).insert(
            MistakesCompanion.insert(
              item: 'already',
              context: 'çözülmüş kayıt',
              type: 'grammar',
              resolved: const Value(true),
            ),
          );

      final items = await repository.unresolvedMistakeItems();

      expect(items, ['seldom', 'rarely']);
      expect(items, isNot(contains('already')));
    });

    test('limit uygulanır', () async {
      for (var i = 0; i < 5; i++) {
        await repository.recordOutcomes([_outcome('item$i', correct: false)]);
      }

      expect(await repository.unresolvedMistakeItems(limit: 3), hasLength(3));
    });
  });
}
