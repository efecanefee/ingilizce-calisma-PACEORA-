import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/avatar.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Küçük telefon + büyük yazı boyutunda sekmeleri baştan sona gezer ve
/// düzen hatası (RenderFlex overflow vb.) olmadığını doğrular.
///
/// Testler debug modda çalıştığı için her taşma bir istisna olarak yakalanır.
void main() {
  Future<void> advance(WidgetTester tester) async {
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  /// Listeyi sonuna kadar kaydırır; her adımda yeni çizilen öğeler de
  /// düzen kontrolünden geçer.
  Future<void> scrollThrough(WidgetTester tester) async {
    for (var i = 0; i < 12; i++) {
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -400));
      await advance(tester);
      expect(tester.takeException(), isNull);
    }
  }

  for (final (label, size, textScale) in [
    ('küçük telefon', const Size(360, 640), 1.3),
    ('tablet', const Size(800, 1280), 1.0),
  ]) {
    testWidgets('$label: sekmelerde düzen hatası yok', (tester) async {
      tester.view.physicalSize = size * 3;
      tester.view.devicePixelRatio = 3;
      tester.platformDispatcher.textScaleFactorTestValue = textScale;
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = Repository(db);
      await repository.saveProfile(
        name: 'Efecan Uzunisimli',
        level: 'B2+',
        dailyMinutes: 20,
      );
      await repository.replaceWeeklyPlan(DateTime.now(), [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(
            grammarTopic: 'Present Perfect Continuous vs Past Perfect $i',
            vocabTheme: 'Uzun bir kelime teması: iş hayatı ve kariyer $i',
          ),
      ]);

      SharedPreferences.setMockInitialValues({});
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
      await advance(tester);
      expect(tester.takeException(), isNull);

      for (final tab in ['Bugün', 'Program', 'İlerleme', 'Ayarlar']) {
        await tester.tap(find.text(tab));
        await advance(tester);
        expect(tester.takeException(), isNull, reason: tab);
        await scrollThrough(tester);
      }

      // Pratik ekranları.
      await tester.tap(find.text('Bugün'));
      await advance(tester);
      for (final tile in ['Konuşma', 'Dinle ve yaz', 'Kelime Rallisi']) {
        await tester.scrollUntilVisible(
          find.text(tile),
          300,
          scrollable: find.byType(Scrollable).first,
        );
        await advance(tester);
        await tester.tap(find.text(tile));
        await advance(tester);
        expect(tester.takeException(), isNull, reason: tile);
        await tester.tap(find.byType(BackButton));
        await advance(tester);
      }

      // Profil ve görünüm düzenleyici.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 4000));
      await advance(tester);
      await tester.tap(find.byType(PlayerAvatar).first);
      await advance(tester);
      expect(find.text('Vitrin'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'profil');
      await scrollThrough(tester);
      await tester.tap(find.byTooltip('Görünümü düzenle'));
      await advance(tester);
      expect(find.text('ÇERÇEVE'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'düzenleyici');
    });
  }
}
