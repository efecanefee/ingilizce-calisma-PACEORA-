import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/lesson_models.dart';
import 'package:paceora/data/repository.dart';

void main() {
  late AppDatabase db;
  late Repository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = Repository(db);
  });
  tearDown(() => db.close());

  AnswerOutcome outcome(String item, {required bool correct}) => AnswerOutcome(
    item: item,
    context: 'bağlam',
    type: 'grammar',
    correct: correct,
  );

  test('yanlış yapılan ifade 1, 3 ve 7 gün arayla geri gelir', () async {
    final day0 = DateTime(2026, 11, 2, 9);
    await repository.recordOutcomes([
      outcome('make a decision', correct: false),
    ], now: day0);

    // Aynı gün tekrar sorulmaz, ertesi gün sorulur.
    expect(await repository.dueMistakeItems(now: day0), isEmpty);
    final day1 = DateTime(2026, 11, 3, 9);
    expect(await repository.dueMistakeItems(now: day1), ['make a decision']);

    // Doğru bildi: aralık 3 güne çıkar.
    await repository.recordOutcomes([
      outcome('make a decision', correct: true),
    ], now: day1);
    expect(
      await repository.dueMistakeItems(now: DateTime(2026, 11, 5)),
      isEmpty,
    );
    final day4 = DateTime(2026, 11, 6, 9);
    expect(await repository.dueMistakeItems(now: day4), ['make a decision']);

    // Yine doğru: aralık 7 gün.
    await repository.recordOutcomes([
      outcome('make a decision', correct: true),
    ], now: day4);
    expect(
      await repository.dueMistakeItems(now: DateTime(2026, 11, 12)),
      isEmpty,
    );
    expect(await repository.dueMistakeItems(now: DateTime(2026, 11, 13)), [
      'make a decision',
    ]);

    // Yanlış: başa döner, ertesi gün yine gelir.
    await repository.recordOutcomes([
      outcome('make a decision', correct: false),
    ], now: DateTime(2026, 11, 13));
    expect(await repository.dueMistakeItems(now: DateTime(2026, 11, 14)), [
      'make a decision',
    ]);
  });

  test('pekişen (3 kez doğru) ifade artık gelmez', () async {
    final start = DateTime(2026, 11, 2);
    await repository.recordOutcomes([outcome('x', correct: false)], now: start);
    for (var i = 1; i <= 3; i++) {
      await repository.recordOutcomes([
        outcome('x', correct: true),
      ], now: start.add(Duration(days: i * 10)));
    }
    expect(
      await repository.dueMistakeItems(now: DateTime(2027, 1, 1)),
      isEmpty,
    );
  });
}
