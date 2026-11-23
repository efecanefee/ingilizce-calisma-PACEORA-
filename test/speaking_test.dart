import 'dart:math';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/speak_button.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/pronunciation.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/data/rewards.dart';
import 'package:paceora/data/speech_service.dart';
import 'package:paceora/data/word_lookup.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scroll_helper.dart';

/// Cihaz servisleri yerine: okunanları kaydeder, söylenecek metni verir.
class FakeSpeech implements SpeechService {
  final spoken = <String>[];
  bool available = true;

  /// Sıradaki dinlemede "duyulacak" metin; null ise hiç ses gelmez.
  String? nextHeard;

  /// Cihazda İngilizce ses var mı.
  bool canSpeak = true;

  @override
  Future<bool> speak(String text, {bool slow = false}) async {
    spoken.add(text);
    return canSpeak;
  }

  @override
  Future<void> stopSpeaking() async {}

  @override
  Future<bool> initRecognition() async => available;

  @override
  Future<void> listen(
    void Function(String words, bool isFinal) onResult, {
    void Function()? onDone,
  }) async {
    final heard = nextHeard;
    if (heard == null) {
      onDone?.call();
      return;
    }
    onResult(heard, true);
  }

  @override
  Future<void> stopListening() async {}
}

Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('scoreSentence', () {
    test('noktalama ve büyük harf önemsenmez', () {
      final s = scoreSentence(
        'Ali lost his key in the park.',
        'ali lost his key in the park',
      );
      expect(s.percent, 100);
      expect(s.passed, isTrue);
      expect(s.words.last.word, 'park.');
    });

    test('eksik ve yanlış kelimeler işaretlenir', () {
      final s = scoreSentence(
        'She has lived in Istanbul for five years.',
        'she lived in istanbul for nine years',
      );
      expect(
        [
          for (final w in s.words)
            if (!w.ok) w.word,
        ],
        ['has', 'five'],
      );
      expect(s.correct, 6);
      expect(s.percent, 75);
      expect(s.passed, isFalse);
    });

    test('kısaltmalar açık hâliyle de doğru sayılır', () {
      expect(
        scoreSentence("I don't like it.", 'I do not like it').percent,
        100,
      );
      expect(
        scoreSentence('I do not like it.', "I don't like it").percent,
        100,
      );
      // Kısaltmanın yarısı söylendiyse kelime yanlış.
      final half = scoreSentence("I don't like it.", 'I do like it');
      expect(half.words[1].ok, isFalse);
    });

    test('sıra korunur; fazladan kelimeler cezalandırılmaz', () {
      final s = scoreSentence(
        'We are going home.',
        'um we are uh going home now',
      );
      expect(s.percent, 100);
      final swapped = scoreSentence('one two three', 'three two one');
      expect(swapped.correct, 1);
    });

    test('boş cevap sıfır', () {
      expect(scoreSentence('Hello there.', '').percent, 0);
      expect(scoreSentence('', 'anything').percent, 0);
    });
  });

  test('zorlanılan kelimeler: yanlışta artar, doğruda azalıp düşer', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await HardWords.record(
      prefs,
      scoreSentence(
        'I thought about the weather.',
        'I taught about the wetter',
      ),
    );
    await HardWords.record(
      prefs,
      scoreSentence('The weather is nice.', 'the wetter is nice'),
    );
    var hard = HardWords.read(prefs);
    expect(hard.top().first, 'weather');
    expect(hard.counts['weather'], 2);
    expect(hard.counts.containsKey('thought'), isTrue);
    // Tek harfli kelimeler sayılmaz.
    expect(hard.counts.containsKey('i'), isFalse);

    await HardWords.record(
      prefs,
      scoreSentence('I thought so.', 'I thought so'),
    );
    hard = HardWords.read(prefs);
    expect(hard.counts.containsKey('thought'), isFalse);
    expect(hard.counts['weather'], 2);
  });

  test('cümle seçimi: uzunluk süzgeci ve tekrar yok', () {
    final picked = pickPracticeSentences([
      'Too short.',
      'This sentence has exactly enough words.',
      'this sentence has exactly enough words.',
      'Another good sentence for practice today.',
      List.filled(20, 'word').join(' '),
    ], random: Random(1));
    expect(picked, hasLength(2));
  });

  test('splitSentences', () {
    expect(splitSentences('Hi there. How are you? "Fine!" he said.'), [
      'Hi there.',
      'How are you?',
      '"Fine!"',
      'he said.',
    ]);
  });

  test('kayıtlar XP ve rozete yansır', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    for (var i = 0; i < 25; i++) {
      await SpeechRecords.addGood(prefs, spoken: true);
    }
    await SpeechRecords.addGood(prefs, spoken: false);
    final r = SpeechRecords.read(prefs);
    expect(r.spokenGood, 25);
    expect(r.dictationGood, 1);
    expect(r.xp, 26 * xpPerGoodSentence);

    final game = GameState(GameStats(speechXp: r.xp, spokenGood: r.spokenGood));
    expect(totalXp(game.stats), 78);
    expect(game.earnedBadgeIds, contains('speaker_25'));
  });

  group('ekran', () {
    late AppDatabase db;
    late FakeSpeech speech;
    const sentence = 'I usually drink a cup of tea every morning.';

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = Repository(db);
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      await repository.replaceWeeklyPlan(DateTime.now(), [
        for (var i = 0; i < 7; i++)
          PlanDaySpec(grammarTopic: 'Konu $i', vocabTheme: 'Tema $i'),
      ]);
      speech = FakeSpeech();
    });
    tearDown(() => db.close());

    Future<SharedPreferences> openPractice(
      WidgetTester tester,
      String tile,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
            speechServiceProvider.overrideWithValue(speech),
            // Tek, bilinen cümle: puanlama tahmin edilebilsin.
            practiceSentencesProvider.overrideWith((ref) async => [sentence]),
          ],
          child: const PaceoraApp(onboardingDone: true),
        ),
      );
      await _advance(tester);
      await openPracticeTab(tester);
      await tester.scrollUntilVisible(
        find.text(tile),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      await _advance(tester);
      await tester.tap(find.text(tile));
      await _advance(tester);
      return prefs;
    }

    testWidgets('konuşma: doğru söylenen cümle XP kazandırır', (tester) async {
      final prefs = await openPractice(tester, 'Konuşma');
      expect(find.text(sentence), findsOneWidget);

      await tester.tap(find.text('Dinle'));
      await tester.pump();
      expect(speech.spoken, [sentence]);

      speech.nextHeard = 'I usually drink a cup of tea every morning';
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await _advance(tester);

      expect(find.text('%100'), findsOneWidget);
      expect(find.text('Kusursuz!'), findsOneWidget);
      expect(prefs.getInt(SpeechRecords.spokenKey), 1);

      // Aynı cümleyi tekrar başarmak ikinci kez XP vermez.
      await tester.tap(find.text('Tekrar dene'));
      await _advance(tester);
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await _advance(tester);
      expect(prefs.getInt(SpeechRecords.spokenKey), 1);

      await tester.tap(find.text('Bitir'));
      await _advance(tester);
      expect(find.text('1/1 cümle başarılı'), findsOneWidget);
      expect(find.text('+$xpPerGoodSentence XP'), findsOneWidget);
    });

    testWidgets('İngilizce ses yoksa bir kez nasıl yükleneceği anlatılır', (
      tester,
    ) async {
      resetMissingVoiceNotice();
      speech.canSpeak = false;
      await openPractice(tester, 'Konuşma');

      await tester.tap(find.text('Dinle'));
      await tester.pump();
      expect(find.textContaining('İngilizce ses yok'), findsOneWidget);

      // Mesaj kaybolduktan sonra ikinci dokunuşta tekrar çıkmaz.
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(seconds: 1));
      }
      await _advance(tester);
      expect(find.textContaining('İngilizce ses yok'), findsNothing);
      await tester.tap(find.text('Dinle'));
      await tester.pump();
      expect(find.textContaining('İngilizce ses yok'), findsNothing);
      expect(speech.spoken, [sentence, sentence]);
    });

    testWidgets('konuşma: ses gelmezse uyarı, tanıma yoksa hata', (
      tester,
    ) async {
      await openPractice(tester, 'Konuşma');
      speech.nextHeard = null;
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await _advance(tester);
      expect(find.textContaining('Ses duyulmadı'), findsOneWidget);

      speech.available = false;
      await tester.tap(find.byIcon(Icons.mic_rounded));
      await _advance(tester);
      expect(
        find.textContaining('Konuşma tanıma kullanılamıyor'),
        findsOneWidget,
      );
      expect(find.text('Bu cümleyi atla'), findsOneWidget);
    });

    testWidgets('dinle-yaz: cümle okunur, yazılan puanlanır', (tester) async {
      final prefs = await openPractice(tester, 'Dinle ve yaz');
      // Açılınca cümle kendiliğinden okunur ve gizli kalır.
      expect(speech.spoken, [sentence]);
      expect(find.text(sentence), findsNothing);

      await tester.enterText(
        find.byType(TextField),
        'I usually drink a cup of coffee every morning',
      );
      await tester.pump();
      await tester.tap(find.text('Kontrol et'));
      await _advance(tester);

      // 9 kelimeden 8'i doğru: %89, geçer.
      expect(find.text('%89'), findsOneWidget);
      expect(prefs.getInt(SpeechRecords.dictationKey), 1);
      expect(
        find.textContaining('Yazdığın: I usually drink a cup of coffee'),
        findsOneWidget,
      );
    });
  });
}
