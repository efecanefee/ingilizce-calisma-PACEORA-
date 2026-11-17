import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/data/streak_freeze.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  final today = DateTime(2026, 11, 17);
  DateTime ago(int days) => DateTime(2026, 11, 17 - days);

  group('nextStreakWithFreezes', () {
    test('dün çalışıldıysa +1, hak harcanmaz', () {
      final r = nextStreakWithFreezes(
        current: 4,
        lastStudy: ago(1),
        today: today,
        freezes: 2,
      );
      expect(r.streak, 5);
      expect(r.bridged, isEmpty);
    });

    test('kaçırılan günler haklarla karşılanır', () {
      final r = nextStreakWithFreezes(
        current: 4,
        lastStudy: ago(3),
        today: today,
        freezes: 2,
      );
      expect(r.streak, 5);
      expect(r.bridged, [ago(2), ago(1)]);
    });

    test('haklar yetmezse seri sıfırlanır ve hak harcanmaz', () {
      final r = nextStreakWithFreezes(
        current: 4,
        lastStudy: ago(4),
        today: today,
        freezes: 2,
      );
      expect(r.streak, 1);
      expect(r.bridged, isEmpty);
    });

    test('ilk gün, aynı gün ve sıfır seri', () {
      expect(
        nextStreakWithFreezes(
          current: 0,
          lastStudy: null,
          today: today,
          freezes: 1,
        ).streak,
        1,
      );
      expect(
        nextStreakWithFreezes(
          current: 3,
          lastStudy: today,
          today: today,
          freezes: 1,
        ).streak,
        3,
      );
      // Korunacak bir seri yoksa hak boşa harcanmaz.
      final none = nextStreakWithFreezes(
        current: 0,
        lastStudy: ago(2),
        today: today,
        freezes: 1,
      );
      expect(none.bridged, isEmpty);
    });
  });

  test('displayStreak durumları', () {
    ({int streak, StreakStatus status, int freezesNeeded}) show(
      int daysAgo,
      int freezes,
    ) => displayStreak(
      stored: 6,
      lastStudy: ago(daysAgo),
      today: today,
      freezes: freezes,
    );

    expect(show(0, 0).status, StreakStatus.done);
    expect(show(1, 0).status, StreakStatus.pending);
    expect(show(1, 0).streak, 6);
    final protected = show(3, 2);
    expect(protected.status, StreakStatus.protected);
    expect(protected.freezesNeeded, 2);
    expect(protected.streak, 6);
    // Gün kaçırılınca eski sayı artık gösterilmez.
    final broken = show(3, 1);
    expect(broken.status, StreakStatus.broken);
    expect(broken.streak, 0);
  });

  test('satın alma: bakiye ve üst sınır, harcama', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();

    expect(await FreezeState.buy(prefs, totalXp: freezeCost - 1), isFalse);
    expect(await FreezeState.buy(prefs, totalXp: 250), isTrue);
    expect(await FreezeState.buy(prefs, totalXp: 250), isTrue);
    // Sınır dolu.
    expect(await FreezeState.buy(prefs, totalXp: 1000), isFalse);

    var s = FreezeState.read(prefs);
    expect(s.owned, maxFreezes);
    expect(s.spentXp, 2 * freezeCost);
    expect(s.balance(250), 50);

    await FreezeState.consume(prefs, [ago(1)]);
    s = FreezeState.read(prefs);
    expect(s.owned, 1);
    expect(s.frozenDays, {ago(1)});
    // Harcanan XP yalnızca bakiyeden düşer; 250 XP'de yeni hak alınamaz.
    expect(s.canBuy(250), isFalse);
    expect(s.canBuy(300), isTrue);
  });

  group('gün tamamlama', () {
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

    Future<void> setStreak(int streak, DateTime lastStudy) => db
        .update(db.userProfiles)
        .write(
          UserProfilesCompanion(
            streak: Value(streak),
            lastStudyDate: Value(lastStudy),
          ),
        );

    test('kaçırılan gün hakla karşılanır, hak düşer, gün buz olur', () async {
      final now = DateTime.now();
      final twoDaysAgo = DateTime(now.year, now.month, now.day - 2);
      await setStreak(5, twoDaysAgo);
      SharedPreferences.setMockInitialValues({FreezeState.ownedKey: 2});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
      );
      addTearDown(container.dispose);

      final week = await container.read(weekPlanProvider.future);
      await container.read(weekPlanProvider.notifier).completeDay(week.today!);

      final profile = await repository.profile();
      expect(profile!.streak, 6);
      final freeze = FreezeState.read(prefs);
      expect(freeze.owned, 1);
      expect(freeze.frozenDays, {DateTime(now.year, now.month, now.day - 1)});
    });

    test('hak yoksa seri sıfırdan başlar', () async {
      final now = DateTime.now();
      await setStreak(5, DateTime(now.year, now.month, now.day - 2));
      final bridged = await repository.completeDay(
        (await repository.planForWeek(now)).first,
        now: now,
      );
      expect(bridged, isEmpty);
      expect((await repository.profile())!.streak, 1);
    });
  });

  group('ana sayfa', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = Repository(db);
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      await repository.replaceWeeklyPlan(DateTime.now(), [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
      ]);
      final now = DateTime.now();
      await db
          .update(db.userProfiles)
          .write(
            UserProfilesCompanion(
              streak: const Value(5),
              lastStudyDate: Value(DateTime(now.year, now.month, now.day - 2)),
            ),
          );
    });
    tearDown(() => db.close());

    Future<SharedPreferences> pumpHome(
      WidgetTester tester,
      Map<String, Object> values,
    ) async {
      SharedPreferences.setMockInitialValues(values);
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

    testWidgets('hak yoksa kopan seri 0 görünür, XP yetmezse alınamaz', (
      tester,
    ) async {
      await pumpHome(tester, {});
      expect(find.text('0 gün'), findsOneWidget);

      await tester.tap(find.text('0 gün'));
      await _advance(tester);
      expect(find.text('Seri koruma'), findsOneWidget);
      expect(find.textContaining('Serin koptu'), findsOneWidget);
      final button = tester.widget<ButtonStyleButton>(
        find.ancestor(
          of: find.text('Hak al · $freezeCost XP'),
          matching: find.byWidgetPredicate((w) => w is ButtonStyleButton),
        ),
      );
      expect(button.onPressed, isNull);
    });

    testWidgets('hak varken seri korunur; XP ile yeni hak alınır', (
      tester,
    ) async {
      final prefs = await pumpHome(tester, {
        FreezeState.ownedKey: 1,
        // 150 kart tekrarı = 300 XP.
        'cards_reviewed_2026-01-05T00:00:00.000': 150,
      });
      expect(find.text('5 gün'), findsOneWidget);
      expect(find.byIcon(Icons.ac_unit_rounded), findsWidgets);

      await tester.tap(find.text('5 gün'));
      await _advance(tester);
      expect(find.textContaining('1 gün kaçırdın'), findsOneWidget);

      await tester.tap(find.text('Hak al · $freezeCost XP'));
      await _advance(tester);
      expect(prefs.getInt(FreezeState.ownedKey), 2);
      expect(prefs.getInt(FreezeState.spentKey), freezeCost);
      expect(find.text('Haklar dolu (2/2)'), findsOneWidget);
    });
  });
}
