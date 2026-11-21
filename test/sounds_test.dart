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
}
