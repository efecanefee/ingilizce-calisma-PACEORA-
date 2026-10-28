import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/srs.dart';

void main() {
  final today = DateTime(2026, 10, 28, 15, 30);

  SrsSchedule review(
    ReviewGrade grade, {
    double ease = 2.5,
    int interval = 0,
    int reps = 0,
  }) => nextSchedule(
    ease: ease,
    intervalDays: interval,
    reps: reps,
    grade: grade,
    today: today,
  );

  group('SM-2', () {
    test('ilk başarılı tekrar 1 gün sonraya planlanır', () {
      final next = review(ReviewGrade.good);
      expect(next.reps, 1);
      expect(next.intervalDays, 1);
      expect(next.dueDate, DateTime(2026, 10, 29));
    });

    test('ikinci başarılı tekrar 6 gün sonra', () {
      final next = review(ReviewGrade.good, interval: 1, reps: 1);
      expect(next.reps, 2);
      expect(next.intervalDays, 6);
      expect(next.dueDate, DateTime(2026, 11, 3));
    });

    test('sonraki tekrarlar aralık × kolaylık katsayısı', () {
      final next = review(ReviewGrade.good, interval: 6, reps: 2);
      // "İyi" (q=4) katsayıyı değiştirmez: 6 × 2.5 = 15
      expect(next.ease, closeTo(2.5, 1e-9));
      expect(next.intervalDays, 15);
    });

    test('"Tekrar" kartı baştan başlatır ve katsayıyı düşürür', () {
      final next = review(ReviewGrade.again, interval: 15, reps: 3);
      expect(next.reps, 0);
      expect(next.intervalDays, 1);
      expect(next.ease, lessThan(2.5));
    });

    test('"Kolay" katsayıyı artırır, "Zor" düşürür', () {
      expect(review(ReviewGrade.easy).ease, closeTo(2.6, 1e-9));
      expect(review(ReviewGrade.hard).ease, closeTo(2.36, 1e-9));
    });

    test('katsayı 1.3\'ün altına inmez', () {
      var ease = 1.4;
      for (var i = 0; i < 5; i++) {
        ease = review(ReviewGrade.again, ease: ease).ease;
      }
      expect(ease, minEase);
    });

    test('vade günü saat bilgisinden bağımsızdır', () {
      final next = review(ReviewGrade.good);
      expect(next.dueDate.hour, 0);
      expect(next.dueDate.minute, 0);
    });
  });
}
