import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

/// Kelime Rallisi: 60 saniyede olabildiğince çok İngilizce–Türkçe çifti
/// eşleştirme oyunu. Kelimeler kullanıcının seviyesinden gelir
/// (bkz. `level_words.dart`).

/// Bir turun süresi.
const matchRoundDuration = Duration(seconds: 60);

/// Tahtadaki satır sayısı (her sütunda).
const matchBoardRows = 5;

/// Oynamak için gereken en az kart: tahta dolu ve dışarıda en az bir kart.
///
/// Tam 5 kartla eşleşen çiftin yerine yine kendisi gelir; oyuncuya "hiçbir
/// şey olmadı" gibi görünür. Dışarıda kalan kart her eşleşmede yeni yüz getirir.
const matchMinPairs = matchBoardRows + 1;

/// Boşalan çift sayısı buna ulaşınca yerlerine topluca yeni çiftler gelir.
///
/// Her eşleşmede tek çift gelseydi iki yarısı da az önce boşalan iki yere
/// düşer, oyuncu okumadan eşleştirirdi.
const matchRefillAt = 3;

/// Doğru eşleşme başına temel puan; kombo çarpanıyla çarpılır.
const matchBasePoints = 10;

/// Bir oyunun kazandırabileceği en fazla XP: oyun dersin yerini almasın.
const matchMaxXp = 30;

/// Eşleştirilecek çift; [id] flash kartın kimliğidir.
class MatchPair {
  const MatchPair({
    required this.id,
    required this.word,
    required this.meaning,
  });

  final int id;
  final String word;
  final String meaning;
}

enum MatchSide { word, meaning }

/// Bir dokunuşun sonucu.
enum MatchOutcome {
  /// Seçim yapıldı ya da değiştirildi; karşı taraf bekleniyor.
  selected,

  /// Seçim kaldırıldı ya da dokunulan yer boştu.
  ignored,
  correct,
  wrong,
}

/// Oyun tahtası. Arayüzden bağımsızdır; süreyi ekran tutar.
///
/// Doğru eşleşen kutucuklar önce [cleared] olarak işaretlenir, ekran kısa
/// bir yeşil parlamadan sonra [refill] çağırır. Kutucuklar önce boşalır;
/// [matchRefillAt] çift boşalınca yerlerine karışık sırada yenileri gelir.
class MatchBoard {
  MatchBoard(List<MatchPair> pairs, {Random? random})
    : assert(pairs.length >= matchBoardRows),
      _random = random ?? Random(),
      _pool = List.of(pairs) {
    _pool.shuffle(_random);
    for (var i = 0; i < matchBoardRows; i++) {
      words.add(_draw());
    }
    meanings
      ..addAll(words)
      ..shuffle(_random);
  }

  final Random _random;
  final List<MatchPair> _pool;
  var _next = 0;

  /// Sol sütun (İngilizce) ve sağ sütun (Türkçe).
  final words = <MatchPair>[];
  final meanings = <MatchPair>[];

  /// Seçili kutucuk: (taraf, satır).
  (MatchSide, int)? selected;

  /// Doğru eşleşip yenilenmeyi bekleyen kutucuklar.
  final cleared = <(MatchSide, int)>{};

  /// Parlaması bitmiş, yeni çift bekleyen boş yerler: (İngilizce satırı,
  /// Türkçe satırı), eşleştirilme sırasıyla.
  final vacant = <(int word, int meaning)>[];

  bool isVacant(MatchSide side, int row) =>
      vacant.any((v) => row == (side == MatchSide.word ? v.$1 : v.$2));

  int score = 0;
  int matches = 0;
  int mistakes = 0;

  /// Üst üste doğru eşleşme sayısı; yanlışta sıfırlanır.
  int combo = 0;
  int bestCombo = 0;

  /// Yanlış eşleştirilen çiftler (her iki taraf da), kimliğe göre.
  final _confused = <int, MatchPair>{};

  Iterable<MatchPair> get confused => _confused.values;

  Set<int> get confusedIds => _confused.keys.toSet();

  /// Sıradaki doğru eşleşmenin çarpanı: 1-3. eşleşme x1, 4-6. x2, sonrası x3.
  int get multiplier => 1 + min(combo ~/ 3, 2);

  MatchPair at(MatchSide side, int row) =>
      side == MatchSide.word ? words[row] : meanings[row];

  /// Destedeki sıradaki çift; tahtadakilerle aynı kelime ya da anlamı
  /// taşıyanlar atlanır (iki "bank" aynı anda görünmesin).
  ///
  /// [leaving]: tahtadan çıkmak üzere olan çiftler. Önce onlar da atlanır;
  /// deste çok küçükse ve başka aday yoksa yeniden gelebilirler.
  MatchPair _draw({Set<int> leaving = const {}}) {
    final onBoard = [...words, ...meanings];
    bool clashes(MatchPair p) => onBoard.any(
      (b) =>
          b.id == p.id ||
          _norm(b.word) == _norm(p.word) ||
          _norm(b.meaning) == _norm(p.meaning),
    );

    for (var tries = 0; tries < _pool.length; tries++) {
      if (_next >= _pool.length) {
        _next = 0;
        _pool.shuffle(_random);
      }
      final candidate = _pool[_next++];
      if (!clashes(candidate)) return candidate;
    }
    // Döngü ortasında yeniden karıştırma bazı kartları atlatmış olabilir;
    // bütün destede çakışmasız aday aranır.
    for (final candidate in _pool) {
      if (!clashes(candidate)) return candidate;
    }
    // Çakışmasız aday yok: tahtada kalacaklardan farklı herhangi bir çift.
    final staying = {
      for (final b in onBoard)
        if (!leaving.contains(b.id)) b.id,
    };
    return _pool.firstWhere((p) => !staying.contains(p.id));
  }

  static String _norm(String s) => s.trim().toLowerCase();

  MatchOutcome tap(MatchSide side, int row) {
    if (cleared.contains((side, row)) || isVacant(side, row)) {
      return MatchOutcome.ignored;
    }
    final current = selected;

    if (current == null || current.$1 == side) {
      // Aynı kutucuğa ikinci dokunuş seçimi kaldırır.
      if (current == (side, row)) {
        selected = null;
        return MatchOutcome.ignored;
      }
      selected = (side, row);
      return MatchOutcome.selected;
    }

    selected = null;
    final a = at(current.$1, current.$2);
    final b = at(side, row);
    if (a.id == b.id) {
      score += matchBasePoints * multiplier;
      combo++;
      bestCombo = max(bestCombo, combo);
      matches++;
      cleared
        ..add(current)
        ..add((side, row));
      return MatchOutcome.correct;
    }
    combo = 0;
    mistakes++;
    _confused
      ..[a.id] = a
      ..[b.id] = b;
    return MatchOutcome.wrong;
  }

  /// Eşleşen kutucukları boşaltır; yeterince yer boşaldıysa yeni çiftler
  /// koyar.
  ///
  /// Yeni çiftlerin Türkçesi hiçbir zaman, İngilizcesinin geldiği yerle aynı
  /// anda boşalan yere gitmez: son eşleştirilen iki yere bakıp tahmin
  /// edilemez.
  void refill() {
    final wordRows = [
      for (final (side, row) in cleared)
        if (side == MatchSide.word) row,
    ];
    for (final row in wordRows) {
      final id = words[row].id;
      vacant.add((row, meanings.indexWhere((p) => p.id == id)));
    }
    cleared.clear();
    if (vacant.length < matchRefillAt) return;

    final slots = [...vacant];
    vacant.clear();
    final leaving = {for (final (row, _) in slots) words[row].id};
    final shift = 1 + _random.nextInt(slots.length - 1);
    final fresh = <MatchPair>[];
    for (final (row, _) in slots) {
      final next = _draw(leaving: leaving);
      words[row] = next;
      fresh.add(next);
      // Geri dönen çift artık tahtada kalıyor; ikinci kez çekilmesin.
      leaving.remove(next.id);
    }
    // Türkçe karşılıklar en son yazılır: çekiliş sırasında tahtadan çıkan
    // çiftler hâlâ çakışma sayılsın.
    for (var i = 0; i < slots.length; i++) {
      meanings[slots[(i + shift) % slots.length].$2] = fresh[i];
    }
  }

  MatchSummary summary({required int bestScoreBefore}) => MatchSummary(
    score: score,
    matches: matches,
    mistakes: mistakes,
    bestCombo: bestCombo,
    isNewBest: score > bestScoreBefore && score > 0,
  );
}

/// Bitmiş bir turun özeti.
class MatchSummary {
  const MatchSummary({
    required this.score,
    required this.matches,
    required this.mistakes,
    required this.bestCombo,
    this.isNewBest = false,
  });

  final int score;
  final int matches;
  final int mistakes;
  final int bestCombo;
  final bool isNewBest;

  int get xp => matchXp(matches);

  /// Doğru eşleşmelerin tüm denemelere oranı (0-100).
  int get accuracy {
    final attempts = matches + mistakes;
    return attempts == 0 ? 0 : (matches * 100 / attempts).round();
  }
}

/// Bir turun XP'si: eşleşme başına 1, en fazla [matchMaxXp].
int matchXp(int matches) => min(matches, matchMaxXp);

/// Kelime Rallisi'nin kalıcı istatistikleri (SharedPreferences).
class MatchRecords {
  const MatchRecords({
    this.games = 0,
    this.bestScore = 0,
    this.bestMatches = 0,
    this.xp = 0,
  });

  static const gamesKey = 'match_games';
  static const bestScoreKey = 'match_best_score';
  static const bestMatchesKey = 'match_best_matches';
  static const xpKey = 'match_xp';

  final int games;
  final int bestScore;
  final int bestMatches;

  /// Tüm turlardan kazanılan XP toplamı.
  final int xp;

  factory MatchRecords.read(SharedPreferences prefs) => MatchRecords(
    games: prefs.getInt(gamesKey) ?? 0,
    bestScore: prefs.getInt(bestScoreKey) ?? 0,
    bestMatches: prefs.getInt(bestMatchesKey) ?? 0,
    xp: prefs.getInt(xpKey) ?? 0,
  );

  /// Turu kaydeder ve güncel kayıtları döner.
  static Future<MatchRecords> save(
    SharedPreferences prefs,
    MatchSummary summary,
  ) async {
    final old = MatchRecords.read(prefs);
    final next = MatchRecords(
      games: old.games + 1,
      bestScore: max(old.bestScore, summary.score),
      bestMatches: max(old.bestMatches, summary.matches),
      xp: old.xp + summary.xp,
    );
    await prefs.setInt(gamesKey, next.games);
    await prefs.setInt(bestScoreKey, next.bestScore);
    await prefs.setInt(bestMatchesKey, next.bestMatches);
    await prefs.setInt(xpKey, next.xp);
    return next;
  }
}
