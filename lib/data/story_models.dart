import 'dart:convert';

import 'gemini_json.dart';
import 'lesson_models.dart';

/// Hikayede geçen ve öğrenciye açıklanan kelime.
class GlossaryItem {
  const GlossaryItem({required this.word, required this.meaning});

  final String word;

  /// Türkçe karşılığı
  final String meaning;

  static GlossaryItem? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final word = readString(raw, 'word');
    final meaning = readString(raw, 'meaning');
    if (word.isEmpty || meaning.isEmpty) return null;
    return GlossaryItem(word: word, meaning: meaning);
  }

  Map<String, dynamic> toJson() => {'word': word, 'meaning': meaning};
}

/// Günün hikayesi: kısa bir okuma parçası ve okuduğunu anlama soruları.
class DailyStory {
  const DailyStory({
    required this.title,
    required this.paragraphs,
    required this.glossary,
    required this.questions,
  });

  final String title;
  final List<String> paragraphs;
  final List<GlossaryItem> glossary;

  /// Soru biçimi dersteki testle aynı; puanlama da aynı sınıfla yapılır.
  final List<QuizItem> questions;

  int get wordCount => paragraphs
      .expand((p) => p.split(RegExp(r'\s+')))
      .where((w) => w.isNotEmpty)
      .length;

  static DailyStory? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final title = readString(raw, 'title');
    final paragraphs = readStringList(raw, 'paragraphs');
    if (title.isEmpty || paragraphs.isEmpty) return null;

    List<T> items<T extends Object>(String key, T? Function(Object?) parse) {
      final list = raw[key];
      if (list is! List) return <T>[];
      return [
        for (final item in list)
          if (parse(item) case final T value) value,
      ];
    }

    final questions = items('questions', QuizItem.tryParse);
    // Sorusuz hikaye "okuduğunu anlama" değil; yedeğe düşülsün.
    if (questions.isEmpty) return null;

    return DailyStory(
      title: title,
      paragraphs: paragraphs,
      glossary: items('glossary', GlossaryItem.tryParse),
      questions: questions,
    );
  }

  Map<String, dynamic> toJson() => {
        'title': title,
        'paragraphs': paragraphs,
        'glossary': [for (final g in glossary) g.toJson()],
        'questions': [for (final q in questions) q.toJson()],
      };
}

/// Hikaye + okuyucunun soru cevapları.
///
/// `Stories.contentJson` içine tek JSON olarak yazılır; yarıda bırakılan test
/// kaldığı sorudan devam eder.
class StoryState {
  const StoryState({
    required this.story,
    this.answers = const {},
    this.offline = false,
  });

  final DailyStory story;

  /// soru sırası -> seçilen seçenek
  final Map<int, String> answers;

  /// true ise hikaye Gemini'den değil yerleşik yedekten geldi.
  final bool offline;

  int get correctCount => [
        for (final entry in answers.entries)
          if (entry.key < story.questions.length &&
              story.questions[entry.key].isCorrect(entry.value))
            entry.key,
      ].length;

  bool get isFinished => answers.length >= story.questions.length;

  double get scorePercent => story.questions.isEmpty
      ? 0
      : correctCount / story.questions.length * 100;

  StoryState withAnswer(int index, String option) => StoryState(
        story: story,
        answers: {...answers, index: option},
        offline: offline,
      );

  String encode() => jsonEncode({
        'story': story.toJson(),
        'answers': {
          for (final entry in answers.entries) '${entry.key}': entry.value,
        },
        'offline': offline,
      });

  static StoryState? decode(String json) {
    try {
      final raw = jsonDecode(json);
      if (raw is! Map<String, dynamic>) return null;
      final story = DailyStory.tryParse(raw['story']);
      if (story == null) return null;
      final answers = raw['answers'];
      return StoryState(
        story: story,
        answers: answers is Map
            ? {
                for (final entry in answers.entries)
                  if (int.tryParse('${entry.key}') case final int index
                      when entry.value is String)
                    index: entry.value as String,
              }
            : const {},
        offline: raw['offline'] == true,
      );
    } catch (_) {
      return null;
    }
  }
}

/// Gemini yanıtını [DailyStory]'ye çevirir; bozuksa null.
DailyStory? parseDailyStoryResponse(String responseBody) {
  final text = extractModelText(responseBody);
  if (text == null) return null;
  try {
    return DailyStory.tryParse(jsonDecode(text));
  } catch (_) {
    return null;
  }
}

/// API anahtarı yokken ya da Gemini'ye ulaşılamadığında gösterilen hikaye.
///
/// Haftanın gününe göre iki hikaye arasında dönülür; böylece çevrimdışı
/// kullanıcı her gün aynı metni görmez.
DailyStory fallbackStory(String levelCode, DateTime date) {
  final pool = levelCode.startsWith('B2') ? _fallbackB2 : _fallbackB1;
  return pool[date.weekday % pool.length];
}

final _fallbackB1 = <DailyStory>[
  DailyStory(
    title: 'The Last Train',
    paragraphs: const [
      'Mia works in a busy office in the city centre. Every evening she takes '
          'the train home, and she usually reads a book during the journey.',
      'Last Friday she stayed late because her manager needed a report. When '
          'she finally arrived at the station, the last train was already '
          'leaving the platform. She ran, but the doors closed in front of her.',
      'At first she felt angry, but then an old man sitting on a bench smiled '
          'at her. "I missed it too," he said. They started talking, and he '
          'told her he had worked on the railway for forty years.',
      'They shared a taxi in the end. Mia got home very late, but she said it '
          'was the most interesting evening she had had in months.',
    ],
    glossary: const [
      GlossaryItem(word: 'journey', meaning: 'yolculuk'),
      GlossaryItem(word: 'platform', meaning: 'peron'),
      GlossaryItem(word: 'bench', meaning: 'bank'),
      GlossaryItem(word: 'in the end', meaning: 'sonunda'),
    ],
    questions: [
      _q('Why did Mia stay late on Friday?', [
        'Her manager needed a report.',
        'She wanted to read her book.',
        'Her train was cancelled.',
        'She was waiting for a friend.',
      ], 0, 'Metinde müdürünün bir rapora ihtiyacı olduğu için geç kaldığı yazıyor.'),
      _q('What happened when she arrived at the station?', [
        'She caught the last train.',
        'The last train was leaving.',
        'The station was closed.',
        'She met her manager.',
      ], 1, 'Son tren perondan ayrılıyordu ve kapılar önünde kapandı.'),
      _q('Who did Mia talk to?', [
        'A taxi driver',
        'Her manager',
        'An old man who had worked on the railway',
        'A student on the bench',
      ], 2, 'Bankta oturan, demiryolunda kırk yıl çalışmış yaşlı bir adamla konuştu.'),
      _q('How did Mia feel about the evening at the end?', [
        'It was boring.',
        'It was the worst night of her life.',
        'It was very interesting.',
        'It was too expensive.',
      ], 2, 'Aylardır geçirdiği en ilginç akşam olduğunu söyledi.'),
    ],
  ),
  DailyStory(
    title: 'A New Hobby',
    paragraphs: const [
      'Can has always wanted to learn how to cook, but he was too busy at work. '
          'This year he decided to change that and joined a cooking class on '
          'Saturday mornings.',
      'On the first day, the teacher asked everyone to make a simple soup. Can '
          'forgot to add salt, and his soup tasted terrible. Everyone laughed, '
          'including Can.',
      'Since then he has practised every weekend. He now cooks dinner for his '
          'family twice a week, and his younger sister says his pasta is better '
          'than the one at their favourite restaurant.',
    ],
    glossary: const [
      GlossaryItem(word: 'decide', meaning: 'karar vermek'),
      GlossaryItem(word: 'taste', meaning: 'tadı olmak'),
      GlossaryItem(word: 'practise', meaning: 'pratik yapmak'),
    ],
    questions: [
      _q('Why didn’t Can learn to cook before?', [
        'He didn’t like food.',
        'He was too busy at work.',
        'He had no kitchen.',
        'His family cooked for him.',
      ], 1, 'İşte çok meşgul olduğu için daha önce öğrenemedi.'),
      _q('What was wrong with his first soup?', [
        'It was too hot.',
        'It had too much salt.',
        'He forgot the salt.',
        'It was cold.',
      ], 2, 'Tuz eklemeyi unuttuğu için çorbanın tadı kötüydü.'),
      _q('How often does Can cook for his family now?', [
        'Every day',
        'Twice a week',
        'Once a month',
        'Only on Saturdays',
      ], 1, 'Artık haftada iki kez ailesine akşam yemeği yapıyor.'),
    ],
  ),
];

final _fallbackB2 = <DailyStory>[
  DailyStory(
    title: 'The Remote Office',
    paragraphs: const [
      'When Selin’s company announced that employees could work from anywhere, '
          'she moved to a small coastal town she had visited as a child. She '
          'had imagined long walks by the sea and a calmer, more productive life.',
      'For the first few weeks, everything went according to plan. However, '
          'she gradually realised that she missed the spontaneous conversations '
          'with colleagues, which had often led to her best ideas.',
      'Rather than returning to the city, she started organising monthly '
          'meetups with other remote workers in the town. What began as a '
          'handful of people in a café has since grown into a community of '
          'more than fifty members.',
    ],
    glossary: const [
      GlossaryItem(word: 'coastal', meaning: 'kıyı'),
      GlossaryItem(word: 'spontaneous', meaning: 'kendiliğinden, plansız'),
      GlossaryItem(word: 'a handful of', meaning: 'bir avuç, birkaç'),
    ],
    questions: [
      _q('Why did Selin move to the coastal town?', [
        'Her company closed its city office.',
        'She could work from anywhere and liked the town.',
        'She found a new job there.',
        'Her family lived there.',
      ], 1, 'Şirketi her yerden çalışmaya izin verince çocukken gittiği kasabaya taşındı.'),
      _q('What did she gradually start to miss?', [
        'The noise of the city',
        'Her old apartment',
        'Unplanned conversations with colleagues',
        'Long walks by the sea',
      ], 2, 'İş arkadaşlarıyla plansız sohbetleri özledi; en iyi fikirleri onlardan çıkıyordu.'),
      _q('How did she solve the problem?', [
        'She moved back to the city.',
        'She changed her job.',
        'She organised meetups for remote workers.',
        'She opened a café.',
      ], 2, 'Şehre dönmek yerine uzaktan çalışanlar için aylık buluşmalar düzenledi.'),
      _q('Which sentence best describes the community today?', [
        'It has stayed very small.',
        'It has grown to over fifty people.',
        'It meets every day.',
        'It moved to the city.',
      ], 1, 'Birkaç kişiyle başlayan grup elli kişiyi aşan bir topluluğa dönüştü.'),
    ],
  ),
  DailyStory(
    title: 'An Unexpected Review',
    paragraphs: const [
      'Kerem had been running his small bakery for three years when a famous '
          'food critic walked in without warning. He only noticed who she was '
          'after she had left, having ordered a single slice of lemon cake.',
      'For a week he could hardly sleep, convinced that the review would be '
          'negative. When it was finally published, it praised the cake as '
          '“the best thing I have eaten this year”.',
      'The next morning there was a queue outside the door before he had even '
          'switched on the ovens. Kerem says that, had he known who she was, '
          'he would probably have been too nervous to serve her properly.',
    ],
    glossary: const [
      GlossaryItem(word: 'critic', meaning: 'eleştirmen'),
      GlossaryItem(word: 'convinced', meaning: 'emin, ikna olmuş'),
      GlossaryItem(word: 'queue', meaning: 'kuyruk, sıra'),
    ],
    questions: [
      _q('When did Kerem realise who the customer was?', [
        'Before she entered',
        'While she was ordering',
        'After she had left',
        'When the review was published',
      ], 2, 'Eleştirmeni ancak dükkândan ayrıldıktan sonra fark etti.'),
      _q('How did Kerem feel while waiting for the review?', [
        'Excited and confident',
        'Worried that it would be negative',
        'Completely calm',
        'Angry with the critic',
      ], 1, 'Bir hafta boyunca eleştirinin olumsuz olacağından emin olup uyuyamadı.'),
      _q('What does the last paragraph suggest?', [
        'Not knowing her identity helped him.',
        'He wanted to close the bakery.',
        'The critic came back the next day.',
        'He stopped making lemon cake.',
      ], 0, 'Kim olduğunu bilseydi heyecandan iyi servis yapamayacağını söylüyor.'),
    ],
  ),
];

QuizItem _q(
  String question,
  List<String> options,
  int answerIndex,
  String explanationTr,
) =>
    QuizItem(
      question: question,
      options: options,
      answer: options[answerIndex],
      explanationTr: explanationTr,
    );
