import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/turkish_text.dart';

void main() {
  test('Türkçe büyük harf', () {
    expect(trUpper('i'), 'İ');
    expect(trUpper('ı'), 'I');
    expect(trUpper('ğüşöç'), 'ĞÜŞÖÇ');
  });
}
