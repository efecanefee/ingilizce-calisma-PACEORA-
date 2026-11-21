import '../app/constants.dart';
import 'placement.dart';

/// Seviye seçildikten sonra gösterilen önizleme ve 4 soruluk kontrol.
///
/// Her kademe için odak konuları ve o kademeyi ölçen sorular cihazda durur.
class LevelPreview {
  const LevelPreview({required this.focus, required this.questions});

  /// "Nelere odaklanacağız" maddeleri.
  final List<String> focus;

  /// Kademeye özel kontrol soruları.
  final List<PlacementQuestion> questions;

  static LevelPreview of(DifficultyLevel level) => _previews[level]!;
}

/// Kontrolün sonucu: seviye uygun mu, yoksa bir alt/üst kademe mi öneriliyor.
enum LevelCheckVerdict { lower, fits, higher }

/// 4 sorudan: hepsi doğru → üst kademe önerilir, 0-1 doğru → alt kademe.
/// Zaten en üst/alt kademedeyse "uygun" sayılır.
LevelCheckVerdict levelCheckVerdict(DifficultyLevel level, int correct) {
  final last = DifficultyLevel.values.length - 1;
  if (correct >= 4 && level.index < last) return LevelCheckVerdict.higher;
  if (correct <= 1 && level.index > 0) return LevelCheckVerdict.lower;
  return LevelCheckVerdict.fits;
}

const _previews = <DifficultyLevel, LevelPreview>{
  DifficultyLevel.a2: LevelPreview(
    focus: [
      'to be, have got ve present simple ile kendini anlatma',
      'Past simple ile geçen hafta sonunu anlatma',
      'there is / there are, some / any',
      'Aile, yemek, ev ve alışveriş kelimeleri',
    ],
    questions: [
      PlacementQuestion(
        prompt: 'There ___ two apples on the table.',
        options: ['is', 'are', 'be', 'am'],
        answer: 1,
        level: DifficultyLevel.a2,
      ),
      PlacementQuestion(
        prompt: 'He ___ like coffee.',
        options: ["don't", "doesn't", "isn't", "not"],
        answer: 1,
        level: DifficultyLevel.a2,
      ),
      PlacementQuestion(
        prompt: 'I ___ born in Bolu.',
        options: ['am', 'were', 'was', 'did'],
        answer: 2,
        level: DifficultyLevel.a2,
      ),
      PlacementQuestion(
        prompt: 'Can I have ___ water, please?',
        options: ['a', 'some', 'many', 'an'],
        answer: 1,
        level: DifficultyLevel.a2,
      ),
    ],
  ),
  DifficultyLevel.b1Minus: LevelPreview(
    focus: [
      'Present simple ve present continuous farkı',
      'Past simple: düzenli ve düzensiz fiiller',
      'can, must, have to ile kurallar ve olanaklar',
      'Günlük rutin, alışveriş ve yol tarifi kelimeleri',
    ],
    questions: [
      PlacementQuestion(
        prompt: 'We ___ dinner when the phone rang.',
        options: ['had', 'were having', 'have', 'are having'],
        answer: 1,
        level: DifficultyLevel.b1Minus,
      ),
      PlacementQuestion(
        prompt: "There aren't ___ eggs in the fridge.",
        options: ['some', 'much', 'any', 'a'],
        answer: 2,
        level: DifficultyLevel.b1Minus,
      ),
      PlacementQuestion(
        prompt: "You ___ wear a seatbelt. It's the law.",
        options: ['must', 'can', 'might', 'would'],
        answer: 0,
        level: DifficultyLevel.b1Minus,
      ),
      PlacementQuestion(
        prompt: 'He is ___ than his brother.',
        options: ['tall', 'tallest', 'more tall', 'taller'],
        answer: 3,
        level: DifficultyLevel.b1Minus,
      ),
    ],
  ),
  DifficultyLevel.b1: LevelPreview(
    focus: [
      'Present perfect ve past simple ayrımı',
      'First ve second conditional',
      'Relative clauses: who, which, where',
      'İş, seyahat ve sağlık kelimeleri; kısa e-posta yazma',
    ],
    questions: [
      PlacementQuestion(
        prompt: 'Have you ever ___ sushi?',
        options: ['eat', 'ate', 'eaten', 'eating'],
        answer: 2,
        level: DifficultyLevel.b1,
      ),
      PlacementQuestion(
        prompt: 'If I won the lottery, I ___ a big house.',
        options: ['would buy', 'will buy', 'buy', 'bought'],
        answer: 0,
        level: DifficultyLevel.b1,
      ),
      PlacementQuestion(
        prompt: 'The woman ___ lives next door is a doctor.',
        options: ['which', 'who', 'where', 'whose'],
        answer: 1,
        level: DifficultyLevel.b1,
      ),
      PlacementQuestion(
        prompt: "I'm looking forward ___ you again.",
        options: ['to see', 'seeing', 'see', 'to seeing'],
        answer: 3,
        level: DifficultyLevel.b1,
      ),
    ],
  ),
  DifficultyLevel.b1Plus: LevelPreview(
    focus: [
      'Past perfect ile olayları sıralama',
      'Passive voice (edilgen yapı)',
      'Reported speech (dolaylı anlatım)',
      'used to / be used to ve sık kullanılan phrasal verb’ler',
    ],
    questions: [
      PlacementQuestion(
        prompt: 'The bridge ___ in 1990.',
        options: ['built', 'was built', 'has built', 'is building'],
        answer: 1,
        level: DifficultyLevel.b1Plus,
      ),
      PlacementQuestion(
        prompt: 'She told me she ___ tired.',
        options: ['is', 'will be', 'was', 'has'],
        answer: 2,
        level: DifficultyLevel.b1Plus,
      ),
      PlacementQuestion(
        prompt: 'I ___ play football every weekend when I was a child.',
        options: ['used to', 'use to', 'was used to', 'am used to'],
        answer: 0,
        level: DifficultyLevel.b1Plus,
      ),
      PlacementQuestion(
        prompt: "Could you turn ___ the music? It's too loud.",
        options: ['up', 'on', 'in', 'down'],
        answer: 3,
        level: DifficultyLevel.b1Plus,
      ),
    ],
  ),
  DifficultyLevel.b2Minus: LevelPreview(
    focus: [
      'Third conditional ile geçmişi yorumlama',
      'Çıkarım bildiren modal’lar: must, might, can’t',
      'Gerund ve infinitive ile fiil kalıpları',
      'Bağlaçlar (despite, although, however) ve görüş yazısı',
    ],
    questions: [
      PlacementQuestion(
        prompt: 'If she had studied harder, she ___ the exam.',
        options: [
          'would pass',
          'will pass',
          'would have passed',
          'passed',
        ],
        answer: 2,
        level: DifficultyLevel.b2Minus,
      ),
      PlacementQuestion(
        prompt: "He ___ be at home; all the lights are off.",
        options: ["can't", "mustn't", "shouldn't", "needn't"],
        answer: 0,
        level: DifficultyLevel.b2Minus,
      ),
      PlacementQuestion(
        prompt: 'I stopped ___ coffee last year.',
        options: ['to drink', 'drinking', 'drink', 'drunk'],
        answer: 1,
        level: DifficultyLevel.b2Minus,
      ),
      PlacementQuestion(
        prompt: '___ the rain, we went for a walk.',
        options: ['Although', 'Even', 'However', 'Despite'],
        answer: 3,
        level: DifficultyLevel.b2Minus,
      ),
    ],
  ),
  DifficultyLevel.b2: LevelPreview(
    focus: [
      'Future continuous ve future perfect',
      'wish / if only ile istek ve pişmanlık',
      'Vurgu için inversion (Not only…, Hardly…)',
      'Collocation’lar ve resmi yazı dili',
    ],
    questions: [
      PlacementQuestion(
        prompt: 'This time tomorrow, I ___ on a beach.',
        options: ['will lie', 'will be lying', 'lie', 'am lying'],
        answer: 1,
        level: DifficultyLevel.b2,
      ),
      PlacementQuestion(
        prompt: 'I wish I ___ more time to travel.',
        options: ['have', 'would have', 'had', 'will have'],
        answer: 2,
        level: DifficultyLevel.b2,
      ),
      PlacementQuestion(
        prompt: 'Not only ___ late, but he also forgot the documents.',
        options: ['was he', 'he was', 'he is', 'did he'],
        answer: 0,
        level: DifficultyLevel.b2,
      ),
      PlacementQuestion(
        prompt: 'She made a ___ effort to finish the project on time.',
        options: ['concentrated', 'considered', 'concealed', 'concerted'],
        answer: 3,
        level: DifficultyLevel.b2,
      ),
    ],
  ),
  DifficultyLevel.b2Plus: LevelPreview(
    focus: [
      'Mixed conditionals',
      'Cleft sentences ile vurgu (It was… who…)',
      'Subjunctive: It is essential that he be…',
      'İnce anlam farkları, deyimler ve tartışma yazısı',
    ],
    questions: [
      PlacementQuestion(
        prompt: 'If I had taken that job, I ___ in London now.',
        options: [
          'would have lived',
          'would be living',
          'will live',
          'lived',
        ],
        answer: 1,
        level: DifficultyLevel.b2Plus,
      ),
      PlacementQuestion(
        prompt: 'It was John ___ broke the window.',
        options: ['which', 'what', 'who', 'whom'],
        answer: 2,
        level: DifficultyLevel.b2Plus,
      ),
      PlacementQuestion(
        prompt: 'It is essential that he ___ on time.',
        options: ['is', 'be', 'was', 'will be'],
        answer: 1,
        level: DifficultyLevel.b2Plus,
      ),
      PlacementQuestion(
        prompt: 'The new rules were only a ___ improvement; little changed.',
        options: ['marginal', 'massive', 'pivotal', 'sweeping'],
        answer: 0,
        level: DifficultyLevel.b2Plus,
      ),
    ],
  ),
  DifficultyLevel.c1: LevelPreview(
    focus: [
      'Vurgu için inversion ve cleft yapılar',
      'Gelişmiş bağlaçlar ve söylem belirleyiciler',
      'Akademik ve iş İngilizcesinde resmi üslup',
      'Deyimler, phrasal verb’ler ve ince anlam farkları',
    ],
    questions: [
      PlacementQuestion(
        prompt: 'Rarely ___ such a convincing argument.',
        options: ['I have heard', 'have I heard', 'I heard', 'heard I'],
        answer: 1,
        level: DifficultyLevel.c1,
      ),
      PlacementQuestion(
        prompt: 'What I need ___ a long holiday.',
        options: ['are', 'is', 'be', 'being'],
        answer: 1,
        level: DifficultyLevel.c1,
      ),
      PlacementQuestion(
        prompt: 'The results were inconclusive; ___, further research is needed.',
        options: ['nevertheless', 'consequently', 'whereas', 'albeit'],
        answer: 1,
        level: DifficultyLevel.c1,
      ),
      PlacementQuestion(
        prompt: "She's very good at ___ difficult situations.",
        options: ['defusing', 'diffusing', 'refusing', 'confusing'],
        answer: 0,
        level: DifficultyLevel.c1,
      ),
    ],
  ),
};
