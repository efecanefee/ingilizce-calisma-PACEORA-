import 'dart:convert';

import 'gemini_json.dart';
import 'story_models.dart';

/// Hikaye metninin bir parçası: ya dokunulabilir bir kelime ya da aradaki
/// boşluk/noktalama.
class StoryToken {
  const StoryToken(this.text, {required this.start, this.isWord = false});

  final String text;

  /// Paragraf içindeki başlangıç konumu; örnek cümleyi bulmak için.
  final int start;
  final bool isWord;
}

/// "didn't", "Selin’s" gibi kesme işaretli kelimeler tek parça sayılır.
final _wordPattern = RegExp(r"[A-Za-z]+(?:['’][A-Za-z]+)*");

/// Paragrafı kelime ve ara metin parçalarına böler; parçalar birleşince
/// paragrafın kendisi elde edilir.
List<StoryToken> tokenizeParagraph(String paragraph) {
  final tokens = <StoryToken>[];
  var cursor = 0;
  for (final match in _wordPattern.allMatches(paragraph)) {
    if (match.start > cursor) {
      tokens.add(
        StoryToken(paragraph.substring(cursor, match.start), start: cursor),
      );
    }
    tokens.add(StoryToken(match[0]!, start: match.start, isWord: true));
    cursor = match.end;
  }
  if (cursor < paragraph.length) {
    tokens.add(StoryToken(paragraph.substring(cursor), start: cursor));
  }
  return tokens;
}

/// Önbellek ve karşılaştırma anahtarı: küçük harf, düz kesme işareti.
String normalizeWord(String word) =>
    word.trim().toLowerCase().replaceAll('’', "'");

/// [offset] konumundaki kelimeyi içeren cümle.
String sentenceAt(String paragraph, int offset) {
  final ends = RegExp(r'[.!?]+["”’)]*\s+');
  var start = 0;
  for (final match in ends.allMatches(paragraph)) {
    if (match.end > offset) {
      return paragraph.substring(start, match.end).trim();
    }
    start = match.end;
  }
  return paragraph.substring(start).trim();
}

/// Paragrafı cümlelere böler.
List<String> splitSentences(String paragraph) => [
  for (final m in RegExp(r'[^.!?]+[.!?]+["”’)]*').allMatches(paragraph))
    if (m[0]!.trim().isNotEmpty) m[0]!.trim(),
];

/// Basit İngilizce çekim eklerini atarak olası kök biçimleri üretir.
///
/// Sözlükçedeki "decide" ile metindeki "decided"ı eşleştirmeye yeter;
/// düzensiz fiiller (lost → lose) Gemini'ye bırakılır.
Set<String> _baseForms(String word) {
  final w = normalizeWord(word);
  final forms = {w};
  void add(String suffix, [String replacement = '']) {
    if (w.length > suffix.length + 2 && w.endsWith(suffix)) {
      final stem = w.substring(0, w.length - suffix.length);
      forms.add('$stem$replacement');
      // stopped → stop, running → run
      if (replacement.isEmpty &&
          (suffix == 'ed' || suffix == 'ing') &&
          stem.length > 2 &&
          stem[stem.length - 1] == stem[stem.length - 2]) {
        forms.add(stem.substring(0, stem.length - 1));
      }
    }
  }

  if (w.endsWith("'s")) forms.add(w.substring(0, w.length - 2));
  add('ies', 'y');
  add('ied', 'y');
  add('es');
  add('s');
  add('ed');
  add('d');
  add('ing');
  add('ing', 'e');
  return forms;
}

/// Hikayenin sözlükçesinde bu kelimenin karşılığı varsa döner.
GlossaryItem? glossaryMatch(List<GlossaryItem> glossary, String word) {
  final forms = _baseForms(word);
  for (final item in glossary) {
    if (forms.contains(normalizeWord(item.word))) return item;
  }
  return null;
}

/// Bir kelimenin Türkçe karşılığı.
class WordMeaning {
  const WordMeaning({
    required this.word,
    required this.meaning,
    this.partOfSpeech = '',
  });

  /// Sözlük biçimi (lost → lose); karta bu yazılır.
  final String word;

  /// Cümledeki anlamıyla Türkçe karşılığı.
  final String meaning;

  /// Türkçe sözcük türü: fiil, isim, sıfat…
  final String partOfSpeech;

  static WordMeaning? tryParse(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final word = readString(raw, 'word');
    final meaning = readString(raw, 'meaning');
    if (word.isEmpty || meaning.isEmpty) return null;
    return WordMeaning(
      word: word,
      meaning: meaning,
      partOfSpeech: readString(raw, 'partOfSpeech'),
    );
  }

  Map<String, dynamic> toJson() => {
    'word': word,
    'meaning': meaning,
    if (partOfSpeech.isNotEmpty) 'partOfSpeech': partOfSpeech,
  };
}

/// Gemini yanıtını [WordMeaning]'e çevirir; bozuksa null.
WordMeaning? parseWordMeaningResponse(String responseBody) {
  final text = extractModelText(responseBody);
  if (text == null) return null;
  try {
    return WordMeaning.tryParse(jsonDecode(stripCodeFence(text)));
  } catch (_) {
    return null;
  }
}
