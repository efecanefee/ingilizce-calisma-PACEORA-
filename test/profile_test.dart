import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/avatar.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/profile_style.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/data/rewards.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('AvatarFrame', () {
    test('seviyeyle açılır, en iyisi seçilir', () {
      expect(AvatarFrame.bestFor(1), AvatarFrame.none);
      expect(AvatarFrame.bestFor(4), AvatarFrame.bronze);
      expect(AvatarFrame.bestFor(6), AvatarFrame.silver);
      expect(AvatarFrame.bestFor(12), AvatarFrame.gold);
    });

    test('seçilen çerçeve kilitliyse seviyenin en iyisine düşülür', () {
      const style = ProfileStyle(frame: AvatarFrame.gold);
      expect(style.frameFor(3), AvatarFrame.bronze);
      expect(style.frameFor(7), AvatarFrame.gold);
      const plain = ProfileStyle(frame: AvatarFrame.none);
      expect(plain.frameFor(9), AvatarFrame.none);
    });
  });

  group('vitrin', () {
    final earned = {'first_lesson', 'streak_3', 'perfect', 'reader'};

    test('seçim yoksa kazanılanların en zorları gösterilir', () {
      final shown = const ProfileStyle().showcaseBadges(earned);
      expect(shown.map((b) => b.id), ['reader', 'perfect', 'streak_3']);
    });

    test('yalnızca kazanılmış ve bilinen rozetler gösterilir', () {
      const style = ProfileStyle(
        showcase: ['streak_30', 'perfect', 'yok_boyle_rozet'],
      );
      expect(style.showcaseBadges(earned).map((b) => b.id), ['perfect']);
    });

    test('ekle/çıkar; dolunca en eskisi düşer', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      );
      addTearDown(container.dispose);
      final notifier = container.read(profileStyleProvider.notifier);
      List<String> ids() => [
        for (final b
            in container.read(profileStyleProvider).showcaseBadges(earned))
          b.id,
      ];

      // İlk dokunuş otomatik vitrini kullanıcının listesine çevirir.
      await notifier.toggleShowcase('reader', earned);
      expect(ids(), ['perfect', 'streak_3']);

      await notifier.toggleShowcase('first_lesson', earned);
      await notifier.toggleShowcase('reader', earned);
      expect(ids(), ['streak_3', 'first_lesson', 'reader']);
      expect(prefs.getStringList(ProfileStyle.showcaseKey), ids());
    });
  });

  test('tercihler kaydedilir, bozuk değer varsayılana düşer', () async {
    SharedPreferences.setMockInitialValues({
      ProfileStyle.emojiKey: 'bozuk',
      ProfileStyle.frameKey: 'platin',
    });
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    var style = container.read(profileStyleProvider);
    expect(style.emoji, avatarEmojis.first);
    expect(style.frame, isNull);

    final notifier = container.read(profileStyleProvider.notifier);
    await notifier.setEmoji('🐼');
    await notifier.setColor(2);
    await notifier.setFrame(AvatarFrame.bronze);
    style = container.read(profileStyleProvider);
    expect(style.emoji, '🐼');
    expect(style.color, avatarColors[2]);
    expect(style.frame, AvatarFrame.bronze);
  });

  group('ekran', () {
    late AppDatabase db;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = Repository(db);
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      await repository.replaceWeeklyPlan(DateTime.now(), [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
      ]);
    });
    tearDown(() => db.close());

    Future<SharedPreferences> pumpApp(
      WidgetTester tester, {
      Map<String, Object> prefsValues = const {},
    }) async {
      SharedPreferences.setMockInitialValues(prefsValues);
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

    testWidgets('avatardan profil açılır, avatar değiştirilir', (tester) async {
      final prefs = await pumpApp(tester);
      await tester.tap(find.byType(PlayerAvatar).first);
      await _advance(tester);

      expect(find.text('Efe'), findsOneWidget);
      expect(find.text('Lv 1 · Çaylak'), findsOneWidget);
      expect(find.textContaining('Bronz çerçeve açılır'), findsOneWidget);
      // Rozet yokken vitrin boş yuvalarla gelir.
      expect(find.text('Rozet ekle'), findsNWidgets(showcaseSize));

      await tester.tap(find.byTooltip('Görünümü düzenle'));
      await _advance(tester);
      await tester.tap(find.text('🐼'));
      await _advance(tester);

      expect(prefs.getString(ProfileStyle.emojiKey), '🐼');
      final avatars = tester.widgetList<PlayerAvatar>(
        find.byType(PlayerAvatar),
      );
      expect(avatars.where((a) => a.emoji == '🐼'), isNotEmpty);
    });

    testWidgets('kazanılan rozet vitrinden çıkarılıp geri eklenir', (
      tester,
    ) async {
      // 300 XP = Lv 3 (bronz çerçeve) ve "Hafıza avcısı" rozeti.
      await pumpApp(
        tester,
        prefsValues: {'cards_reviewed_2026-01-05T00:00:00.000': 150},
      );
      await tester.tap(find.byType(PlayerAvatar).first);
      await _advance(tester);

      expect(find.text('Lv 3 · Kaşif'), findsOneWidget);
      expect(find.text('Hafıza avcısı'), findsOneWidget);
      expect(find.text('Rozet ekle'), findsNWidgets(showcaseSize - 1));
      final avatar = tester.widget<PlayerAvatar>(
        find.byType(PlayerAvatar).first,
      );
      expect(avatar.frame, AvatarFrame.bronze);

      await tester.tap(find.text('Hafıza avcısı'));
      await _advance(tester);
      await tester.tap(find.text('Vitrinden çıkar'));
      await _advance(tester);
      await tester.tapAt(const Offset(10, 10));
      await _advance(tester);
      expect(find.text('Rozet ekle'), findsNWidgets(showcaseSize));

      await tester.tap(find.text('Rozet ekle').first);
      await _advance(tester);
      await tester.tap(find.byIcon(Icons.star_outline_rounded));
      await _advance(tester);
      await tester.tapAt(const Offset(10, 10));
      await _advance(tester);
      expect(find.text('Rozet ekle'), findsNWidgets(showcaseSize - 1));
    });
  });

  test('XP hesabı rozet testindeki seviyeyle tutarlı', () {
    // Ekran testi bu varsayıma dayanıyor.
    final game = GameState(const GameStats(cardsReviewed: 150));
    expect(game.level.level, 3);
    expect(game.earnedBadgeIds, contains('cards_50'));
  });
}
