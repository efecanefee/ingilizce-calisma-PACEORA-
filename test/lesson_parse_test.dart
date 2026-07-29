import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/lesson_models.dart';

/// Gemini `generateContent` yanıtını taklit eder.
String _response(String modelText) => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': modelText},
            ],
          },
        },
      ],
    });

const _lesson = '''
{
  "vocab": [
    {"word": "commute", "meaning": "işe gidip gelmek", "example": "I commute by train."},
    {"word": "rush hour", "meaning": "trafiğin yoğun olduğu saat", "example": "Avoid rush hour."}
  ],
  "gapFill": [
    {
      "sentence": "I ___ to work every day.",
      "answer": "commute",
      "options": ["commute", "commuted", "commuting", "commutes"],
      "hintTr": "Her gün işe giderim."
    }
  ],
  "translate": [
    {
      "tr": "Her gün trenle işe gidiyorum.",
      "en": "I commute to work by train every day.",
      "accepted": ["I go to work by train every day."]
    }
  ],
  "quiz": [
    {
      "question": "Which sentence is correct?",
      "options": ["He commute", "He commutes", "He commuting", "He to commute"],
      "answerIndex": 1,
      "explanationTr": "Üçüncü tekil şahısta fiile -s eklenir."
    }
  ]
}
''';

void main() {
  group('parseDailyLessonResponse', () {
    test('dört bölümü de okur', () {
      final lesson = parseDailyLessonResponse(_response(_lesson))!;

      expect(lesson.vocab, hasLength(2));
      expect(lesson.gapFill, hasLength(1));
      expect(lesson.translate, hasLength(1));
      expect(lesson.quiz, hasLength(1));

      expect(lesson.vocab.first.word, 'commute');
      expect(lesson.vocab.first.meaning, 'işe gidip gelmek');
      expect(lesson.gapFill.first.answer, 'commute');
      expect(lesson.translate.first.tr, 'Her gün trenle işe gidiyorum.');
    });

    test('puanlanan soru sayısı kelimeleri saymaz', () {
      final lesson = parseDailyLessonResponse(_response(_lesson))!;

      expect(lesson.questionCount, 3);
      expect(lesson.steps, [
        LessonStepKind.vocab,
        LessonStepKind.gapFill,
        LessonStepKind.translate,
        LessonStepKind.quiz,
      ]);
    });

    test('```json bloğuna sarılmış yanıtı da okur', () {
      final lesson = parseDailyLessonResponse(_response('```json\n$_lesson\n```'));

      expect(lesson, isNotNull);
      expect(lesson!.questionCount, 3);
    });

    test('seçenekler karıştırılır ama doğru cevap korunur', () {
      final lesson = parseDailyLessonResponse(_response(_lesson))!;

      expect(lesson.quiz.first.answer, 'He commutes');
      expect(lesson.quiz.first.options, hasLength(4));
      expect(lesson.quiz.first.options, contains('He commutes'));
      expect(lesson.gapFill.first.options, contains('commute'));
    });

    test('doğru cevap seçeneklerde yoksa listeye eklenir', () {
      final lesson = parseDailyLessonResponse(_response('''
{
  "vocab": [],
  "gapFill": [
    {
      "sentence": "She ___ tea.",
      "answer": "drinks",
      "options": ["drink", "drinking", "drank"],
      "hintTr": "O çay içer."
    }
  ],
  "translate": [],
  "quiz": []
}
'''))!;

      expect(lesson.gapFill.first.options, contains('drinks'));
      expect(lesson.gapFill.first.options, hasLength(4));
    });

    test('bozuk öğeler elenir, ders ayakta kalır', () {
      final lesson = parseDailyLessonResponse(_response('''
{
  "vocab": [{"word": "", "meaning": "boş"}],
  "gapFill": [
    {"sentence": "I ___ it.", "answer": "did", "options": ["did", "done"], "hintTr": ""},
    {"sentence": "eksik cevap"}
  ],
  "translate": [{"tr": "sadece türkçe"}],
  "quiz": [
    {"question": "S", "options": ["a", "b"], "answerIndex": 7, "explanationTr": ""}
  ]
}
'''))!;

      expect(lesson.vocab, isEmpty, reason: 'boş kelime elenmeli');
      expect(lesson.gapFill, hasLength(1));
      expect(lesson.translate, isEmpty, reason: 'en alanı yok');
      expect(lesson.quiz, isEmpty, reason: 'answerIndex sınır dışı');
      expect(lesson.questionCount, 1);
    });

    test('hiç puanlanabilir soru yoksa null döner', () {
      expect(
        parseDailyLessonResponse(_response(
          '{"vocab": [{"word": "a", "meaning": "b", "example": "c"}], '
          '"gapFill": [], "translate": [], "quiz": []}',
        )),
        isNull,
      );
    });

    test('bozuk yanıtlarda null döner, hata fırlatmaz', () {
      expect(parseDailyLessonResponse('bu JSON değil'), isNull);
      expect(parseDailyLessonResponse('{}'), isNull);
      expect(parseDailyLessonResponse(_response('yine JSON değil')), isNull);
      expect(parseDailyLessonResponse(jsonEncode({'candidates': []})), isNull);
    });
  });

  group('LessonState kodlama', () {
    test('ders ve ilerleme kaydedilip geri okunur', () {
      final lesson = parseDailyLessonResponse(_response(_lesson))!;
      final state = LessonState(lesson: lesson).copyWith(
        progress: const LessonProgress(stepIndex: 2)
            .withAnswer(gapFillKey(0), correct: true, input: 'commute')
            .withAnswer(quizKey(0), correct: false, input: 'He commute'),
      );

      final restored = LessonState.decode(state.encode())!;

      expect(restored.progress.stepIndex, 2);
      expect(restored.progress.answers[gapFillKey(0)], isTrue);
      expect(restored.progress.answers[quizKey(0)], isFalse);
      expect(restored.progress.given[quizKey(0)], 'He commute');
      expect(restored.lesson.quiz.first.answer, 'He commutes');
      expect(restored.answeredCount, 2);
    });

    test('bozuk kayıt null döner', () {
      expect(LessonState.decode('{}'), isNull);
      expect(LessonState.decode('bu JSON değil'), isNull);
    });
  });

  group('LessonSize', () {
    test('günlük süreye göre ölçeklenir', () {
      expect(LessonSize.forMinutes(10).vocab, 5);
      expect(LessonSize.forMinutes(15).vocab, 8);
      expect(LessonSize.forMinutes(20).vocab, 10);
      expect(LessonSize.forMinutes(5).gapFill, 4, reason: 'alt sınıra düşer');
      expect(LessonSize.forMinutes(60).quiz, 6, reason: 'üst sınıra düşer');
    });
  });
}
