import 'dart:io';
import 'dart:typed_data';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/sounds.dart';
import 'package:paceora/data/lesson_models.dart';
import 'package:paceora/features/lesson/lesson_steps.dart';

class _RecordingPlayer implements SoundPlayer {
  final played = <SoundEffect>[];

  @override
  void play(SoundEffect effect) => played.add(effect);
}

void main() {
  late _RecordingPlayer player;
  setUp(() {
    player = _RecordingPlayer();
    Sounds.player = player;
    Sounds.enabled = true;
  });

  Widget card(ValueChanged<String> onSelected) => MaterialApp(
    home: Scaffold(
      body: ChoiceQuestionCard(
        number: 1,
        prompt: 'She ___ to work.',
        options: const ['walks', 'walk'],
        answer: 'walks',
        given: null,
        onSelected: onSelected,
      ),
    ),
  );

  testWidgets('doğru seçenek doğru, yanlış seçenek yanlış sesini çalar', (
    tester,
  ) async {
    await tester.pumpWidget(card((_) {}));
    await tester.tap(find.text('walks'));
    await tester.tap(find.text('walk'));
    expect(player.played, [SoundEffect.correct, SoundEffect.wrong]);
  });

  testWidgets('çeviri cevabı kabul edilen varyantlarla değerlendirilir', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: TranslateQuestionCard(
            number: 1,
            item: const TranslateItem(
              tr: 'Biz arkadaşız.',
              en: 'We are friends.',
              accepted: ["We're friends."],
            ),
            given: null,
            correct: false,
            onSubmit: (_) {},
          ),
        ),
      ),
    );
    await tester.enterText(find.byType(TextField), "we're friends");
    await tester.testTextInput.receiveAction(TextInputAction.done);
    expect(player.played, [SoundEffect.correct]);
  });

  test('ses efektleri kapalıyken hiçbir şey çalınmaz', () {
    Sounds.enabled = false;
    Sounds.correct();
    Sounds.wrong();
    expect(player.played, isEmpty);
  });

  group('sesler üst üste binmez', () {
    final start = DateTime(2026, 11, 24, 12);
    void at(int ms, void Function() body) =>
        withClock(Clock.fixed(start.add(Duration(milliseconds: ms))), body);

    test('rozet sesi sürerken bitiş ve cevap sesi atlanır', () {
      at(0, Sounds.badge);
      at(200, Sounds.finished);
      at(400, Sounds.correct);
      expect(player.played, [SoundEffect.badge]);
      at(1300, Sounds.finished);
      expect(player.played.last, SoundEffect.finished);
    });

    test('daha önemli ses araya girer', () {
      at(0, Sounds.finished);
      at(100, Sounds.badge);
      at(200, Sounds.levelUp);
      expect(player.played, [
        SoundEffect.finished,
        SoundEffect.badge,
        SoundEffect.levelUp,
      ]);
    });

    test('aynı kutlama sesi baştan başlamaz, cevap sesi başlar', () {
      at(0, Sounds.badge);
      at(100, Sounds.badge);
      expect(player.played, [SoundEffect.badge]);
      at(2000, Sounds.correct);
      at(2100, Sounds.correct);
      expect(player.played.length, 3);
    });

    test('sırası gelen kutlamanın sesi atlanmaz', () {
      at(0, Sounds.levelUp);
      at(300, () => Sounds.play(SoundEffect.badge, force: true));
      expect(player.played, [SoundEffect.levelUp, SoundEffect.badge]);
    });
  });

  test('ses süreleri dosyalarla uyuşur, düzeyler birbirine yakındır', () {
    for (final effect in SoundEffect.values) {
      final bytes = File('assets/${effect.asset}').readAsBytesSync();
      final data = bytes.buffer.asByteData();
      final samples = (bytes.length - 44) ~/ 2;
      var peak = 0;
      for (var i = 0; i < samples; i++) {
        final v = data.getInt16(44 + i * 2, Endian.little).abs();
        if (v > peak) peak = v;
      }
      expect(
        samples * 1000 / 44100,
        closeTo(effect.length.inMilliseconds, 30),
        reason: effect.asset,
      );
      expect(peak / 32768, inInclusiveRange(0.5, 0.95), reason: effect.asset);
    }
  });
}
