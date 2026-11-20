import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/constants.dart';
import 'package:paceora/data/placement.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/features/placement/placement_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('her kademe iki soruyla temsil edilir ve cevaplar geçerli', () {
    expect(placementQuestions, hasLength(12));
    for (final level in DifficultyLevel.values) {
      expect(placementQuestions.where((q) => q.level == level), hasLength(2));
    }
    for (final q in placementQuestions) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.options.toSet(), hasLength(q.options.length));
    }
  });

  test('doğru sayısı seviyeye çevrilir', () {
    expect(placementLevel(0), DifficultyLevel.b1Minus);
    expect(placementLevel(3), DifficultyLevel.b1Minus);
    expect(placementLevel(5), DifficultyLevel.b1);
    expect(placementLevel(7), DifficultyLevel.b1Plus);
    expect(placementLevel(9), DifficultyLevel.b2Minus);
    expect(placementLevel(10), DifficultyLevel.b2);
    expect(placementLevel(12), DifficultyLevel.b2Plus);
  });

  testWidgets('test çözülünce seviye gösterilir ve kaydedilir', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: PlacementTestScreen()),
      ),
    );

    // İlk 7 soruyu doğru, kalanını yanlış cevapla → 7 doğru = B1+.
    for (var i = 0; i < placementQuestions.length; i++) {
      final q = placementQuestions[i];
      final pick = i < 7 ? q.answer : (q.answer + 1) % q.options.length;
      await tester.tap(find.text(q.options[pick]));
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Seviyen: ${DifficultyLevel.b1Plus.label}'),
        findsOneWidget);
    expect(PlacementRecord.read(prefs), DifficultyLevel.b1Plus);
  });
}
