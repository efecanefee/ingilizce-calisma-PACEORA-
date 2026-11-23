import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/constants.dart';
import 'package:paceora/app/welcome_tour.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    final repository = Repository(db);
    await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 15);
    await repository.replaceWeeklyPlan(DateTime.now(), [
      for (var i = 0; i < 7; i++)
        PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
    ]);
  });

  tearDown(() => db.close());

  Future<SharedPreferences> pumpApp(
    WidgetTester tester, {
    bool tourPending = false,
  }) async {
    SharedPreferences.setMockInitialValues({
      if (tourPending) AppConstants.prefTourPending: true,
    });
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
    await _advance(tester);
    return prefs;
  }

  testWidgets('tur bekliyorsa Pace karşılar, sekmeleri sırayla gezer', (
    tester,
  ) async {
    final prefs = await pumpApp(tester, tourPending: true);

    expect(find.text(tourSteps.first.title), findsOneWidget);
    expect(find.text('1/${tourSteps.length}'), findsOneWidget);

    // Bugün → Pratik: ikinci "İleri"de Pratik sekmesi açılır.
    await tester.tap(find.text('İleri'));
    await _advance(tester);
    expect(find.text(tourSteps[1].body), findsOneWidget);
    await tester.tap(find.text('İleri'));
    await _advance(tester);
    expect(find.text(tourSteps[2].body), findsOneWidget);
    final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
    expect(bar.selectedIndex, 1);

    // Sona kadar git, "Başla" turu kapatır ve Bugün'e döner.
    for (var i = 3; i < tourSteps.length; i++) {
      await tester.tap(find.text('İleri'));
      await _advance(tester);
    }
    expect(find.text('Atla'), findsNothing);
    await tester.tap(find.text('Başla'));
    await _advance(tester);

    expect(find.byType(WelcomeTour), findsNothing);
    expect(prefs.getBool(AppConstants.prefTourPending), isFalse);
    expect(
      tester.widget<NavigationBar>(find.byType(NavigationBar)).selectedIndex,
      0,
    );
  });

  testWidgets('Atla turu hemen kapatır', (tester) async {
    final prefs = await pumpApp(tester, tourPending: true);
    await tester.tap(find.text('Atla'));
    await _advance(tester);
    expect(find.byType(WelcomeTour), findsNothing);
    expect(prefs.getBool(AppConstants.prefTourPending), isFalse);
  });

  testWidgets('bayrak yoksa (eski kullanıcı) tur çıkmaz', (tester) async {
    await pumpApp(tester);
    expect(find.byType(WelcomeTour), findsNothing);
  });
}
