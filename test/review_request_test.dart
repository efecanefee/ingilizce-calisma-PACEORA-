import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/review_request.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('puanlama 7 gün ve sonrasında, yalnızca bir kez istenir', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(shouldRequestReview(prefs, 3), isFalse);
    expect(shouldRequestReview(prefs, 7), isTrue);
    expect(shouldRequestReview(prefs, 30), isTrue);
    await prefs.setBool(reviewRequestedKey, true);
    expect(shouldRequestReview(prefs, 30), isFalse);
  });
}
