import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/streak_freeze.dart';

void main() {
  test('seri hedefi bir sonraki eşiği gösterir', () {
    expect(streakMilestone(1), (from: 0, to: 3));
    expect(streakMilestone(3), (from: 3, to: 7));
    expect(streakMilestone(5), (from: 3, to: 7));
    expect(streakMilestone(29), (from: 14, to: 30));
    expect(streakMilestone(364), (from: 200, to: 365));
  });

  test('son hedeften sonra her 100 günde yeni hedef', () {
    expect(streakMilestone(365), (from: 365, to: 400));
    expect(streakMilestone(420), (from: 400, to: 500));
  });

  test('ulaşılan hedef', () {
    expect(reachedStreakMilestone(0), 0);
    expect(reachedStreakMilestone(2), 0);
    expect(reachedStreakMilestone(3), 3);
    expect(reachedStreakMilestone(13), 7);
    expect(reachedStreakMilestone(365), 365);
    expect(reachedStreakMilestone(401), 400);
  });
}
