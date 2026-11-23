import 'database.dart';
import 'repository.dart';

/// Uygulama içi arama: kelimeler (kart destesi), hata defteri ve program
/// konuları.
///
/// Veri küçük (en fazla birkaç bin satır); süzme cihazda yapılır.

/// Aramada büyük/küçük harf ve Türkçe harf farkı gözetilmez:
/// "İ/I/ı/i" → "i", "ş" → "s" vb.
String searchFold(String s) {
  const map = {
    'İ': 'i',
    'I': 'i',
    'ı': 'i',
    'ş': 's',
    'Ş': 's',
    'ğ': 'g',
    'Ğ': 'g',
    'ü': 'u',
    'Ü': 'u',
    'ö': 'o',
    'Ö': 'o',
    'ç': 'c',
    'Ç': 'c',
    '’': "'",
  };
  final b = StringBuffer();
  for (final ch in s.split('')) {
    b.write(map[ch] ?? ch.toLowerCase());
  }
  return b.toString().trim();
}

class TopicHit {
  const TopicHit({required this.date, required this.day});

  final DateTime date;
  final WeeklyPlanDay day;
}

class SearchResults {
  const SearchResults({
    this.words = const [],
    this.mistakes = const [],
    this.topics = const [],
  });

  final List<Flashcard> words;
  final List<Mistake> mistakes;
  final List<TopicHit> topics;

  bool get isEmpty => words.isEmpty && mistakes.isEmpty && topics.isEmpty;
  int get total => words.length + mistakes.length + topics.length;
}

/// [query] en az 2 harf olmalı; daha kısa sorgu boş sonuç döner.
SearchResults searchAll({
  required String query,
  required List<Flashcard> cards,
  required List<Mistake> mistakes,
  required List<WeeklyPlanDay> plan,
  int limit = 30,
}) {
  final q = searchFold(query);
  if (q.length < 2) return const SearchResults();
  bool hit(String s) => searchFold(s).contains(q);

  // Başında eşleşen önce gelir: "go" aranınca "go on" "ago"dan önce.
  int rank(String s) => searchFold(s).startsWith(q) ? 0 : 1;

  final words = cards.where((c) => hit(c.word) || hit(c.meaning)).toList()
    ..sort((a, b) => rank(a.word).compareTo(rank(b.word)));
  final wrong = mistakes.where((m) => hit(m.item) || hit(m.context)).toList()
    ..sort((a, b) => rank(a.item).compareTo(rank(b.item)));
  final topics = [
    for (final d in plan)
      if (hit(d.grammarTopic) || hit(d.vocabTheme))
        TopicHit(date: planDateOf(d), day: d),
  ]..sort((a, b) => b.date.compareTo(a.date));

  return SearchResults(
    words: words.take(limit).toList(),
    mistakes: wrong.take(limit).toList(),
    topics: topics.take(limit).toList(),
  );
}
