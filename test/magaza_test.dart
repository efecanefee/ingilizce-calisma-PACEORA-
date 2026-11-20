@Tags(['magaza'])
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:clock/clock.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/features/home/home_screen.dart';
import 'package:paceora/features/placement/placement_screen.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'support/app_fonts.dart';

/// Mağaza ekran görüntüleri. Varsayılan test çalıştırmasında atlanır;
/// üretmek için (Linux):
///
///   flutter test --tags magaza --run-skipped
///
/// Görüntüler docs/magaza/ekranlar/ altına yazılır. Emoji'ler için Noto
/// Color Emoji yazı tipi gerekir: PACE_EMOJI_FONT ortam değişkeniyle yolu
/// verilebilir, yoksa sistemdeki fonts-noto-color-emoji paketi aranır.

/// Sabit tarih: 18 Kasım 2026 Çarşamba, 10:00.
final _now = DateTime(2026, 11, 18, 10);

/// Hedef boyutlar: Google Play telefon ve App Store 6,7 inç.
const _devices = {
  'play': (Size(1080, 1920), 2.625),
  'ios': (Size(1290, 2796), 3.0),
};

void main() {
  setUpAll(() async {
    await loadAppFonts();
    final emoji = _emojiFont();
    if (emoji != null) {
      final bytes = ByteData.sublistView(emoji.readAsBytesSync());
      await (FontLoader('Noto Color Emoji')..addFont(Future.value(bytes)))
          .load();
    }
  });

  for (final MapEntry(key: device, value: (size, ratio)) in _devices.entries) {
    Future<void> pumpApp(
      WidgetTester tester, {
      String mode = 'light',
      bool onboardingDone = true,
    }) async {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = ratio;
      addTearDown(tester.view.reset);
      final db = await _seededDatabase();
      addTearDown(db.close);
      SharedPreferences.setMockInitialValues({
        'theme_mode': mode,
        'api_key_hint_dismissed': true,
      });
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
          ],
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: PaceoraApp(onboardingDone: onboardingDone),
          ),
        ),
      );
      await _settle(tester);
    }

    Future<void> shot(WidgetTester tester, String name) async {
      await _settle(tester);
      await _save(tester, '${device}_$name');
    }

    testWidgets('$device: ekranlar', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await pumpApp(tester);
        await shot(tester, '1_bugun');

        await tester.tap(find.bySemanticsLabel("Pace'in dolabını aç"));
        await shot(tester, '2_dolap');
        await tester.tapAt(const Offset(10, 10));
        await _settle(tester);

        await tester.tap(find.text('Program').last);
        await shot(tester, '3_program');

        await tester.tap(find.text('İlerleme').last);
        await shot(tester, '4_ilerleme');

        await tester.tap(find.text('Bugün').last);
        await _settle(tester);
        unawaited(openPlacementTest(tester.element(find.byType(HomeScreen))));
        await shot(tester, '5_seviye_testi');
      });
    });

    testWidgets('$device: koyu tema', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await pumpApp(tester, mode: 'dark');
        await shot(tester, '6_bugun_koyu');
      });
    });

    testWidgets('$device: karşılama', (tester) async {
      await withClock(Clock.fixed(_now), () async {
        await pumpApp(tester, onboardingDone: false);
        await shot(tester, '7_karsilama');
      });
    });
  }
}

File? _emojiFont() {
  for (final path in [
    Platform.environment['PACE_EMOJI_FONT'],
    '/usr/share/fonts/truetype/noto/NotoColorEmoji.ttf',
  ]) {
    if (path != null && File(path).existsSync()) return File(path);
  }
  return null;
}

Future<AppDatabase> _seededDatabase() async {
  final db = AppDatabase.forTesting(NativeDatabase.memory());
  final repository = Repository(db);
  await repository.saveProfile(name: 'Yağız', level: 'B1', dailyMinutes: 20);
  await repository.replaceWeeklyPlan(_now, [
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
  await db.update(db.userProfiles).write(
    UserProfilesCompanion(
      streak: const Value(14),
      lastStudyDate: Value(_now.subtract(const Duration(days: 1))),
    ),
  );
  // Geçmiş günlerde bitmiş dersler ve öğrenilmiş kartlar: ilerleme ekranı
  // gerçek bir kullanıcınınki gibi dolu görünsün.
  for (var i = 1; i <= 14; i++) {
    await db.into(db.lessons).insert(
      LessonsCompanion.insert(
        lessonDate: _now.subtract(Duration(days: i)),
        contentJson: '{}',
        score: Value(0.7 + (i % 4) * 0.08),
        durationSeconds: const Value(1200),
        completed: const Value(true),
      ),
    );
  }
  const words = [
    ('journey', 'yolculuk'), ('borrow', 'ödünç almak'),
    ('crowded', 'kalabalık'), ('schedule', 'program'),
    ('improve', 'geliştirmek'), ('neighbour', 'komşu'),
    ('forecast', 'tahmin'), ('experience', 'deneyim'),
    ('suburb', 'banliyö'), ('decide', 'karar vermek'),
    ('remember', 'hatırlamak'), ('cheap', 'ucuz'),
  ];
  for (final (i, (word, meaning)) in words.indexed) {
    await db.into(db.flashcards).insert(
      FlashcardsCompanion.insert(
        word: word,
        meaning: meaning,
        exampleSentence: '',
        source: 'lesson',
        reps: const Value(4),
        intervalDays: Value(i.isEven ? 24 : 9),
        dueDate: _now.add(const Duration(days: 5)),
      ),
    );
  }
  return db;
}

/// Ekranın tamamını PNG olarak docs/magaza/ekranlar/ altına yazar.
Future<void> _save(WidgetTester tester, String name) async {
  final element = tester.binding.rootElement!;
  final image = await captureImage(element);
  await tester.runAsync(() async {
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    final file = File('docs/magaza/ekranlar/$name.png')
      ..createSync(recursive: true);
    file.writeAsBytesSync(data!.buffer.asUint8List());
  });
  image.dispose();
}

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
