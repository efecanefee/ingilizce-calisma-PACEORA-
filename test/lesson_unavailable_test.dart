import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/gemini_service.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/features/lesson/lesson_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Ders hazırlanamayınca çıkan "elle tamamlandı" düğmesi bugünü tamamlar ve
/// seriyi uzatır; telafi dersinde görünürse yanlış günü tamamlardı.
void main() {
  for (final today in [true, false]) {
    testWidgets('elle işaretleme yalnızca bugünün dersinde (bugün: $today)', (
      tester,
    ) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = Repository(db);
      final now = DateTime.now();
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 15);
      // Program dün başladı; dün kaçırıldı.
      final yesterday = DateTime(now.year, now.month, now.day - 1);
      await repository.replaceWeeklyPlan(yesterday, [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
      ]);
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            databaseProvider.overrideWithValue(db),
            sharedPreferencesProvider.overrideWithValue(prefs),
            // Anahtar yok: ders üretilemez.
            geminiServiceProvider.overrideWithValue(GeminiService(apiKey: '')),
            if (!today)
              lessonProvider.overrideWith(
                () => MakeupLessonNotifier(yesterday),
              ),
          ],
          child: const MaterialApp(home: LessonScreen()),
        ),
      );
      for (var i = 0; i < 15; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(find.text('Ders hazırlanamadı'), findsOneWidget);
      expect(
        find.text('Günü elle tamamlandı işaretle'),
        today ? findsOneWidget : findsNothing,
      );
    });
  }
}
