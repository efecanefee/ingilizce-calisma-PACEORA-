import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/lesson_models.dart';

const _item = TranslateItem(
  tr: 'Her gün trenle işe gidiyorum.',
  en: 'I commute to work by train every day.',
  accepted: ['I go to work by train every day.'],
);

void main() {
  group('normalizeAnswer', () {
    test('küçük harfe indirir ve noktalamayı atar', () {
      expect(normalizeAnswer('  I Commute, Every Day!  '),
          'i commute every day');
    });

    test('kesme işaretini korur ama tekilleştirir', () {
      expect(normalizeAnswer('He’s happy'), "he's happy");
    });

    test('fazla boşlukları teke indirir', () {
      expect(normalizeAnswer('I   go    home'), 'i go home');
    });
  });

  group('canonicalAnswer', () {
    test('kısaltmaları açar', () {
      expect(canonicalAnswer("I'm happy"), 'i am happy');
      expect(canonicalAnswer("They haven't arrived"), 'they have not arrived');
      expect(canonicalAnswer('I cannot swim'), 'i can not swim');
    });

    test('kısaltmasız yazım aynı sonuca varır', () {
      expect(canonicalAnswer("It's cold"), canonicalAnswer('It is cold'));
      expect(canonicalAnswer("won't"), canonicalAnswer('will not'));
    });
  });

  group('TranslateItem.isCorrect', () {
    test('birebir cevabı kabul eder', () {
      expect(_item.isCorrect('I commute to work by train every day.'), isTrue);
    });

    test('büyük/küçük harf ve noktalama farkını yok sayar', () {
      expect(_item.isCorrect('i commute to work by train every day'), isTrue);
      expect(_item.isCorrect('  I COMMUTE to work by train every day!  '),
          isTrue);
    });

    test('modelin bildirdiği varyantı kabul eder', () {
      expect(_item.isCorrect('I go to work by train every day.'), isTrue);
    });

    test('kısaltma farkı yüzünden haksız yere yanlış saymaz', () {
      const item = TranslateItem(
        tr: 'Mutluyum.',
        en: 'I am happy.',
        accepted: [],
      );

      expect(item.isCorrect("I'm happy"), isTrue);
    });

    test('yanlış ve boş cevapları reddeder', () {
      expect(_item.isCorrect('I walk to work every day.'), isFalse);
      expect(_item.isCorrect(''), isFalse);
      expect(_item.isCorrect('   '), isFalse);
    });
  });

  group('GapFillItem / QuizItem', () {
    test('seçenek karşılaştırması büyük/küçük harfe duyarsız', () {
      const item = GapFillItem(
        sentence: 'I ___ tea.',
        answer: 'drink',
        options: ['drink', 'drinks'],
        hintTr: '',
      );

      expect(item.isCorrect('drink'), isTrue);
      expect(item.isCorrect('Drink'), isTrue);
      expect(item.isCorrect('drinks'), isFalse);
    });
  });

  group('LessonState puanlama', () {
    final lesson = DailyLesson(
      vocab: const [],
      gapFill: const [
        GapFillItem(
          sentence: 'I ___ tea.',
          answer: 'drink',
          options: ['drink', 'drinks'],
          hintTr: '',
        ),
      ],
      translate: const [_item],
      quiz: const [
        QuizItem(
          question: 'Which is correct?',
          options: ['He commute', 'He commutes'],
          answer: 'He commutes',
          explanationTr: '',
        ),
      ],
    );

    test('cevaplanmayan soru skoru düşürür', () {
      final state = LessonState(lesson: lesson).copyWith(
        progress: const LessonProgress()
            .withAnswer(gapFillKey(0), correct: true, input: 'drink'),
      );

      expect(state.lesson.questionCount, 3);
      expect(state.answeredCount, 1);
      expect(state.correctCount, 1);
      expect(state.scorePercent, closeTo(33.3, 0.1));
      expect(state.isFinished, isFalse);
    });

    test('hepsi doğruysa %100 ve bitmiş sayılır', () {
      final state = LessonState(lesson: lesson).copyWith(
        progress: const LessonProgress()
            .withAnswer(gapFillKey(0), correct: true, input: 'drink')
            .withAnswer(translateKey(0), correct: true, input: 'x')
            .withAnswer(quizKey(0), correct: true, input: 'He commutes'),
      );

      expect(state.scorePercent, 100);
      expect(state.isFinished, isTrue);
    });

    test('aynı soru iki kez cevaplanmış sayılmaz', () {
      final progress = const LessonProgress()
          .withAnswer(gapFillKey(0), correct: false, input: 'drinks')
          .withAnswer(gapFillKey(0), correct: true, input: 'drink');

      expect(progress.answers, hasLength(1));
    });
  });

  group('LessonState.outcomes', () {
    test('cevaplanan soruları hata defteri biçimine çevirir', () {
      final lesson = DailyLesson(
        vocab: const [],
        gapFill: const [
          GapFillItem(
            sentence: 'I ___ tea.',
            answer: 'drink',
            options: ['drink', 'drinks'],
            hintTr: '',
          ),
        ],
        translate: const [_item],
        quiz: const [
          QuizItem(
            question: 'Which is correct?',
            options: ['He commute', 'He commutes'],
            answer: 'He commutes',
            explanationTr: '',
          ),
        ],
      );

      final state = LessonState(lesson: lesson).copyWith(
        progress: const LessonProgress()
            .withAnswer(gapFillKey(0), correct: false, input: 'drinks')
            .withAnswer(quizKey(0), correct: true, input: 'He commutes'),
      );

      final outcomes = state.outcomes();

      expect(outcomes, hasLength(2), reason: 'çeviri cevaplanmadı');
      expect(outcomes.first.item, 'drink');
      expect(outcomes.first.context, 'I ___ tea.');
      expect(outcomes.first.type, 'vocabulary');
      expect(outcomes.first.correct, isFalse);
      expect(outcomes.last.type, 'grammar');
      expect(outcomes.last.correct, isTrue);
    });
  });
}
