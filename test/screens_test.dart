import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/placement.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/data/review_models.dart';
import 'package:paceora/data/rewards.dart';
import 'package:paceora/data/streak_freeze.dart';
import 'package:paceora/data/wardrobe.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scroll_helper.dart';

/// Ekranlarda sürekli tekrarlayan animasyonlar (alev, parıltı) olduğu için
/// pumpAndSettle hiç oturmaz; sabit sayıda kare ilerletilir.
Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late AppDatabase db;
  late Repository repository;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = Repository(db);
    await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
    await repository.replaceWeeklyPlan(DateTime.now(), [
      for (var i = 0; i < 7; i++)
        PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
    ]);
  });

  tearDown(() => db.close());

  Future<SharedPreferences> pumpApp(
    WidgetTester tester, [
    Map<String, Object> prefs = const {},
  ]) async {
    SharedPreferences.setMockInitialValues(prefs);
    final instance = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(instance),
          databaseProvider.overrideWithValue(db),
        ],
        child: const PaceoraApp(onboardingDone: true),
      ),
    );
    await _advance(tester);
    return instance;
  }

  testWidgets('Program sekmesi haftayı ve gün ayrıntısını gösterir', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Program'));
    await _advance(tester);

    expect(find.text('Haftalık program'), findsOneWidget);
    expect(find.text('/ 7 gün tamam'), findsOneWidget);

    final today = DateTime.now().weekday - DateTime.monday;
    await tester.scrollUntilVisible(
      find.text('Konu $today'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Konu $today'));
    await _advance(tester);

    // Alt sayfa: konu ayrıntısı ve bugünün dersine giden düğme.
    expect(find.text('Dilbilgisi'), findsOneWidget);
    expect(find.text('Kelime teması'), findsOneWidget);
    expect(find.text('Derse başla'), findsOneWidget);
  });

  testWidgets('ana ekrandaki gün kutucuğu o günün konusunu açar', (
    tester,
  ) async {
    await pumpApp(tester);

    final today = DateTime.now().weekday - DateTime.monday;
    const initials = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];
    await tester.scrollUntilVisible(
      find.text(initials[today]),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(initials[today]));
    await _advance(tester);

    expect(find.text('Dilbilgisi'), findsOneWidget);
    expect(find.text('Derse başla'), findsOneWidget);
  });

  testWidgets('Pace\'e dokununca dolap açılır, forma onayla alınır', (
    tester,
  ) async {
    // 100 kart tekrarı = 200 XP; kutlamalar önceden görülmüş sayılır.
    final prefs = await pumpApp(tester, {
      'seen_player_level': 99,
      'seen_badges': [for (final b in badges) b.id],
      cardsReviewedKey(DateTime.now()): 100,
    });

    await tester.tap(find.bySemanticsLabel("Pace'in dolabını aç"));
    await _advance(tester);
    expect(find.text("Pace'in dolabı"), findsOneWidget);

    await tester.tap(find.text('Kırmızı Şimşek'));
    await tester.pump();
    final buy = find.text('Kırmızı Şimşek al · 150 XP');
    await tester.ensureVisible(buy);
    await tester.tap(buy);
    await _advance(tester);

    // Onay penceresi: vazgeçince hiçbir şey alınmaz.
    expect(find.text('Kırmızı Şimşek alınsın mı?'), findsOneWidget);
    await tester.tap(find.text('Vazgeç'));
    await _advance(tester);
    expect(WardrobeState.read(prefs).owns(PaceKit.crimson), isFalse);

    await tester.tap(buy);
    await _advance(tester);
    await tester.tap(find.text('150 XP harca'));
    await _advance(tester);

    expect(find.text('Yeni forma: Kırmızı Şimşek'), findsOneWidget);
    final wardrobe = WardrobeState.read(prefs);
    expect(wardrobe.owns(PaceKit.crimson), isTrue);
    expect(wardrobe.equipped, PaceKit.crimson);
  });

  testWidgets('seri yeni hedefe ulaşınca kutlanır', (tester) async {
    await db.update(db.userProfiles).write(
      UserProfilesCompanion(
        streak: const Value(6),
        lastStudyDate: Value(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
      ),
    );
    await pumpApp(tester, {
      'seen_player_level': 99,
      'seen_badges': [for (final b in badges) b.id],
      seenStreakMilestoneKey: 3,
    });
    expect(find.text('7 günlük seri!'), findsNothing);

    // Bugünü tamamla (dersi bitirmekle aynı yol).
    final container = ProviderScope.containerOf(
      tester.element(find.byType(PaceoraApp)),
    );
    final week = await container.read(weekPlanProvider.future);
    await tester.runAsync(
      () => container.read(weekPlanProvider.notifier).completeDay(week.today!),
    );
    await _advance(tester);

    expect(find.text('7 günlük seri!'), findsOneWidget);
  });

  testWidgets('seviye testi çözülmeden ayarlardan seviye seçilemez', (
    tester,
  ) async {
    await pumpApp(tester);

    await tester.tap(find.text('Ayarlar'));
    await _advance(tester);
    await tester.tap(find.byTooltip('Profili düzenle'));
    await _advance(tester);

    final chip = tester.widget<ChoiceChip>(
      find.widgetWithText(ChoiceChip, 'B2'),
    );
    expect(chip.onSelected, isNull);
    expect(find.text('Testi çöz'), findsOneWidget);
  });

  testWidgets('profil kaydı sonrası snackbardan program yenilemek çökmez', (
    tester,
  ) async {
    // Seviye testi daha önce çözülmüş: seviye seçimi açık.
    await pumpApp(tester, {PlacementRecord.levelKey: 'B1'});

    await tester.tap(find.text('Ayarlar'));
    await _advance(tester);
    await tester.tap(find.byTooltip('Profili düzenle'));
    await _advance(tester);

    await tester.tap(find.widgetWithText(ChoiceChip, 'B2'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
    await _advance(tester);

    // Sayfa kapandı; eylem artık ölmüş State'in ref'ine dokunmamalı.
    expect(find.text('Profil güncellendi.'), findsOneWidget);
    await tester.tap(find.text('Programı yenile'));
    await _advance(tester);

    expect(tester.takeException(), isNull);
    expect((await repository.profile())!.level, 'B2');
    expect(await repository.planForWeek(DateTime.now()), hasLength(7));
  });

  testWidgets('yeni seviye ve rozet sırayla kutlanır', (tester) async {
    // 50 kart tekrarı = 100 XP: seviye 2 ve "Hafıza avcısı" rozeti.
    final prefs = await pumpApp(tester, {
      'seen_player_level': 1,
      'seen_badges': <String>[],
      cardsReviewedKey(DateTime.now()): 50,
    });

    expect(find.text('Seviye atladın!'), findsOneWidget);
    await tester.tap(find.text('Harika!'));
    await _advance(tester);

    expect(find.text('Yeni rozet: Hafıza avcısı'), findsOneWidget);
    await tester.tap(find.text('Harika!'));
    await _advance(tester);

    expect(find.text('Harika!'), findsNothing);
    expect(prefs.getInt('seen_player_level'), 2);
    expect(prefs.getStringList('seen_badges'), contains('cards_50'));
  });

  testWidgets('ilk açılışta mevcut ilerleme sessizce kaydedilir', (
    tester,
  ) async {
    final prefs = await pumpApp(tester, {cardsReviewedKey(DateTime.now()): 50});

    // "Görüldü" bilgisi yoksa geçmiş kazanımlar kutlanmaz.
    expect(find.text('Seviye atladın!'), findsNothing);
    expect(prefs.getInt('seen_player_level'), 2);
  });

  testWidgets('hata defteri ifadeleri ve pekişme ilerlemesini gösterir', (
    tester,
  ) async {
    await db
        .into(db.mistakes)
        .insert(
          MistakesCompanion.insert(
            item: 'make a decision',
            context: 'I need to ___ today.',
            type: 'vocabulary',
            timesWrong: const Value(2),
            timesCorrect: const Value(1),
          ),
        );
    await pumpApp(tester);

    await tester.tap(find.text('İlerleme'));
    await _advance(tester);
    await scrollIntoView(tester, find.text('Hata defterim'));
    await tester.tap(find.text('Hata defterim'));
    await _advance(tester);

    expect(find.text('make a decision'), findsOneWidget);
    expect(find.text('2 kez yanlış'), findsOneWidget);
    expect(find.text('1/3'), findsOneWidget);
  });

  test('seviye yükselişi rapor yenilense de kaybolmaz', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        databaseProvider.overrideWithValue(db),
      ],
    );
    addTearDown(container.dispose);

    final report = WeeklyReport(
      stats: await repository.weeklyStats(DateTime.now()),
      summary: 'İyi',
      strengths: const [],
      focus: const [],
      tip: '',
      fromLevel: 'B1',
      suggestedLevel: 'B1+',
    );
    await repository.saveWeeklyReport(report);
    await container.read(weeklyReportsProvider.future);
    await container.read(weeklyReportsProvider.notifier).applyLevel(report);

    // Aynı hafta raporu yeniden üretmek "uygulandı" kaydını değiştirir.
    await container.read(weeklyReportsProvider.notifier).generate();

    // Riverpod 3 dinleyicisiz provider'ı duraklatır; uygulamada kutlama
    // katmanı hep dinlediği için burada da bir dinleyici açılır.
    final sub = container.listen(gameProvider, (_, _) {});
    addTearDown(sub.close);
    final game = await container.read(gameProvider.future);
    expect(game.stats.levelUps, 1);
    expect(game.earnedBadgeIds, contains('level_up'));
    expect(prefs.getInt(levelUpsKey), 1);
  });
}
