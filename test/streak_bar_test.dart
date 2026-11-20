import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/features/home/home_screen.dart';

void main() {
  test('seri hedefi bir sonraki eşiği gösterir', () {
    expect(streakMilestone(1), (from: 0, to: 3));
    expect(streakMilestone(3), (from: 3, to: 7));
    expect(streakMilestone(5), (from: 3, to: 7));
    expect(streakMilestone(29), (from: 14, to: 30));
    expect(streakMilestone(364), (from: 200, to: 365));
  });

  test('son hedeften sonra her 100 günde yeni hedef', () {
    expect(streakMilestone(365), (from: 300, to: 400));
    expect(streakMilestone(420), (from: 400, to: 500));
  });
}
