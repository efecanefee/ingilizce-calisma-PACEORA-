import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/data/review_models.dart';
import 'package:paceora/data/rewards.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  testWidgets('profil kaydı sonrası snackbardan program yenilemek çökmez', (
    tester,
  ) async {
    await pumpApp(tester);

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
    await tester.scrollUntilVisible(
      find.text('Hata defterim'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
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
