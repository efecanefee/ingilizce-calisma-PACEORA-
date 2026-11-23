import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Konuşma ve dinle-yaz pratiğinin puanlaması.
///
/// Hedef cümle ile söylenen/yazılan metin kelime kelime hizalanır (en uzun
/// ortak alt dizi). Sıra korunarak eşleşen kelimeler "doğru" sayılır;
/// noktalama ve büyük/küçük harf önemsenmez.

/// Bir hedef kelimenin sonucu.
class WordCheck {
  const WordCheck(this.word, {required this.ok});

  /// Cümlede göründüğü haliyle (noktalamasıyla) kelime.
  final String word;
  final bool ok;
}

class SentenceScore {
  const SentenceScore(this.words);

  final List<WordCheck> words;

  int get correct => words.where((w) => w.ok).length;

  /// 0-100.
  int get percent => words.isEmpty ? 0 : (correct * 100 / words.length).round();

  /// Cümle başarılı sayılır mı?
  bool get passed => percent >= passPercent;
}

/// Başarılı sayılma eşiği. Konuşma tanıma kusursuz değil; tek kelimelik
/// kayma cümleyi düşürmesin.
const passPercent = 80;

/// Karşılaştırma için kelime: küçük harf, noktalamasız, düz kesme işareti.
String _norm(String w) => w
    .toLowerCase()
    .replaceAll('’', "'")
    .replaceAll(RegExp(r"[^a-z0-9']"), '')
    .replaceAll(RegExp(r"^'+|'+$"), '');

/// Sık görülen kısaltmalar: tanıma "do not" der, cümlede "don't" yazar.
const _contractions = {
  "don't": 'do not',
  "doesn't": 'does not',
  "didn't": 'did not',
  "can't": 'can not',
  "cannot": 'can not',
  "won't": 'will not',
  "isn't": 'is not',
  "aren't": 'are not',
  "wasn't": 'was not',
  "weren't": 'were not',
  "haven't": 'have not',
  "hasn't": 'has not',
  "hadn't": 'had not',
  "i'm": 'i am',
  "you're": 'you are',
  "we're": 'we are',
  "they're": 'they are',
  "it's": 'it is',
  "he's": 'he is',
  "she's": 'she is',
  "that's": 'that is',
  "there's": 'there is',
  "i've": 'i have',
  "we've": 'we have',
  "they've": 'they have',
  "i'll": 'i will',
  "we'll": 'we will',
  "i'd": 'i would',
};

/// Yazılan/söylenen metni karşılaştırılabilir kelimelere açar.
List<String> _expand(String text) => [
  for (final raw in text.split(RegExp(r'\s+')))
    if (_norm(raw) case final w when w.isNotEmpty)
      ...(_contractions[w] ?? w).split(' '),
];

/// [target] cümlesini [heard] metnine göre puanlar.
///
/// Hedefteki kısaltmalar ("don't") iki kelimeye açılır ama sonuçta tek
/// kelime olarak gösterilir: ikisi de duyulduysa doğru sayılır.
SentenceScore scoreSentence(String target, String heard) {
  // Hedefin her kelimesi ve açılmış parçaları.
  final shown = target.split(RegExp(r'\s+')).where((w) => _norm(w).isNotEmpty);
  final parts = <(int, String)>[];
  final display = <String>[];
  for (final word in shown) {
    final i = display.length;
    display.add(word);
    final n = _norm(word);
    for (final p in (_contractions[n] ?? n).split(' ')) {
      parts.add((i, p));
    }
  }
  final said = _expand(heard);

  // En uzun ortak alt dizi tablosu.
  final m = parts.length, n = said.length;
  final dp = List.generate(m + 1, (_) => List.filled(n + 1, 0));
  for (var i = m - 1; i >= 0; i--) {
    for (var j = n - 1; j >= 0; j--) {
      dp[i][j] = parts[i].$2 == said[j]
          ? dp[i + 1][j + 1] + 1
          : max(dp[i + 1][j], dp[i][j + 1]);
    }
  }
  final matched = List.filled(m, false);
  var i = 0, j = 0;
  while (i < m && j < n) {
    if (parts[i].$2 == said[j]) {
      matched[i] = true;
      i++;
      j++;
    } else if (dp[i + 1][j] >= dp[i][j + 1]) {
      i++;
    } else {
      j++;
    }
  }

  return SentenceScore([
    for (var w = 0; w < display.length; w++)
      WordCheck(
        display[w],
        ok: [
          for (var p = 0; p < m; p++)
            if (parts[p].$1 == w) matched[p],
        ].every((ok) => ok),
      ),
  ]);
}

/// Pratik için cümle seçimi: makul uzunlukta, tekrarsız.
List<String> pickPracticeSentences(
  Iterable<String> candidates, {
  int count = 5,
  Random? random,
}) {
  final seen = <String>{};
  final pool = [
    for (final s in candidates)
      if (s.trim() case final t
          when _wordCount(t) >= 4 &&
              _wordCount(t) <= 16 &&
              seen.add(t.toLowerCase()))
        t,
  ]..shuffle(random);
  return pool.take(count).toList();
}

int _wordCount(String s) =>
    s.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length;

/// Deste ve hikaye boşken kullanılan cümleler.
const fallbackPracticeSentences = [
  'I usually drink a cup of tea in the morning.',
  'She has lived in Istanbul for five years.',
  'We are going to visit our grandparents this weekend.',
  'If it rains tomorrow, we will stay at home.',
  'He was reading a book when the phone rang.',
  'Could you tell me where the nearest station is?',
  'I have never seen such a beautiful sunset.',
  'They decided to take the train instead of the bus.',
  'My brother is taller than me, but I am older.',
  'The meeting was cancelled because the manager was ill.',
];

// --- Kayıtlar ----------------------------------------------------------------

/// Pratiğin XP'si: başarılı cümle başına.
const xpPerGoodSentence = 3;

/// Konuşma ve dinle-yaz kayıtları (SharedPreferences, `speech_` önekli).
class SpeechRecords {
  const SpeechRecords({this.spokenGood = 0, this.dictationGood = 0});

  static const spokenKey = 'speech_spoken_good';
  static const dictationKey = 'speech_dictation_good';

  /// Başarılı söylenen cümle sayısı.
  final int spokenGood;

  /// Doğru yazılan dikte cümlesi sayısı.
  final int dictationGood;

  int get xp => (spokenGood + dictationGood) * xpPerGoodSentence;

  factory SpeechRecords.read(SharedPreferences prefs) => SpeechRecords(
    spokenGood: prefs.getInt(spokenKey) ?? 0,
    dictationGood: prefs.getInt(dictationKey) ?? 0,
  );

  /// Bir başarılı cümleyi kaydeder.
  static Future<void> addGood(
    SharedPreferences prefs, {
    required bool spoken,
  }) async {
    final key = spoken ? spokenKey : dictationKey;
    await prefs.setInt(key, (prefs.getInt(key) ?? 0) + 1);
  }
}

/// Konuşmada zorlanılan kelimeler (SharedPreferences, `speech_hard_words`).
///
/// Yanlış söylenen kelimenin sayacı artar, doğru söylenince azalır; sıfıra
/// inen kelime listeden düşer. Böylece liste "hâlâ zorlandıkların"dır.
class HardWords {
  const HardWords(this.counts);

  static const key = 'speech_hard_words';

  final Map<String, int> counts;

  factory HardWords.read(SharedPreferences prefs) {
    final raw = prefs.getStringList(key) ?? const [];
    final counts = <String, int>{};
    for (final entry in raw) {
      final at = entry.lastIndexOf('|');
      if (at <= 0) continue;
      final n = int.tryParse(entry.substring(at + 1));
      if (n != null && n > 0) counts[entry.substring(0, at)] = n;
    }
    return HardWords(counts);
  }

  /// En çok zorlanılandan başlayarak en çok [n] kelime.
  List<String> top([int n = 8]) {
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted.take(n)) e.key];
  }

  /// Bir cümlenin sonucunu işler.
  static Future<void> record(
    SharedPreferences prefs,
    SentenceScore score,
  ) async {
    final counts = {...HardWords.read(prefs).counts};
    for (final w in score.words) {
      final word = _norm(w.word);
      if (word.length < 2) continue;
      final next = (counts[word] ?? 0) + (w.ok ? -1 : 1);
      if (next > 0) {
        counts[word] = next;
      } else {
        counts.remove(word);
      }
    }
    await prefs.setStringList(key, [
      for (final e in counts.entries) '${e.key}|${e.value}',
    ]);
  }
}
