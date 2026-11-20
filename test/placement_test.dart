import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/constants.dart';
import 'package:paceora/data/level_check.dart';
import 'package:paceora/data/placement.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/features/placement/placement_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('her kademe iki soruyla temsil edilir ve cevaplar geçerli', () {
    expect(placementQuestions, hasLength(placementQuestionCount));
    expect(placementQuestionCount, 16);
    for (final level in DifficultyLevel.values) {
      expect(placementQuestions.where((q) => q.level == level), hasLength(2));
    }
    for (final q in placementQuestions) {
      expect(q.answer, inInclusiveRange(0, q.options.length - 1));
      expect(q.options.toSet(), hasLength(q.options.length));
    }
  });

  test('doğru sayısı seviyeye çevrilir', () {
    expect(placementLevel(0), DifficultyLevel.a2);
    expect(placementLevel(3), DifficultyLevel.a2);
    expect(placementLevel(5), DifficultyLevel.b1Minus);
    expect(placementLevel(7), DifficultyLevel.b1);
    expect(placementLevel(9), DifficultyLevel.b1Plus);
    expect(placementLevel(11), DifficultyLevel.b2Minus);
    expect(placementLevel(13), DifficultyLevel.b2);
    expect(placementLevel(14), DifficultyLevel.b2Plus);
    expect(placementLevel(16), DifficultyLevel.c1);
  });

  test('her test kademe başına 2 soru çeker, seçenekler karışık', () {
    final a = drawPlacementQuestions(Random(1));
    final b = drawPlacementQuestions(Random(2));
    expect(a, hasLength(16));
    for (final level in DifficultyLevel.values) {
      expect(a.where((q) => q.level == level), hasLength(2));
      expect(placementPool(level), hasLength(6));
    }
    // Farklı tohumlarda farklı sorular ya da sıralar gelir.
    expect(
      a.map((q) => '${q.prompt}${q.options}'),
      isNot(equals(b.map((q) => '${q.prompt}${q.options}'))),
    );
    // Karıştırma doğru cevabı korur.
    for (final q in a) {
      final original = [
        ...placementQuestions,
        for (final l in DifficultyLevel.values) ...LevelPreview.of(l).questions,
      ].firstWhere((o) => o.prompt == q.prompt);
      expect(q.correctOption, original.correctOption);
    }
  });

  Future<SharedPreferences> pumpTest(WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: MaterialApp(home: PlacementTestScreen(random: Random(7))),
      ),
    );
    return prefs;
  }

  testWidgets('test çözülünce seviye ve yanlışlar gösterilir', (
    tester,
  ) async {
    final prefs = await pumpTest(tester);
    final questions = drawPlacementQuestions(Random(7));

    // İlk 7 soruyu doğru, kalanını yanlış cevapla → 7 doğru = B1.
    for (var i = 0; i < questions.length; i++) {
      final q = questions[i];
      final pick = i < 7 ? q.answer : (q.answer + 1) % q.options.length;
      await tester.tap(find.text(q.options[pick]).last);
      await tester.pump(const Duration(milliseconds: 400));
    }
    await tester.pump(const Duration(milliseconds: 400));

    expect(
      find.text('Seviyen: ${DifficultyLevel.b1.label}'),
      findsOneWidget,
    );
    expect(PlacementRecord.read(prefs), DifficultyLevel.b1);

    await tester.ensureVisible(find.text('Yanlışlarını gör (9)'));
    await tester.tap(find.text('Yanlışlarını gör (9)'));
    // Sonuç ekranındaki Pace sürekli hareket eder; sabit süre ilerlet.
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text(questions.last.prompt), findsOneWidget);
  });

  testWidgets('test yarıdayken geri çıkmak onay ister', (tester) async {
    await pumpTest(tester);
    final q = drawPlacementQuestions(Random(7)).first;
    await tester.tap(find.text(q.options[0]).last);
    await tester.pump(const Duration(milliseconds: 400));

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Testten çıkılsın mı?'), findsOneWidget);
    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    expect(find.byType(PlacementTestScreen), findsOneWidget);
  });
}
