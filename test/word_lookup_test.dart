import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paceora/data/gemini_service.dart';
import 'package:paceora/data/lesson_models.dart';
import 'package:paceora/data/story_models.dart';
import 'package:paceora/data/word_lookup.dart';

String _content(Object json) => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': jsonEncode(json)},
        ],
      },
    },
  ],
});

String _modelList(List<String> names) => jsonEncode({
  'models': [
    for (final n in names)
      {
        'name': 'models/$n',
        'supportedGenerationMethods': ['generateContent'],
      },
  ],
});

void main() {
  group('tokenizeParagraph', () {
    test('kelimeleri ve ara metni ayırır, birleşince paragraf çıkar', () {
      const text = 'Mia didn’t stop. "I missed it," she said!';
      final tokens = tokenizeParagraph(text);

      expect(tokens.map((t) => t.text).join(), text);
      expect(
        [
          for (final t in tokens)
            if (t.isWord) t.text,
        ],
        ['Mia', 'didn’t', 'stop', 'I', 'missed', 'it', 'she', 'said'],
      );
      final missed = tokens.firstWhere((t) => t.text == 'missed');
      expect(text.substring(missed.start, missed.start + 6), 'missed');
    });

    test('noktalamayla başlayan ve biten metin', () {
      final tokens = tokenizeParagraph('“Hello.”');
      expect(tokens.map((t) => t.isWord), [false, true, false]);
    });
  });

  test('sentenceAt kelimenin geçtiği cümleyi verir', () {
    const text = 'Ali woke up early. He lost his key! Then he went home.';
    expect(sentenceAt(text, text.indexOf('lost')), 'He lost his key!');
    expect(sentenceAt(text, 0), 'Ali woke up early.');
    expect(sentenceAt(text, text.indexOf('home')), 'Then he went home.');
  });

  group('glossaryMatch', () {
    const glossary = [
      GlossaryItem(word: 'decide', meaning: 'karar vermek'),
      GlossaryItem(word: 'stop', meaning: 'durmak'),
      GlossaryItem(word: 'city', meaning: 'şehir'),
      GlossaryItem(word: 'Queue', meaning: 'kuyruk'),
    ];

    test('çekimli biçimleri sözlükçeyle eşleştirir', () {
      expect(glossaryMatch(glossary, 'decided')?.meaning, 'karar vermek');
      expect(glossaryMatch(glossary, 'deciding')?.meaning, 'karar vermek');
      expect(glossaryMatch(glossary, 'stopped')?.meaning, 'durmak');
      expect(glossaryMatch(glossary, 'cities')?.meaning, 'şehir');
      expect(glossaryMatch(glossary, 'queue')?.meaning, 'kuyruk');
      expect(glossaryMatch(glossary, 'Decide')?.meaning, 'karar vermek');
    });

    test('ilgisiz kelime eşleşmez', () {
      expect(glossaryMatch(glossary, 'station'), isNull);
      expect(glossaryMatch(glossary, 'sto'), isNull);
    });
  });

  test('parseWordMeaningResponse bozuk yanıtı reddeder', () {
    final ok = parseWordMeaningResponse(
      _content({
        'word': 'lose',
        'meaning': 'kaybetmek',
        'partOfSpeech': 'fiil',
      }),
    )!;
    expect(ok.word, 'lose');
    expect(ok.partOfSpeech, 'fiil');
    expect(parseWordMeaningResponse(_content({'word': 'lose'})), isNull);
    expect(parseWordMeaningResponse('{}'), isNull);
  });

  test('çeviri önbelleği hikayeyle kaydedilir ve cevaplarla korunur', () {
    const story = DailyStory(
      title: 'T',
      paragraphs: ['Ali lost his key.'],
      glossary: [],
      questions: [
        QuizItem(
          question: 'Q?',
          options: ['A', 'B'],
          answer: 'A',
          explanationTr: '',
        ),
      ],
    );
    final state = const StoryState(story: story)
        .withLookup(
          'Lost',
          const WordMeaning(word: 'lose', meaning: 'kaybetmek'),
        )
        .withAnswer(0, 'A');
    expect(state.lookups.keys, ['lost']);

    final restored = StoryState.decode(state.encode())!;
    expect(restored.lookups['lost']?.meaning, 'kaybetmek');
    expect(restored.answers, {0: 'A'});

    // Eski kayıtlarda alan yok: boş önbellekle açılır.
    final legacy = jsonDecode(state.encode()) as Map<String, dynamic>
      ..remove('lookups');
    expect(StoryState.decode(jsonEncode(legacy))!.lookups, isEmpty);
  });

  group('GeminiService.translateWord', () {
    test('kelime ve cümleyi gönderir, anlamı döner', () async {
      String? prompt;
      final service = GeminiService(
        apiKey: 'k',
        retryDelay: Duration.zero,
        client: MockClient((r) async {
          if (r.method == 'GET') {
            return http.Response(_modelList(['gemini-3.5-flash-lite']), 200);
          }
          final body = jsonDecode(r.body) as Map<String, dynamic>;
          prompt =
              (((body['contents'] as List).first as Map)['parts'] as List)
                      .cast<Map<String, dynamic>>()
                      .first['text']
                  as String;
          return http.Response.bytes(
            utf8.encode(
              _content({
                'word': 'lose',
                'meaning': 'kaybetmek',
                'partOfSpeech': 'fiil',
              }),
            ),
            200,
          );
        }),
      );
      addTearDown(service.dispose);

      final result = await service.translateWord(
        word: 'lost',
        sentence: 'Ali lost his key.',
        level: 'B1',
      );
      expect(result.error, isNull);
      expect(result.meaning?.meaning, 'kaybetmek');
      expect(prompt, contains('Kelime: lost'));
      expect(prompt, contains('Ali lost his key.'));
    });

    test('anahtar yoksa hata döner, fırlatmaz', () async {
      final service = GeminiService();
      addTearDown(service.dispose);
      final result = await service.translateWord(
        word: 'lost',
        sentence: 'Ali lost his key.',
        level: 'B1',
      );
      expect(result.meaning, isNull);
      expect(result.error, contains('GEMINI_API_KEY'));
    });
  });
}
