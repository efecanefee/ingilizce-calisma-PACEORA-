import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/gemini_service.dart';
import 'package:paceora/data/lesson_models.dart';
import 'package:paceora/data/offline_lessons.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  final bank = OfflineLessonBank.parse(
    File(OfflineLessonBank.asset).readAsStringSync(),
  );

  test('havuzdaki tüm dersler geçerli ve yedek programın her konusu var', () {
    expect(bank.length, 24);
    for (final level in ['A2', 'B1', 'B2', 'C1']) {
      final plan = fallbackWeeklyPlan(level);
      for (var day = 0; day < plan.length; day++) {
        final lesson = bank.lessonFor(
          level: level,
          grammarTopic: plan[day].grammarTopic,
          dayIndex: day,
        );
        expect(lesson, isNotNull, reason: '$level gün $day');
        expect(lesson!.vocab, isNotEmpty);
        expect(lesson.questionCount, greaterThanOrEqualTo(8));
      }
    }
  });

  test('A2 ve C1 programının konusu, açılan dersin konusuyla aynı', () {
    final json = jsonDecode(File(OfflineLessonBank.asset).readAsStringSync())
        as Map<String, dynamic>;
    for (final level in ['A2', 'C1']) {
      final plan = fallbackWeeklyPlan(level);
      for (var day = 0; day < 6; day++) {
        final topic = plan[day].grammarTopic;
        final entry = (json['lessons'] as List<dynamic>)
            .cast<Map<String, dynamic>>()
            .firstWhere((l) => l['level'] == level && l['grammarTopic'] == topic);
        final lesson = bank.lessonFor(
          level: level,
          grammarTopic: topic,
          dayIndex: day,
        )!;
        final content = entry['lesson'] as Map<String, dynamic>;
        final words = [
          for (final v in content['vocab'] as List<dynamic>)
            (v as Map<String, dynamic>)['word'],
        ];
        expect(lesson.vocab.map((v) => v.word), words, reason: topic);
      }
    }
  });

  test('hazır ders günlük süreye göre kısalır ve uzar', () {
    DailyLesson fit(int minutes) => bank.lessonFor(
      level: 'B1',
      grammarTopic: 'Bilinmeyen konu',
      dayIndex: 1,
      size: LessonSize.forMinutes(minutes),
    )!;

    for (final minutes in [5, 15, 30, 60]) {
      final size = LessonSize.forMinutes(minutes);
      final lesson = fit(minutes);
      expect(lesson.vocab, hasLength(size.vocab), reason: '$minutes dk');
      expect(lesson.gapFill, hasLength(size.gapFill), reason: '$minutes dk');
      expect(lesson.translate, hasLength(size.translate), reason: '$minutes dk');
      expect(lesson.quiz, hasLength(size.quiz), reason: '$minutes dk');
      // Uzatılan derste aynı kelime iki kez gelmez.
      expect(
        lesson.vocab.map((v) => v.word).toSet(),
        hasLength(lesson.vocab.length),
      );
    }
  });

  test('seviye kodları doğru ders grubuna gider', () {
    expect(OfflineLessonBank.groupOf('A2'), 'A2');
    expect(OfflineLessonBank.groupOf('B1-'), 'B1');
    expect(OfflineLessonBank.groupOf('B1+'), 'B1');
    expect(OfflineLessonBank.groupOf('B2-'), 'B2');
    expect(OfflineLessonBank.groupOf('B2+'), 'B2');
    expect(OfflineLessonBank.groupOf('C1'), 'C1');
  });

  test('Gemini planındaki bilinmeyen konuya haftanın gününe göre ders', () {
    final a = bank.lessonFor(
      level: 'B1+',
      grammarTopic: 'Modal verbs',
      dayIndex: 2,
    );
    final b = bank.lessonFor(level: 'B2-', grammarTopic: 'X', dayIndex: 2);
    expect(a, isNotNull);
    expect(b, isNotNull);
    expect(a!.vocab.first.word, isNot(b!.vocab.first.word));
  });

  testWidgets('anahtar yokken hazır dersle çalışılır', (tester) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = Repository(db);
    await repository.saveProfile(name: 'Yağız', level: 'B1', dailyMinutes: 15);
    await repository.replaceWeeklyPlan(DateTime.now(), fallbackWeeklyPlan('B1'));

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(GeminiService(apiKey: '')),
          offlineLessonBankProvider.overrideWith((_) => bank),
        ],
        child: const PaceoraApp(onboardingDone: true),
      ),
    );
    Future<void> advance() async {
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
    }

    await advance();
    await tester.tap(find.text('Bugünü çalış'));
    await advance();

    expect(find.text('Ders hazırlanamadı'), findsOneWidget);
    await tester.tap(find.text('Hazır dersle çalış'));
    await advance();

    expect(find.text('Bugünün dersi · hazır ders'), findsOneWidget);
    expect(find.text('KELİMELER'), findsOneWidget);
    final saved = await repository.lessonFor(DateTime.now());
    expect(saved, isNotNull);
    expect(saved!.contentJson, contains('"offline":true'));
  });
}
