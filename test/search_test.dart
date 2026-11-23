import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/search.dart';

void main() {
  final now = DateTime(2026, 11, 20);
  Flashcard card(int id, String word, String meaning) => Flashcard(
    id: id,
    word: word,
    meaning: meaning,
    exampleSentence: '',
    source: 'new_word',
    ease: 2.5,
    intervalDays: 0,
    reps: 0,
    dueDate: now,
    createdAt: now,
  );
  Mistake mistake(int id, String item) => Mistake(
    id: id,
    item: item,
    context: 'bağlam',
    type: 'grammar',
    timesWrong: 1,
    timesCorrect: 0,
    resolved: false,
    createdAt: now,
  );
  WeeklyPlanDay day(int i, String topic, String theme) => WeeklyPlanDay(
    id: i,
    weekStart: DateTime(2026, 11, 16),
    dayIndex: i,
    grammarTopic: topic,
    vocabTheme: theme,
    status: 'pending',
  );

  final cards = [
    card(1, 'ago', 'önce'),
    card(2, 'go on', 'devam etmek'),
    card(3, 'journey', 'yolculuk'),
  ];
  final plan = [
    day(0, 'Past Perfect', 'Seyahat ve ulaşım'),
    day(3, 'Present Perfect', 'İş hayatı'),
  ];

  SearchResults run(String q) => searchAll(
    query: q,
    cards: cards,
    mistakes: [mistake(1, 'go home')],
    plan: plan,
  );

  test('kısa sorgu sonuç vermez', () {
    expect(run('g').isEmpty, isTrue);
    expect(run('  ').isEmpty, isTrue);
  });

  test('başta eşleşen önce gelir; anlamda da aranır', () {
    final r = run('go');
    expect(r.words.map((c) => c.word), ['go on', 'ago']);
    expect(r.mistakes.single.item, 'go home');
    expect(run('yolcu').words.single.word, 'journey');
  });

  test('Türkçe harf ve büyük/küçük harf farkı gözetilmez', () {
    expect(run('SEYAHAT').topics.single.day.grammarTopic, 'Past Perfect');
    expect(run('is hayati').topics.single.day.grammarTopic, 'Present Perfect');
    expect(searchFold('İŞ Iğdır'), 'is igdir');
  });

  test('konular yeniden eskiye, tarihleriyle', () {
    final r = run('perfect');
    expect(r.topics.map((t) => t.date), [
      DateTime(2026, 11, 19),
      DateTime(2026, 11, 16),
    ]);
  });
}
