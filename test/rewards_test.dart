import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/rewards.dart';

void main() {
  group('oyuncu seviyesi', () {
    test('seviye eşikleri 0, 100, 300, 600, 1000', () {
      expect(
        [for (var l = 1; l <= 5; l++) xpForLevel(l)],
        [0, 100, 300, 600, 1000],
      );
    });

    test('XP seviyeye ve ilerlemeye çevrilir', () {
      final start = PlayerLevel.fromXp(0);
      expect(start.level, 1);
      expect(start.title, 'Çaylak');
      expect(start.xpToNext, 100);

      final mid = PlayerLevel.fromXp(200);
      expect(mid.level, 2);
      expect(mid.progress, closeTo(0.5, 1e-9));
      expect(mid.xpToNext, 100);

      expect(PlayerLevel.fromXp(300).level, 3);
      // Unvan listesinin sonundan sonra son unvan korunur.
      expect(PlayerLevel.fromXp(1000000).title, 'Efsane');
    });

    test('toplam XP tüm etkinliklerden gelir', () {
      final stats = GameStats(
        lessons: 2,
        lessonXpSum: lessonXp(100) + lessonXp(50),
        stories: 1,
        storyXpSum: storyXp(80),
        cardsReviewed: 10,
        studiedDays: 3,
        levelUps: 1,
      );
      // (40 + 30) + 23 + 20 + 30 + 100
      expect(totalXp(stats), 243);
      expect(lessonXp(100), 40);
      expect(storyXp(50), 20);
    });

    test('ders XP\'si ders başına yuvarlanır (sonuç ekranıyla aynı)', () {
      // 33.3 iki kez: her biri 20 + 7 = 27; toplam skordan yuvarlasaydık 53.
      expect(lessonXp(33.3) * 2, 54);
    });
  });

  group('rozetler', () {
    test('koşullar ve ilerleme', () {
      const stats = GameStats(lessons: 1, perfectLessons: 1, bestStreak: 4);
      final earned = GameState(stats).earnedBadgeIds;
      expect(earned, containsAll(['first_lesson', 'perfect', 'streak_3']));
      expect(earned, isNot(contains('streak_7')));

      final week = badges.firstWhere((b) => b.id == 'streak_7');
      expect(week.progressOf(stats), 4);
      expect(week.progressOf(const GameStats(bestStreak: 99)), 7);
    });

    test('rozet kimlikleri benzersiz', () {
      final ids = badges.map((b) => b.id).toList();
      expect(ids.toSet(), hasLength(ids.length));
    });
  });

  group('günlük hedef', () {
    test('sıradaki adım ilk bitmemiş adımdır', () {
      const goal = DailyGoal(
        tasks: [DailyTask.lesson, DailyTask.story, DailyTask.cards],
        done: {DailyTask.lesson},
      );
      expect(goal.next, DailyTask.story);
      expect(goal.doneCount, 1);
      expect(goal.progress, closeTo(1 / 3, 1e-9));
      expect(goal.complete, isFalse);
    });

    test('hepsi bitince tamamlanır', () {
      const goal = DailyGoal(
        tasks: [DailyTask.lesson, DailyTask.story],
        done: {DailyTask.lesson, DailyTask.story},
      );
      expect(goal.complete, isTrue);
      expect(goal.next, isNull);
    });
  });
}
