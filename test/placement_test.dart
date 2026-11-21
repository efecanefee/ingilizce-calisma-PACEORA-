import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/answer_option.dart';
import 'package:paceora/app/constants.dart';
import 'package:paceora/data/placement.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/speech_service.dart';
import 'package:paceora/features/placement/placement_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Kademe × beceri başına 3 soruluk yapay havuz (96 soru). Her kademe ve
/// becerinin ilk iki sorusu aynı konuyu paylaşır; konu sınırı denenir.
PlacementBank _bank() => PlacementBank([
  for (final level in DifficultyLevel.values)
    for (final skill in PlacementSkill.values)
      for (var i = 0; i < 3; i++)
        PlacementQuestion(
          prompt: '${level.code} ${skill.name} $i ___',
          options: [
            for (final o in 'abcd'.split(''))
              '${level.code}-${skill.name}-$i-$o',
          ],
          answer: i % 4,
          level: level,
          skill: skill,
          topic: '${level.code}_${skill.name}_${i < 2 ? 0 : i}',
          passage:
              skill == PlacementSkill.reading ||
                  skill == PlacementSkill.listening
              ? 'Passage ${level.code} ${skill.name} $i.'
              : null,
        ),
]);

/// Sesli okuma sahtesi: ses var gibi davranır.
class _FakeSpeech implements SpeechService {
  @override
  Future<bool> speak(String text, {bool slow = false}) async => true;
  @override
  Future<void> stopSpeaking() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Ekranın yapacağı seçimi aynı tohumla tekrarlar.
({List<PlacementQuestion> questions, List<int> answers}) _simulate(
  PlacementBank bank,
  int seed,
  bool Function(PlacementQuestion q, int i) answerRight,
) {
  final draw = PlacementDraw(bank, Random(seed));
  final questions = draw.fixedBlocks();
  final answers = <int>[];
  int pick(PlacementQuestion q, int i) =>
      answerRight(q, i) ? q.answer : (q.answer + 1) % q.options.length;
  for (var i = 0; i < questions.length; i++) {
    answers.add(pick(questions[i], i));
  }
  questions.addAll(draw.finalBlock(questions, answers));
  for (var i = answers.length; i < questions.length; i++) {
    answers.add(pick(questions[i], i));
  }
  return (questions: questions, answers: answers);
}

void main() {
  group('soru seçimi', () {
    test('ilk 16 soru blok düzenine uyar, 1. blok kolaydan zora', () {
      final fixed = PlacementDraw(_bank(), Random(1)).fixedBlocks();
      expect(fixed, hasLength(16));
      expect(placementFixedCount, 16);

      var start = 0;
      for (final block in placementBlocks) {
        final bands = fixed
            .sublist(start, start + block.length)
            .map((q) => q.band)
            .toList();
        expect(
          bands..sort((a, b) => a.index - b.index),
          [...block]..sort((a, b) => a.index - b.index),
        );
        start += block.length;
      }
      expect(
        fixed.take(4).map((q) => q.band),
        placementBlocks.first,
        reason: 'ısınma bloğu sırayla gelir',
      );
    });

    test('20 soruda beceri kotası ve konu sınırı tutar', () {
      for (final seed in [1, 2, 3, 4, 5]) {
        final run = _simulate(_bank(), seed, (q, i) => i.isEven);
        expect(run.questions, hasLength(placementQuestionCount));

        final skills = <PlacementSkill, int>{};
        final topics = <String, int>{};
        for (final q in run.questions) {
          skills.update(q.skill, (n) => n + 1, ifAbsent: () => 1);
          topics.update(q.topic, (n) => n + 1, ifAbsent: () => 1);
        }
        expect(skills, placementSkillQuota, reason: 'tohum $seed');
        expect(topics.values.every((n) => n <= placementTopicCap), isTrue);
        expect(
          run.questions.map((q) => q.prompt).toSet(),
          hasLength(placementQuestionCount),
          reason: 'aynı soru iki kez gelmez',
        );
      }
    });

    test('son bölüm tahmini seviyenin çevresinden seçilir', () {
      // Hepsi doğru → çok zor bant; son bölümde 3 çok zor + 1 zor.
      final strong = _simulate(_bank(), 3, (q, i) => true);
      final strongFinal = strong.questions.skip(16).map((q) => q.band);
      expect(
        strongFinal.where((b) => b == PlacementBand.veryHard),
        hasLength(3),
      );
      expect(strongFinal, contains(PlacementBand.hard));

      // Hepsi yanlış → kolay bant; son bölümde 3 kolay + 1 orta.
      final weak = _simulate(_bank(), 3, (q, i) => false);
      final weakFinal = weak.questions.skip(16).map((q) => q.band);
      expect(weakFinal.where((b) => b == PlacementBand.easy), hasLength(3));
      expect(weakFinal, contains(PlacementBand.medium));
    });

    test('karıştırma doğru cevabı korur', () {
      final bank = _bank();
      for (final q in PlacementDraw(bank, Random(9)).fixedBlocks()) {
        final original = bank.questions.firstWhere((o) => o.prompt == q.prompt);
        expect(q.correctOption, original.correctOption);
      }
    });
  });

  group('puanlama', () {
    test('hepsi doğru C1, hepsi yanlış A2', () {
      final all = _simulate(_bank(), 2, (q, i) => true);
      expect(
        scorePlacement(all.questions, all.answers).level,
        DifficultyLevel.c1,
      );
      final none = _simulate(_bank(), 2, (q, i) => false);
      expect(
        scorePlacement(none.questions, none.answers).level,
        DifficultyLevel.a2,
      );
    });

    test('zor sorular daha çok puan getirir', () {
      final q = [
        PlacementQuestion(
          prompt: 'kolay',
          options: const ['a', 'b'],
          answer: 0,
          level: DifficultyLevel.a2,
        ),
        PlacementQuestion(
          prompt: 'zor',
          options: const ['a', 'b'],
          answer: 0,
          level: DifficultyLevel.c1,
        ),
      ];
      final easyOnly = scorePlacement(q, [0, 1]).percent;
      final hardOnly = scorePlacement(q, [1, 0]).percent;
      expect(hardOnly, greaterThan(easyOnly));
      expect(easyOnly, closeTo(20, 0.01));
      expect(hardOnly, closeTo(80, 0.01));
    });

    test('zor soruların yarısı tutmadan B2 verilmez', () {
      // Kolay ve orta hepsi doğru, zor ve çok zor hepsi yanlış.
      final run = _simulate(
        _bank(),
        4,
        (q, i) =>
            q.band == PlacementBand.easy || q.band == PlacementBand.medium,
      );
      final level = scorePlacement(run.questions, run.answers).level;
      expect(level.index, lessThanOrEqualTo(DifficultyLevel.b1Plus.index));
      expect(level.index, greaterThanOrEqualTo(DifficultyLevel.b1Minus.index));
    });

    test('beceri dökümü toplamla tutarlı', () {
      final run = _simulate(_bank(), 5, (q, i) => i % 3 == 0);
      final r = scorePlacement(run.questions, run.answers);
      expect(r.total, placementQuestionCount);
      expect(r.bySkill.values.fold<int>(0, (s, e) => s + e.$1), r.correct);
      expect(r.bySkill.values.fold<int>(0, (s, e) => s + e.$2), r.total);
    });
  });

  test('bozuk kayıtlar havuza alınmaz', () {
    final bank = PlacementBank.parse([
      '''[
        {"level":"B1","skill":"grammar","topic":"x","prompt":"I ___ it.","options":["a","b","c","d"],"answer":1},
        {"level":"B1","skill":"reading","topic":"y","prompt":"Why?","options":["a","b","c","d"],"answer":0},
        {"level":"B1","skill":"grammar","prompt":"Bad","options":["a","b"],"answer":5}
      ]''',
    ]);
    expect(
      bank.questions,
      hasLength(1),
      reason: 'metinsiz okuma ve hatalı cevap atlanır',
    );
  });

  Future<SharedPreferences> pumpTest(
    WidgetTester tester, {
    SpeechService? speech,
  }) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          placementBankProvider.overrideWith((ref) async => _bank()),
          speechServiceProvider.overrideWithValue(speech ?? _FakeSpeech()),
        ],
        child: MaterialApp(home: PlacementTestScreen(random: Random(7))),
      ),
    );
    await tester.pump();
    return prefs;
  }

  Future<void> answer(
    WidgetTester tester,
    PlacementQuestion q,
    int pick,
  ) async {
    final option = find.widgetWithText(AnswerOption, q.options[pick]);
    await tester.ensureVisible(option);
    await tester.tap(option);
    await tester.pump();
  }

  testWidgets('test çözülünce seviye, beceri dökümü ve yanlışlar gösterilir', (
    tester,
  ) async {
    final prefs = await pumpTest(tester);
    final run = _simulate(_bank(), 7, (q, i) => i < 10);

    for (var i = 0; i < run.questions.length; i++) {
      final q = run.questions[i];
      expect(find.text(q.skill.instruction), findsWidgets);
      if (q.skill == PlacementSkill.listening) {
        expect(find.text('Dinle'), findsOneWidget);
        expect(find.text(q.passage!), findsNothing, reason: 'metin gizli');
      }
      await answer(tester, q, run.answers[i]);
      final picked = tester.widget<AnswerOption>(
        find.widgetWithText(AnswerOption, q.options[run.answers[i]]),
      );
      expect(picked.state, i < 10 ? AnswerState.correct : AnswerState.wrong);
      await tester.pump(const Duration(seconds: 1));
    }
    await tester.pump(const Duration(milliseconds: 400));

    final expected = scorePlacement(run.questions, run.answers);
    expect(find.text('Seviyen: ${expected.level.label}'), findsOneWidget);
    expect(PlacementRecord.read(prefs), expected.level);
    for (final s in PlacementSkill.values) {
      expect(find.text(s.label), findsOneWidget);
    }

    // Sonuç listesi tembel kurulur; kart görünene dek kaydır.
    final list = find.byType(Scrollable).last;
    await tester.scrollUntilVisible(
      find.text('Yanlışlarını gör (10)'),
      200,
      scrollable: list,
    );
    await tester.tap(find.text('Yanlışlarını gör (10)'));
    // Sonuç ekranındaki Pace sürekli hareket eder; sabit süre ilerlet.
    await tester.pump(const Duration(milliseconds: 600));
    await tester.scrollUntilVisible(
      find.text(run.questions.last.prompt),
      200,
      scrollable: list,
    );
    expect(find.text(run.questions.last.prompt), findsOneWidget);
  });

  testWidgets('bitişi bildirmeyen ses motoru düğmeleri kilitlemez', (
    tester,
  ) async {
    await pumpTest(tester, speech: _HangingSpeech());
    final run = _simulate(_bank(), 7, (q, i) => true);
    final first = run.questions.indexWhere(
      (q) => q.skill == PlacementSkill.listening,
    );
    for (var i = 0; i < first; i++) {
      await answer(tester, run.questions[i], run.answers[i]);
      await tester.pump(const Duration(seconds: 1));
    }
    FilledButton listen() => tester.widget<FilledButton>(
      find.ancestor(
        of: find.text('Dinle'),
        matching: find.byType(FilledButton),
      ),
    );
    await tester.tap(find.text('Dinle'));
    await tester.pump();
    expect(listen().onPressed, isNull, reason: 'okunurken kapalı');
    await tester.pump(const Duration(seconds: 10));
    expect(listen().onPressed, isNotNull, reason: 'süre dolunca açılır');
  });
  testWidgets('dinleme metni istenince açılır', (tester) async {
    await pumpTest(tester);
    final run = _simulate(_bank(), 7, (q, i) => true);
    final first = run.questions.indexWhere(
      (q) => q.skill == PlacementSkill.listening,
    );
    for (var i = 0; i < first; i++) {
      await answer(tester, run.questions[i], run.answers[i]);
      await tester.pump(const Duration(seconds: 1));
    }
    final q = run.questions[first];
    expect(find.text(q.passage!), findsNothing);
    await tester.tap(find.text('Ses gelmiyor mu? Metni göster'));
    await tester.pump();
    expect(find.text(q.passage!), findsOneWidget);
  });

  testWidgets('test yarıdayken geri çıkmak onay ister', (tester) async {
    await pumpTest(tester);
    final q = _simulate(_bank(), 7, (q, i) => true).questions.first;
    await answer(tester, q, 0);
    await tester.pump(const Duration(seconds: 1));

    final navigator = tester.state<NavigatorState>(find.byType(Navigator));
    await navigator.maybePop();
    await tester.pumpAndSettle();
    expect(find.text('Testten çıkılsın mı?'), findsOneWidget);
    await tester.tap(find.text('Devam et'));
    await tester.pumpAndSettle();
    expect(find.byType(PlacementTestScreen), findsOneWidget);
  });

  testWidgets('test sekme gezgininin değil kök gezginin üstünde açılır', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final innerKey = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          placementBankProvider.overrideWith((ref) async => _bank()),
        ],
        child: MaterialApp(
          home: Scaffold(
            // Sekmeli kabuk gibi: içerik iç gezginde, alt menü dışarıda.
            body: Navigator(
              key: innerKey,
              onGenerateRoute: (_) => MaterialPageRoute(
                builder: (context) => TextButton(
                  onPressed: () => openPlacementTest(context),
                  child: const Text('Testi çöz'),
                ),
              ),
            ),
            bottomNavigationBar: const SizedBox(height: 80),
          ),
        ),
      ),
    );
    await tester.tap(find.text('Testi çöz'));
    await tester.pumpAndSettle();

    final opened = tester.element(find.byType(PlacementTestScreen));
    expect(Navigator.of(opened), isNot(innerKey.currentState));
    expect(innerKey.currentState!.canPop(), isFalse);
  });

  group('uygulamadaki soru havuzu', () {
    late PlacementBank bank;
    late int rawCount;

    setUpAll(() {
      final sources = [
        for (final path in PlacementBank.assets) File(path).readAsStringSync(),
      ];
      rawCount = sources.fold(
        0,
        (n, s) => n + (jsonDecode(s) as List<dynamic>).length,
      );
      bank = PlacementBank.parse(sources);
    });

    test('her kayıt geçerli, soru + metin tekrarı yok', () {
      expect(bank.questions, hasLength(rawCount), reason: 'atlanan kayıt yok');
      expect(bank.questions.length, greaterThanOrEqualTo(110));
      expect(
        bank.questions.map((q) => '${q.passage}|${q.prompt}').toSet(),
        hasLength(bank.questions.length),
      );
      for (final q in bank.questions) {
        expect(q.options.toSet(), hasLength(4), reason: q.prompt);
        if (q.passage == null) {
          expect('___'.allMatches(q.prompt), hasLength(1), reason: q.prompt);
        }
      }
    });

    test('her kademe ve beceri temsil edilir', () {
      for (final level in DifficultyLevel.values) {
        for (final skill in PlacementSkill.values) {
          expect(
            bank.questions.where((q) => q.level == level && q.skill == skill),
            isNotEmpty,
            reason: '${level.code} ${skill.name}',
          );
        }
      }
    });

    test('geçmiş zaman ağırlığı düşük', () {
      const past = {
        'past_simple',
        'past_continuous',
        'past_perfect',
        'past_perfect_continuous',
        'used_to',
        'would_past',
        'third_conditional',
      };
      final grammar = bank.questions.where(
        (q) => q.skill == PlacementSkill.grammar,
      );
      final pastCount = grammar.where((q) => past.contains(q.topic)).length;
      expect(pastCount / grammar.length, lessThan(0.15));
    });

    test('rastgele işaretleyen çoğunlukla A2, şansla nadiren B1 üstü', () {
      final levels = <DifficultyLevel>[];
      for (var seed = 0; seed < 300; seed++) {
        final luck = Random(seed + 1000);
        final run = _simulate(bank, seed, (q, i) => luck.nextInt(4) == 0);
        levels.add(scorePlacement(run.questions, run.answers).level);
      }
      final a2 = levels.where((l) => l == DifficultyLevel.a2).length;
      expect(a2 / levels.length, greaterThan(0.7));
      // Şansla B1'in üstüne çıkan en fazla %2.
      final lucky = levels.where((l) => l.index > DifficultyLevel.b1.index);
      expect(lucky.length / levels.length, lessThanOrEqualTo(0.02));
    });

    test('200 farklı test hatasız kurulur, kota ve konu sınırı tutar', () {
      for (var seed = 0; seed < 200; seed++) {
        final run = _simulate(bank, seed, (q, i) => (seed + i) % 3 != 0);
        expect(run.questions, hasLength(placementQuestionCount));
        final skills = <PlacementSkill, int>{};
        final topics = <String, int>{};
        for (final q in run.questions) {
          skills.update(q.skill, (n) => n + 1, ifAbsent: () => 1);
          topics.update(q.topic, (n) => n + 1, ifAbsent: () => 1);
        }
        expect(skills, placementSkillQuota, reason: 'tohum $seed');
        expect(
          topics.values.every((n) => n <= placementTopicCap),
          isTrue,
          reason: 'tohum $seed',
        );
      }
    });
  });
}

/// Okumayı başlatıp bitişini hiç bildirmeyen ses motoru.
class _HangingSpeech implements SpeechService {
  @override
  Future<bool> speak(String text, {bool slow = false}) =>
      Completer<bool>().future;
  @override
  Future<void> stopSpeaking() async {}
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
