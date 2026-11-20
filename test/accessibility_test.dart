import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/features/placement/placement_screen.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Flutter'ın erişilebilirlik yönergeleri: dokunulabilir her öğe etiketli,
/// en az 48x48 dp ve yazılar okunabilir kontrastta olmalı.
void main() {
  for (final mode in ['light', 'dark']) {
    for (final tab in [
      'Bugün',
      'Program',
      'İlerleme',
      'Ayarlar',
      'Profil',
      'Dolap',
    ]) {
      testWidgets('$tab sekmesi erişilebilirlik yönergeleri ($mode)', (
        tester,
      ) async {
        final handle = tester.ensureSemantics();
        tester.view.physicalSize = const Size(1170, 2532);
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.reset);

        final db = AppDatabase.forTesting(NativeDatabase.memory());
        addTearDown(db.close);
        final repository = Repository(db);
        await repository.saveProfile(
          name: 'Yağız',
          level: 'B1',
          dailyMinutes: 20,
        );
        await repository.replaceWeeklyPlan(DateTime.now(), [
          for (var i = 0; i < 7; i++)
            PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
        ]);
        SharedPreferences.setMockInitialValues({'theme_mode': mode});
        final prefs = await SharedPreferences.getInstance();

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(prefs),
              databaseProvider.overrideWithValue(db),
            ],
            child: const PaceoraApp(onboardingDone: true),
          ),
        );
        Future<void> settle() async {
          for (var i = 0; i < 20; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }

        await settle();
        switch (tab) {
          case 'Bugün':
            break;
          case 'Profil':
            await tester.tap(find.bySemanticsLabel(RegExp('^Profilim')));
            await settle();
          case 'Dolap':
            await tester.tap(find.bySemanticsLabel("Pace'in dolabını aç"));
            await settle();
          default:
            await tester.tap(find.text(tab));
            await settle();
        }

        await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
        await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
        await expectLater(tester, meetsGuideline(textContrastGuideline));
        handle.dispose();
      });
    }
  }

  testWidgets('seviye testi ekranı erişilebilirlik yönergeleri', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const MaterialApp(home: PlacementTestScreen()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 500));
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
    await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
    await expectLater(tester, meetsGuideline(textContrastGuideline));
    handle.dispose();
  });
}
