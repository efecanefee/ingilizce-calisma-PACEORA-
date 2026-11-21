import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/constants.dart';

void main() {
  test('DifficultyLevel.step sınırlar içinde kalır', () {
    expect(DifficultyLevel.b1.step(1), DifficultyLevel.b1Plus);
    expect(DifficultyLevel.a2.step(-1), DifficultyLevel.a2);
    expect(DifficultyLevel.c1.step(1), DifficultyLevel.c1);
    expect(DifficultyLevel.b1Minus.step(-1), DifficultyLevel.a2);
  });
}
