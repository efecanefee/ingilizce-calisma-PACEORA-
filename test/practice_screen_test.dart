import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:paceora/app/feature_colors.dart';
import 'package:paceora/app/theme.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/features/practice/practice_screen.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scroll_helper.dart';

/// Tekrarlayan animasyonlar yüzünden pumpAndSettle oturmaz; sabit kare.
Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Pratik ekranındaki her öğe ve açtığı rota.
const _routes = {
  'AI ile sohbet': '/roleplay',
  'Kelime Rallisi': '/match',
  'Flash kartlar': '/flashcards',
  'Günün hikayesi': '/story',
  'Konuşma': '/speaking',
  'Dinle ve yaz': '/dictation',
  'Hata defterim': '/mistakes',
  'Haftalık rapor': '/review',
};

void main() {
  late AppDatabase db;
  late Repository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = Repository(db);
  });

  tearDown(() => db.close());

  /// Pratik ekranını, hedef ekranların yerine basit taslaklar koyan bir
  /// yönlendiriciyle açar: dokunuşun doğru rotaya gittiği görülür.
  Future<void> pumpPractice(
    WidgetTester tester, {
    ThemeData? theme,
    bool reduceMotion = false,
  }) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 2.5;
    addTearDown(tester.view.reset);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final router = GoRouter(
      initialLocation: '/practice',
      routes: [
        GoRoute(path: '/practice', builder: (_, _) => const PracticeScreen()),
        for (final path in _routes.values)
          GoRoute(
            path: path,
            builder: (_, _) => Scaffold(body: Text('rota:$path')),
          ),
      ],
    );
    addTearDown(router.dispose);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
        ],
        child: MediaQuery(
          data: MediaQueryData(
            size: const Size(432, 960),
            disableAnimations: reduceMotion,
          ),
          child: MaterialApp.router(
            theme: theme ?? lightTheme,
            routerConfig: router,
          ),
        ),
      ),
    );
    await _advance(tester);
  }

  testWidgets('sekiz pratik öğesi etiketleriyle görünür', (tester) async {
    await pumpPractice(tester);

    expect(find.text('Pratik'), findsOneWidget);
    for (final label in _routes.keys) {
      await scrollIntoView(tester, find.text(label));
      expect(find.text(label), findsOneWidget, reason: label);
    }
    expect(find.text('Ders bitirince dolar'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  for (final MapEntry(key: label, value: path) in _routes.entries) {
    testWidgets('$label kendi rotasını açar', (tester) async {
      await pumpPractice(tester);
      await scrollIntoView(tester, find.text(label));
      await tester.tap(find.text(label));
      await _advance(tester);
      expect(find.text('rota:$path'), findsOneWidget);
    });
  }

  testWidgets('vadesi gelen kart sayısı bölüm renginde rozetle görünür', (
    tester,
  ) async {
    await repository.addFlashcards([
      (word: 'reliable', meaning: 'güvenilir', example: ''),
      (word: 'brave', meaning: 'cesur', example: ''),
    ], source: 'new_word');
    await pumpPractice(tester, theme: darkTheme);

    await scrollIntoView(tester, find.text('2 kart seni bekliyor'));
    expect(find.text('2 kart seni bekliyor'), findsOneWidget);
    final badge = find.text('2');
    expect(badge, findsOneWidget);

    // Rozet zemini genel vurgu değil, Flash kartların kendi rengi.
    final box = tester.widget<Container>(
      find.ancestor(of: badge, matching: find.byType(Container)).first,
    );
    final decoration = box.decoration! as BoxDecoration;
    expect(decoration.color, Feature.flashcards.bright);
  });

  testWidgets('koyu tema ve azaltılmış harekette sorunsuz çizilir', (
    tester,
  ) async {
    await pumpPractice(tester, theme: darkTheme, reduceMotion: true);
    for (final label in _routes.keys) {
      await scrollIntoView(tester, find.text(label));
    }
    expect(tester.takeException(), isNull);
  });

  group('uygulama içinde', () {
    Future<void> pumpApp(WidgetTester tester) async {
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 15);
      await repository.replaceWeeklyPlan(DateTime.now(), [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
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
      await _advance(tester);
    }

    testWidgets('alt çubukta beş sekme var; Pratik ikinci sırada', (
      tester,
    ) async {
      await pumpApp(tester);
      final labels = [
        for (final d in tester.widgetList<NavigationDestination>(
          find.byType(NavigationDestination),
        ))
          d.label,
      ];
      expect(labels, ['Bugün', 'Pratik', 'Program', 'İlerleme', 'Ayarlar']);

      await openPracticeTab(tester);
      expect(find.text('AI ile sohbet'), findsOneWidget);
    });

    testWidgets('ana ekran pratik kutucuklarını ve anahtar kartını taşımaz', (
      tester,
    ) async {
      await pumpApp(tester);
      await tester.drag(find.byType(Scrollable).first, const Offset(0, -3000));
      await _advance(tester);

      expect(find.text('Pratik alanı'), findsNothing);
      expect(find.text('Kelime Rallisi'), findsNothing);
      expect(find.text('Sana özel dersler için anahtar ekle'), findsNothing);

      // Alttaki sade bağlantı Pratik sekmesine geçer.
      await tester.tap(find.text('Pratik alanına git'));
      await _advance(tester);
      expect(find.text('Kelime Rallisi'), findsOneWidget);
      final bar = tester.widget<NavigationBar>(find.byType(NavigationBar));
      expect(bar.selectedIndex, 1);
    });
  });
}
