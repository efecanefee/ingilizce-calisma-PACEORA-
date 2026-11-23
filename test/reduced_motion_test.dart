import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/motion.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// "Animasyonları azalt" açıkken hiçbir sekmede sürekli dönen animasyon
/// kalmamalı: ekran durgunlaşınca yeni kare istenmez.
void main() {
  tearDown(() => Motion.reduced = false);

  testWidgets('animasyonları azalt: sekmeler durgunlaşır', (tester) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = Repository(db);
    await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 15);
    await repository.replaceWeeklyPlan(DateTime.now(), [
      for (var i = 0; i < 7; i++)
        PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
    ]);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: PaceoraApp(onboardingDone: true),
        ),
      ),
    );

    Future<void> settle(String tab) async {
      for (var i = 0; i < 40; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(
        tester.binding.hasScheduledFrame,
        isFalse,
        reason: '$tab sekmesinde durmayan animasyon var',
      );
    }

    await settle('Bugün');
    for (final tab in ['Pratik', 'Program', 'İlerleme', 'Ayarlar']) {
      await tester.tap(find.text(tab).last);
      await settle(tab);
    }
  });
}
