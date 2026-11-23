@Tags(['golden'])
library;

import 'dart:io';

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

/// Sabit tarih: 18 Kasım 2026 Çarşamba, 10:00.
final _now = DateTime(2026, 11, 18, 10);

void main() {
  final skip = !Platform.isLinux;

  setUpAll(loadAppFonts);

  Future<void> pumpHome(
    WidgetTester tester, {
    required String mode,
    Map<String, Object> prefs = const {},
  }) async {
    tester.view.physicalSize = const Size(1170, 2532);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final repository = Repository(db);
    await repository.saveProfile(name: 'Yağız', level: 'B1', dailyMinutes: 20);
    // Program pazartesi (16 Kasım) başladı: bugün haftanın 3. günü, ilk iki
    // gün çalışıldı. Program başlangıç gününe bağlı olduğu için plan
    // pazartesiye yazılır.
    await repository.replaceWeeklyPlan(DateTime(2026, 11, 16), [
      for (final (t, v) in [
        ('Present Simple vs Continuous', 'Günlük rutin'),
        ('Past Simple', 'Seyahat'),
        ('Present Perfect', 'Deneyimler'),
        ('Comparatives', 'Şehir hayatı'),
        ('Future forms', 'Planlar'),
        ('First conditional', 'Hava durumu'),
        ('Haftanın tekrarı', 'Tüm kelimeler'),
      ])
        PlanDaySpec(grammarTopic: t, vocabTheme: v),
    ]);
    final plan = await repository.planForWeek(_now);
    for (final day in plan.where((d) => d.dayIndex < 2)) {
      await (db.update(db.weeklyPlanDays)..where((t) => t.id.equals(day.id)))
          .write(const WeeklyPlanDaysCompanion(status: Value('completed')));
    }
    await db
        .update(db.userProfiles)
        .write(
          UserProfilesCompanion(
            streak: const Value(6),
            lastStudyDate: Value(_now.subtract(const Duration(days: 1))),
          ),
        );

    SharedPreferences.setMockInitialValues({'theme_mode': mode, ...prefs});
    final sharedPrefs = await SharedPreferences.getInstance();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(sharedPrefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: const MediaQuery(
          // Animasyonlar başlangıç karesinde dursun: görüntü kararlı olsun.
          data: MediaQueryData(disableAnimations: true),
          child: PaceoraApp(onboardingDone: true),
        ),
      ),
    );
    await _settle(tester);
  }

  for (final mode in ['light', 'dark']) {
    testWidgets('ana ekran ($mode)', skip: skip, (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await pumpHome(tester, mode: mode);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/ana_ekran_$mode.png'),
        );
      });
    });

    testWidgets('Pace\'in dolabı ($mode)', skip: skip, (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await pumpHome(tester, mode: mode);
        await tester.tap(find.bySemanticsLabel("Pace'in dolabını aç"));
        await _settle(tester);
        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile('goldens/dolap_$mode.png'),
        );
      });
    });
  }
}

/// Görseller yüklenip ekran yerleşene kadar ilerletir.
Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}
