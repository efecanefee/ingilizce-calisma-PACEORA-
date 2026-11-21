import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/constants.dart';
import 'package:paceora/data/level_check.dart';

void main() {
  test('her seviyenin önizlemesi ve 4 geçerli sorusu var', () {
    for (final level in DifficultyLevel.values) {
      final p = LevelPreview.of(level);
      expect(p.focus, isNotEmpty);
      expect(p.questions, hasLength(4));
      for (final q in p.questions) {
        expect(q.level, level);
        expect(q.answer, inInclusiveRange(0, q.options.length - 1));
        expect(q.options.toSet(), hasLength(q.options.length));
      }
    }
  });

  test('kontrol sonucu alt/üst seviye önerir', () {
    expect(levelCheckVerdict(DifficultyLevel.b1, 4), LevelCheckVerdict.higher);
    expect(levelCheckVerdict(DifficultyLevel.b1, 3), LevelCheckVerdict.fits);
    expect(levelCheckVerdict(DifficultyLevel.b1, 2), LevelCheckVerdict.fits);
    expect(levelCheckVerdict(DifficultyLevel.b1, 1), LevelCheckVerdict.lower);
    // Uçlarda öneri yok.
    expect(
      levelCheckVerdict(DifficultyLevel.c1, 4),
      LevelCheckVerdict.fits,
    );
    expect(
      levelCheckVerdict(DifficultyLevel.a2, 0),
      LevelCheckVerdict.fits,
    );
  });
}
