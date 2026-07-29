import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/constants.dart';

void main() {
  test('DifficultyLevel.step sınırlar içinde kalır', () {
    expect(DifficultyLevel.b1.step(1), DifficultyLevel.b1Plus);
    expect(DifficultyLevel.b1Minus.step(-1), DifficultyLevel.b1Minus);
    expect(DifficultyLevel.b2Plus.step(1), DifficultyLevel.b2Plus);
  });
}
