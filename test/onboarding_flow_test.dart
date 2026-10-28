import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/constants.dart';
import 'package:paceora/app/logo.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Animasyonlu göstergeler yüzünden pumpAndSettle takılmasın diye
/// sabit sayıda kare ilerletip sonra oturmasını bekler.
Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  testWidgets('onboarding tamamlanınca ana ekran haftalık planı gösterir',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: const PaceoraApp(onboardingDone: false),
      ),
    );
    await _advance(tester);

    // 1. adım: isim — karşılama ekranında tam logo
    expect(find.text('Merhaba! Sana nasıl hitap edelim?'), findsOneWidget);
    expect(find.byType(PaceoraLockup), findsOneWidget);
    expect(find.byType(PaceoraWordmark), findsNothing);
    await tester.enterText(find.byType(TextField), 'Efecan');
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Devam'));
    await _advance(tester);

    // 2. adım: seviye — başlıkta kompakt logo
    expect(find.text('Seviyen ne durumda?'), findsOneWidget);
    expect(find.byType(PaceoraWordmark), findsOneWidget);
    await tester.tap(find.widgetWithText(ChoiceChip, 'B2'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Devam'));
    await _advance(tester);

    // 3. adım: günlük süre
    expect(find.text('Günde ne kadar vakit ayırabilirsin?'), findsOneWidget);
    await tester.tap(find.text('Günde 20 dakika'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Programımı oluştur'));
    await _advance(tester);

    // Profil ve plan kalıcı olarak yazıldı mı?
    expect(prefs.getBool(AppConstants.prefOnboardingDone), isTrue);
    final profile = await db.select(db.userProfiles).getSingle();
    expect(profile.name, 'Efecan');
    expect(profile.level, 'B2');
    expect(profile.dailyMinutes, 20);
    expect(await db.select(db.weeklyPlanDays).get(), hasLength(7));

    // Ana ekran — AppBar'da logo
    expect(find.byType(PaceoraWordmark), findsOneWidget);
    expect(find.text('Merhaba, Efecan'), findsOneWidget);
    expect(find.text('Seviye B2 · günde 20 dk'), findsOneWidget);
    expect(find.text('0 gün'), findsOneWidget);
    // API anahtarı olmadığı için yedek program kullanıldı.
    expect(find.byIcon(Icons.cloud_off), findsOneWidget);
    expect(find.text('BUGÜN'), findsOneWidget);
    // Asıl eylem ders akışını açar; elle işaretleme ikincil yol olarak durur.
    expect(find.text('Bugünü çalış'), findsOneWidget);

    // Elle tamamla → streak 1 olur, buton yerini tamamlandı mesajına bırakır.
    await tester.ensureVisible(
      find.widgetWithText(TextButton, 'Çalışmadan tamamlandı işaretle'),
    );
    await _advance(tester);
    await tester.tap(
      find.widgetWithText(TextButton, 'Çalışmadan tamamlandı işaretle'),
    );
    await _advance(tester);
    expect(find.text('Bugünkü çalışman tamam. Yarın görüşürüz!'), findsOneWidget);

    // Seri rozeti karşılama kartında, listenin en üstünde.
    await tester.drag(find.byType(Scrollable).first, const Offset(0, 800));
    await _advance(tester);
    expect(find.text('1 gün'), findsOneWidget);
    expect((await db.select(db.userProfiles).getSingle()).streak, 1);
  });
}
