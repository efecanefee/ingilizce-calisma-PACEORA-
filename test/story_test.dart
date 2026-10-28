import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/story_models.dart';

String _envelope(Object story) => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': jsonEncode(story)},
        ],
      },
    },
  ],
});

final _story = {
  'title': 'A Rainy Day',
  'paragraphs': ['It was raining.', 'Ali stayed at home and read a book.'],
  'glossary': [
    {'word': 'stay', 'meaning': 'kalmak'},
    {'word': '', 'meaning': 'bozuk'},
  ],
  'questions': [
    {
      'question': 'What was the weather like?',
      'options': ['Sunny', 'Rainy', 'Snowy', 'Windy'],
      'answerIndex': 1,
      'explanationTr': 'İlk cümle yağmur yağdığını söylüyor.',
    },
    {
      'question': 'What did Ali do?',
      'options': ['Read a book', 'Went out', 'Cooked', 'Slept'],
      'answerIndex': 0,
      'explanationTr': 'Evde kalıp kitap okudu.',
    },
    {
      'question': 'Bozuk soru',
      'options': ['A'],
      'answerIndex': 3,
    },
  ],
};

void main() {
  test('hikaye ayrıştırılır, bozuk öğeler elenir', () {
    final story = parseDailyStoryResponse(_envelope(_story))!;
    expect(story.title, 'A Rainy Day');
    expect(story.paragraphs, hasLength(2));
    expect(story.glossary, hasLength(1));
    expect(story.questions, hasLength(2));
    expect(story.questions.first.answer, 'Rainy');
    expect(story.wordCount, 11);
  });

  test('sorusuz ya da başlıksız hikaye reddedilir', () {
    expect(
      parseDailyStoryResponse(_envelope({..._story, 'questions': <Object>[]})),
      isNull,
    );
    expect(
      parseDailyStoryResponse(_envelope({..._story, 'title': ''})),
      isNull,
    );
    expect(parseDailyStoryResponse('{}'), isNull);
  });

  test('puanlama ve kayıt/geri okuma', () {
    final story = parseDailyStoryResponse(_envelope(_story))!;
    var state = StoryState(story: story, offline: true);
    expect(state.isFinished, isFalse);

    state = state.withAnswer(0, 'Rainy').withAnswer(1, 'Slept');
    expect(state.isFinished, isTrue);
    expect(state.correctCount, 1);
    expect(state.scorePercent, 50);

    final restored = StoryState.decode(state.encode())!;
    expect(restored.answers, {0: 'Rainy', 1: 'Slept'});
    expect(restored.offline, isTrue);
    expect(restored.story.questions[0].answer, 'Rainy');
    expect(restored.scorePercent, 50);
  });

  test('bozuk kayıt null döner', () {
    expect(StoryState.decode('bozuk'), isNull);
    expect(StoryState.decode('{"story": {}}'), isNull);
  });

  test('yedek hikayeler seviyeye göre seçilir ve geçerli', () {
    final b1 = fallbackStory('B1-', DateTime(2026, 10, 28));
    final b2 = fallbackStory('B2+', DateTime(2026, 10, 28));
    expect(b1.title, isNot(b2.title));

    for (final level in ['B1', 'B2']) {
      for (var d = 0; d < 7; d++) {
        final story = fallbackStory(level, DateTime(2026, 10, 26 + d));
        expect(story.questions, isNotEmpty);
        for (final q in story.questions) {
          expect(q.options, contains(q.answer));
        }
        // JSON'a yazılıp okunduğunda da sağlam kalmalı.
        expect(
          DailyStory.tryParse(jsonDecode(jsonEncode(story.toJson()))),
          isNotNull,
        );
      }
    }
  });
}
