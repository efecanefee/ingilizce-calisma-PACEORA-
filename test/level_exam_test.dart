import 'dart:io';
import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/answer_option.dart';
import 'package:paceora/app/constants.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/level_check.dart';
import 'package:paceora/data/level_exam.dart';
import 'package:paceora/data/placement.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/data/rewards.dart';
import 'package:paceora/features/level_exam/level_exam_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final bank = PlacementBank.parse([
    for (final path in PlacementBank.assets) File(path).readAsStringSync(),
  ]);

  test('sınav 10 sorudur, dinleme yok, çoğu hedef kademeden', () {
    for (final level in DifficultyLevel.values) {
      final target = levelExamTarget(level);
      if (target == null) {
        expect(level, DifficultyLevel.values.last);
        continue;
      }
      for (var seed = 0; seed < 20; seed++) {
        final qs = drawLevelExam(bank, target, Random(seed));
        expect(qs, hasLength(levelExamQuestionCount), reason: target.code);
        expect(qs.toSet(), hasLength(qs.length));
        expect(qs.where((q) => q.skill == PlacementSkill.listening), isEmpty);
        expect(
          qs.where((q) => q.level.index < target.index),
          isEmpty,
          reason: 'hedefin altından soru gelmemeli (${target.code})',
        );
      }
    }
    expect(levelExamPassMark(10), 7);
  });

  test('öneri: 4. haftadan itibaren ve 3 haftada bir', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final now = DateTime(2026, 12, 1);
    bool offer(int week, [DifficultyLevel level = DifficultyLevel.b1]) =>
        shouldOfferLevelExam(
          prefs: prefs,
          level: level,
          weekNumber: week,
          now: now,
        );
    expect(offer(3), isFalse);
    expect(offer(4), isTrue);
    expect(offer(9, DifficultyLevel.values.last), isFalse);
    await prefs.setString(
      levelExamAtKey,
      DateTime(2026, 11, 20).toIso8601String(),
    );
    expect(offer(5), isFalse);
    await prefs.setString(
      levelExamAtKey,
      DateTime(2026, 11, 1).toIso8601String(),
    );
    expect(offer(5), isTrue);
  });

  testWidgets('geçen kullanıcı bir üst seviyeye geçer', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = Repository(db);
    await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 15);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          placementBankProvider.overrideWith((_) async => bank),
        ],
        child: const MaterialApp(home: LevelExamScreen()),
      ),
    );
    for (var i = 0; i < 10; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.textContaining('→'), findsOneWidget);
    await tester.tap(find.text('Sınava başla'));
    await tester.pump();

    // Ekrandaki soru metninden bankadaki soruyu bul, doğru seçeneğe dokun.
    for (var i = 0; i < levelExamQuestionCount; i++) {
      final shown = {
        for (final e in find.byType(Text).evaluate()) (e.widget as Text).data,
      };
      final q =
          [
            ...bank.questions,
            for (final l in DifficultyLevel.values)
              ...LevelPreview.of(l).questions,
          ].firstWhere(
            (q) =>
                shown.contains(q.prompt) &&
                (q.passage == null || shown.contains(q.passage)),
          );
      final correct = find
          .widgetWithText(AnswerOption, q.options[q.answer])
          .first;
      await tester.ensureVisible(correct);
      await tester.pump();
      await tester.tap(correct);
      await tester.pump(const Duration(milliseconds: 1000));
    }
    await tester.pump();
    expect(find.text('10 sorudan 10 doğru'), findsOneWidget);
    expect(prefs.getString(levelExamAtKey), isNotNull);

    await tester.tap(find.textContaining('seviyesine geç'));
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    final profile = await tester.runAsync(repository.profile);
    expect(profile!.level, DifficultyLevel.b1.step(1).code);
    expect(prefs.getInt(levelUpsKey), 1);
  });
}
