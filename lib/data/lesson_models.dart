import 'dart:convert';
import 'dart:math';

import 'gemini_json.dart';

/// Günlük dersin adımları. Boş kalan bölümler akıştan çıkarılır.
enum LessonStepKind {
  vocab('KELİMELER'),
  gapFill('BOŞLUK DOLDUR'),
  translate('ÇEVİRİ'),
  quiz('TEST');

  /// Başlıkta gösterilen etiket.
  ///
  /// Doğrudan büyük harfle yazıldı: Dart'ın `toUpperCase`'i Türkçeye duyarsız
  /// olduğu için "Kelimeler" → "KELIMELER" gibi noktasız I üretiyor.
  const LessonStepKind(this.title);

  final String title;
}

/// Günlük süreye göre ders içeriğinin boyutu.
///
/// Kullanıcı 10 dakika seçtiyse 20 dakikalık ders üretmek programı anlamsız
/// kılar; bu yüzden soru sayısı doğrudan profildeki süreye bağlanır.
class LessonSize {
  const LessonSize({
    required this.vocab,
    required this.gapFill,
    required this.translate,
    required this.quiz,
  });

  final int vocab;
  final int gapFill;
  final int translate;
  final int quiz;

  static LessonSize forMinutes(int minutes) => switch (minutes) {
        <= 10 => const LessonSize(vocab: 5, gapFill: 4, translate: 2, quiz: 4),
        <= 15 => const LessonSize(vocab: 8, gapFill: 5, translate: 3, quiz: 5),
        _ => const LessonSize(vocab: 10, gapFill: 6, translate: 4, quiz: 6),
      };
}

/// Öğretilen kelime/kalıp. Puanlanmaz, ders başında tanıtım için gösterilir.
class VocabItem {
  const VocabItem({
    required this.word,
    required this.meaning,
    required this.example,
  });

  /// İngilizce kelime veya kalıp
  final String word;

  /// Türkçe karşılığı
  final String meaning;

  /// İngilizce örnek cümle
  final String example;

  static VocabItem? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final word = readString(raw, 'word');
    final meaning = readString(raw, 'meaning');
    if (word.isEmpty || meaning.isEmpty) return null;
    return VocabItem(
      word: word,
      meaning: meaning,
      example: readString(raw, 'example'),
    );
  }

  Map<String, dynamic> toJson() =>
      {'word': word, 'meaning': meaning, 'example': example};
}

/// Boşluk doldurma sorusu: cümledeki `___` yerine doğru seçenek bulunur.
class GapFillItem {
  const GapFillItem({
    required this.sentence,
    required this.answer,
    required this.options,
    required this.hintTr,
  });

  /// İçinde `___` geçen İngilizce cümle
  final String sentence;
  final String answer;

  /// Doğru cevabın da içinde olduğu seçenekler (karıştırılmış)
  final List<String> options;

  /// Türkçe ipucu / cümlenin anlamı
  final String hintTr;

  static GapFillItem? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final sentence = readString(raw, 'sentence');
    final answer = readString(raw, 'answer');
    if (sentence.isEmpty || answer.isEmpty) return null;

    final options = readStringList(raw, 'options');
    // Model bazen doğru cevabı seçeneklere koymayı unutuyor; soruyu elemek
    // yerine cevabı listeye ekliyoruz.
    final complete = options.any((o) => o.toLowerCase() == answer.toLowerCase())
        ? options
        : [...options, answer];
    if (complete.length < 2) return null;

    return GapFillItem(
      sentence: sentence,
      answer: answer,
      options: _shuffled(complete, sentence),
      hintTr: readString(raw, 'hintTr'),
    );
  }

  bool isCorrect(String selected) =>
      selected.toLowerCase() == answer.toLowerCase();

  Map<String, dynamic> toJson() => {
        'sentence': sentence,
        'answer': answer,
        'options': options,
        'hintTr': hintTr,
      };
}

/// Türkçeden İngilizceye çeviri sorusu. Serbest metin, cihazda puanlanır.
class TranslateItem {
  const TranslateItem({
    required this.tr,
    required this.en,
    required this.accepted,
  });

  /// Çevrilecek Türkçe cümle
  final String tr;

  /// Beklenen İngilizce karşılık
  final String en;

  /// Modelin bildirdiği, aynı anlama gelen diğer kabul edilebilir çeviriler
  final List<String> accepted;

  static TranslateItem? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final tr = readString(raw, 'tr');
    final en = readString(raw, 'en');
    if (tr.isEmpty || en.isEmpty) return null;
    return TranslateItem(
      tr: tr,
      en: en,
      accepted: readStringList(raw, 'accepted'),
    );
  }

  /// Kullanıcının cevabını beklenen çeviri ve varyantlarıyla karşılaştırır.
  ///
  /// Her cevap için Gemini'ye gitmek gecikme ve kota demek; bunun yerine model
  /// üretim sırasında kabul edilebilir varyantları bildiriyor, karşılaştırma
  /// cihazda yapılıyor. Böylece çevrimdışıyken de çalışır.
  bool isCorrect(String input) {
    final given = canonicalAnswer(input);
    if (given.isEmpty) return false;
    if (canonicalAnswer(en) == given) return true;
    return accepted.any((variant) => canonicalAnswer(variant) == given);
  }

  Map<String, dynamic> toJson() => {'tr': tr, 'en': en, 'accepted': accepted};
}

/// Çoktan seçmeli test sorusu.
class QuizItem {
  const QuizItem({
    required this.question,
    required this.options,
    required this.answer,
    required this.explanationTr,
  });

  final String question;
  final List<String> options;
  final String answer;

  /// Doğru cevabın neden doğru olduğunun Türkçe açıklaması
  final String explanationTr;

  static QuizItem? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final question = readString(raw, 'question');
    final options = readStringList(raw, 'options');
    if (question.isEmpty || options.length < 2) return null;

    final index = raw['answerIndex'];
    if (index is! int || index < 0 || index >= options.length) return null;

    return QuizItem(
      question: question,
      options: _shuffled(options, question),
      answer: options[index],
      explanationTr: readString(raw, 'explanationTr'),
    );
  }

  bool isCorrect(String selected) => selected == answer;

  Map<String, dynamic> toJson() => {
        'question': question,
        'options': options,
        // Karıştırılmış listede doğru cevabın yeri değiştiği için index'i
        // yeniden hesaplayarak yazıyoruz.
        'answerIndex': options.indexOf(answer),
        'explanationTr': explanationTr,
      };
}

/// Bir günlük dersin tamamı.
class DailyLesson {
  const DailyLesson({
    required this.vocab,
    required this.gapFill,
    required this.translate,
    required this.quiz,
  });

  final List<VocabItem> vocab;
  final List<GapFillItem> gapFill;
  final List<TranslateItem> translate;
  final List<QuizItem> quiz;

  /// Puanlanan soru sayısı (kelime tanıtımı puanlanmaz).
  int get questionCount => gapFill.length + translate.length + quiz.length;

  /// Akışta gösterilecek adımlar — boş bölümler atlanır.
  List<LessonStepKind> get steps => [
        if (vocab.isNotEmpty) LessonStepKind.vocab,
        if (gapFill.isNotEmpty) LessonStepKind.gapFill,
        if (translate.isNotEmpty) LessonStepKind.translate,
        if (quiz.isNotEmpty) LessonStepKind.quiz,
      ];

  static DailyLesson? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;

    List<T> items<T extends Object>(String key, T? Function(Object?) parse) {
      final list = raw[key];
      if (list is! List) return <T>[];
      final parsed = <T>[];
      for (final item in list) {
        final value = parse(item);
        // Bozuk öğeler dersin tamamını düşürmesin; sadece o soru elenir.
        if (value != null) parsed.add(value);
      }
      return parsed;
    }

    final lesson = DailyLesson(
      vocab: items('vocab', VocabItem.tryParse),
      gapFill: items('gapFill', GapFillItem.tryParse),
      translate: items('translate', TranslateItem.tryParse),
      quiz: items('quiz', QuizItem.tryParse),
    );

    // Hiç puanlanabilir soru yoksa ders anlamsız — yedeğe düşülsün.
    return lesson.questionCount == 0 ? null : lesson;
  }

  Map<String, dynamic> toJson() => {
        'vocab': [for (final i in vocab) i.toJson()],
        'gapFill': [for (final i in gapFill) i.toJson()],
        'translate': [for (final i in translate) i.toJson()],
        'quiz': [for (final i in quiz) i.toJson()],
      };
}

/// Ders içindeki ilerleme: hangi adımda kalındı, hangi soruya ne cevap verildi.
class LessonProgress {
  const LessonProgress({
    this.stepIndex = 0,
    this.answers = const {},
    this.given = const {},
  });

  /// [DailyLesson.steps] içindeki sıra
  final int stepIndex;

  /// soru anahtarı -> doğru mu
  final Map<String, bool> answers;

  /// soru anahtarı -> kullanıcının verdiği cevap (sonuç ekranında gösterilir)
  final Map<String, String> given;

  bool get isEmpty => stepIndex == 0 && answers.isEmpty;

  LessonProgress copyWith({
    int? stepIndex,
    Map<String, bool>? answers,
    Map<String, String>? given,
  }) =>
      LessonProgress(
        stepIndex: stepIndex ?? this.stepIndex,
        answers: answers ?? this.answers,
        given: given ?? this.given,
      );

  /// Bir soruyu cevaplanmış olarak işaretler.
  LessonProgress withAnswer(String key, {required bool correct, required String input}) =>
      copyWith(
        answers: {...answers, key: correct},
        given: {...given, key: input},
      );

  static LessonProgress fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return const LessonProgress();
    final answers = raw['answers'];
    final given = raw['given'];
    return LessonProgress(
      stepIndex: raw['stepIndex'] is int ? raw['stepIndex'] as int : 0,
      answers: answers is Map
          ? {
              for (final entry in answers.entries)
                if (entry.key is String && entry.value is bool)
                  entry.key as String: entry.value as bool,
            }
          : const {},
      given: given is Map
          ? {
              for (final entry in given.entries)
                if (entry.key is String && entry.value is String)
                  entry.key as String: entry.value as String,
            }
          : const {},
    );
  }

  Map<String, dynamic> toJson() =>
      {'stepIndex': stepIndex, 'answers': answers, 'given': given};
}

/// Bir sorunun sonucu — hata defterine yazılacak biçim.
class AnswerOutcome {
  const AnswerOutcome({
    required this.item,
    required this.context,
    required this.type,
    required this.correct,
  });

  /// Yanlış yapılan kelime/kalıp veya beklenen cevap
  final String item;

  /// Hatanın geçtiği cümle/bağlam
  final String context;

  /// `Mistakes.type` ile aynı sözlük: translation | grammar | vocabulary
  final String type;

  final bool correct;
}

/// Ders içeriği + kullanıcının o ders içindeki ilerlemesi.
///
/// Tamamı `Lessons.contentJson` içine tek JSON olarak yazılır: böylece ders
/// yarıda bırakılıp geri dönüldüğünde kaldığı adımdan devam eder ve bunun için
/// şemaya yeni kolon eklemek gerekmez.
class LessonState {
  const LessonState({required this.lesson, this.progress = const LessonProgress()});

  final DailyLesson lesson;
  final LessonProgress progress;

  LessonState copyWith({DailyLesson? lesson, LessonProgress? progress}) =>
      LessonState(
        lesson: lesson ?? this.lesson,
        progress: progress ?? this.progress,
      );

  int get answeredCount => progress.answers.length;
  int get correctCount => progress.answers.values.where((c) => c).length;
  bool get isFinished => answeredCount >= lesson.questionCount;

  /// 0-100 arası skor. Hiç soru yoksa 0.
  double get scorePercent => lesson.questionCount == 0
      ? 0
      : (correctCount / lesson.questionCount) * 100;

  /// Cevaplanmış soruların hata defteri karşılıkları.
  List<AnswerOutcome> outcomes() {
    final result = <AnswerOutcome>[];

    for (var i = 0; i < lesson.gapFill.length; i++) {
      final correct = progress.answers[gapFillKey(i)];
      if (correct == null) continue;
      final item = lesson.gapFill[i];
      result.add(AnswerOutcome(
        item: item.answer,
        context: item.sentence,
        type: 'vocabulary',
        correct: correct,
      ));
    }

    for (var i = 0; i < lesson.translate.length; i++) {
      final correct = progress.answers[translateKey(i)];
      if (correct == null) continue;
      final item = lesson.translate[i];
      result.add(AnswerOutcome(
        item: item.en,
        context: item.tr,
        type: 'translation',
        correct: correct,
      ));
    }

    for (var i = 0; i < lesson.quiz.length; i++) {
      final correct = progress.answers[quizKey(i)];
      if (correct == null) continue;
      final item = lesson.quiz[i];
      result.add(AnswerOutcome(
        item: item.answer,
        context: item.question,
        type: 'grammar',
        correct: correct,
      ));
    }

    return result;
  }

  String encode() => jsonEncode({
        'lesson': lesson.toJson(),
        'progress': progress.toJson(),
      });

  /// `Lessons.contentJson` içeriğini geri okur; bozuksa null.
  static LessonState? decode(String json) {
    try {
      final raw = jsonDecode(json);
      if (raw is! Map<String, dynamic>) return null;
      final lesson = DailyLesson.tryParse(raw['lesson']);
      if (lesson == null) return null;
      return LessonState(
        lesson: lesson,
        progress: LessonProgress.fromJson(raw['progress']),
      );
    } catch (_) {
      return null;
    }
  }
}

String gapFillKey(int index) => 'gap:$index';
String translateKey(int index) => 'tr:$index';
String quizKey(int index) => 'quiz:$index';

/// Gemini yanıtını [DailyLesson]'a çevirir.
///
/// Yanıt bozuksa ya da hiç puanlanabilir soru çıkmadıysa null döner — çağıran
/// taraf bunu "ders üretilemedi" olarak ele alır, hata fırlatılmaz.
DailyLesson? parseDailyLessonResponse(String responseBody) {
  final text = extractModelText(responseBody);
  if (text == null) return null;
  try {
    return DailyLesson.tryParse(jsonDecode(text));
  } catch (_) {
    return null;
  }
}

/// Serbest metin cevabını karşılaştırmaya hazır hale getirir.
///
/// Küçük harfe indirir, noktalama ve fazla boşlukları atar, kesme işaretini
/// tekilleştirir. "He's happy." ile "hes happy" aynı sayılmasın diye kesme
/// işareti korunur; kısaltmaları [_expandContractions] açar.
String normalizeAnswer(String input) {
  final unified = input.replaceAll('’', "'").toLowerCase().trim();
  final withoutPunctuation = unified.replaceAll(RegExp(r"[^a-z0-9'\s]"), ' ');
  return withoutPunctuation.replaceAll(RegExp(r'\s+'), ' ').trim();
}

/// Normalleştirilmiş cevabı kısaltmaları açılmış nihai biçime getirir.
///
/// "I'm happy" ile "I am happy" aynı cevaptır; model her varyantı `accepted`
/// içinde saymadığında kullanıcıyı boşuna yanlışa düşürmemek için açıyoruz.
String canonicalAnswer(String input) {
  final normalized = normalizeAnswer(input);
  if (normalized.isEmpty) return '';
  return normalized
      .split(' ')
      .map((word) => _contractions[word] ?? word)
      .join(' ');
}

const _contractions = <String, String>{
  "i'm": 'i am',
  "you're": 'you are',
  "we're": 'we are',
  "they're": 'they are',
  "he's": 'he is',
  "she's": 'she is',
  "it's": 'it is',
  "that's": 'that is',
  "there's": 'there is',
  "who's": 'who is',
  "what's": 'what is',
  "i've": 'i have',
  "you've": 'you have',
  "we've": 'we have',
  "they've": 'they have',
  "i'll": 'i will',
  "you'll": 'you will',
  "he'll": 'he will',
  "she'll": 'she will',
  "it'll": 'it will',
  "we'll": 'we will',
  "they'll": 'they will',
  "i'd": 'i would',
  "you'd": 'you would',
  "he'd": 'he would',
  "she'd": 'she would',
  "we'd": 'we would',
  "they'd": 'they would',
  "don't": 'do not',
  "doesn't": 'does not',
  "didn't": 'did not',
  "isn't": 'is not',
  "aren't": 'are not',
  "wasn't": 'was not',
  "weren't": 'were not',
  "haven't": 'have not',
  "hasn't": 'has not',
  "hadn't": 'had not',
  "won't": 'will not',
  "wouldn't": 'would not',
  "can't": 'can not',
  'cannot': 'can not',
  "couldn't": 'could not',
  "shouldn't": 'should not',
  "mustn't": 'must not',
  "let's": 'let us',
};

/// Seçenekleri cümleye bağlı sabit bir tohumla karıştırır.
///
/// Model doğru cevabı çoğu zaman ilk sıraya koyuyor; karıştırmazsak soru
/// kendini ele veriyor. Tohum sabit olduğu için aynı ders yeniden yüklendiğinde
/// seçenek sırası da aynı kalır.
List<String> _shuffled(List<String> options, String seed) {
  final list = [...options];
  list.shuffle(Random(seed.hashCode));
  return list;
}
