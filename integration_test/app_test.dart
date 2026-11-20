import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:paceora/main.dart' as app;

/// Uçtan uca akış, gerçek cihazda/emülatörde: ilk kurulum → onboarding →
/// ana ekran → günün dersi.
///
/// Uygulama temiz kurulmuş olmalı (önceki veriler onboarding'i atlatır).
/// Gemini anahtarı olmadan da geçer: ders üretilemezse hazır ders açılır.
///
/// Çalıştırma: `flutter test integration_test -d <cihaz>`
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> settle(WidgetTester tester, [int frames = 20]) async {
    for (var i = 0; i < frames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> waitFor(WidgetTester tester, Finder finder) async {
    for (var i = 0; i < 150 && finder.evaluate().isEmpty; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(finder, findsWidgets);
  }

  testWidgets('ilk kurulumdan günün dersine', (tester) async {
    await app.main();
    await settle(tester);

    // 1. adım: isim
    await waitFor(tester, find.text('Merhaba! Sana nasıl hitap edelim?'));
    await tester.enterText(find.byType(TextField), 'Test');
    await tester.tap(find.widgetWithText(FilledButton, 'Devam'));
    await settle(tester);

    // 2. adım: seviye
    await tester.tap(find.widgetWithText(ChoiceChip, 'B1'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Devam'));
    await settle(tester);

    // 3. adım: seviye önizlemesi
    expect(find.text('Nelere odaklanacağız'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Devam'));
    await settle(tester);

    // 4. adım: günlük süre
    await tester.ensureVisible(find.text('Günde 15 dakika'));
    await tester.tap(find.text('Günde 15 dakika'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Programımı oluştur'));

    // Ana ekran: program hazırlanır (Gemini ya da yedek plan).
    await waitFor(tester, find.text('Merhaba, Test'));
    await waitFor(tester, find.text('Bugünü çalış'));
    await tester.ensureVisible(find.text('Bugünü çalış'));
    await tester.tap(find.text('Bugünü çalış'));
    await settle(tester);

    // Ders: Gemini'den ya da hazır ders havuzundan.
    final unavailable = find.text('Hazır dersle çalış');
    for (var i = 0; i < 150; i++) {
      if (find.text('KELİMELER').evaluate().isNotEmpty) break;
      if (unavailable.evaluate().isNotEmpty) {
        await tester.tap(unavailable);
      }
      await tester.pump(const Duration(milliseconds: 200));
    }
    expect(find.text('KELİMELER'), findsOneWidget);
  });
}
