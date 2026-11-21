import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/pace_messages.dart';
import 'package:paceora/data/streak_freeze.dart';

void main() {
  final morning = DateTime(2026, 11, 20, 9);
  final evening = DateTime(2026, 11, 20, 21);

  test('bugün tamamlandıysa tebrik eder', () {
    final m = paceMessage(status: StreakStatus.done, streak: 5, now: morning);
    expect(m, anyOf(contains('tamamladın'), contains('5 gün'), contains('Bugünlük')));
  });

  test('korunan seride hakları hatırlatır', () {
    final m = paceMessage(status: StreakStatus.protected, streak: 4, now: morning);
    expect(m, contains('hakların'));
  });

  test('hedefe bir gün kala haber verir', () {
    final m = paceMessage(status: StreakStatus.pending, streak: 6, now: evening);
    expect(m, contains('7 günlük'));
  });

  test('saate göre selamlar ve akşam seriyi hatırlatır', () {
    final day = paceMessage(status: StreakStatus.pending, streak: 0, now: morning);
    expect(day, anyOf(contains('Günaydın'), contains('Güne')));
    final night = paceMessage(status: StreakStatus.pending, streak: 4, now: evening);
    expect(night, contains('serin 4 gün'));
  });

  test('aynı gün aynı mesaj, ertesi gün değişebilir', () {
    final a = paceMessage(status: StreakStatus.broken, streak: 0, now: morning);
    final b = paceMessage(
      status: StreakStatus.broken,
      streak: 0,
      now: morning.add(const Duration(hours: 3)),
    );
    final c = paceMessage(
      status: StreakStatus.broken,
      streak: 0,
      now: morning.add(const Duration(days: 1)),
    );
    expect(a, b);
    expect(a, isNot(c));
  });
}
