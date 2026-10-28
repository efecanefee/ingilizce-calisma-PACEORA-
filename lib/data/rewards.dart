import 'package:flutter/material.dart';

/// Ödül sisteminin girdisi: kullanıcının tüm çalışma geçmişinin özeti.
///
/// XP ve rozetler ayrı bir tabloda tutulmaz, her seferinde bu özetten
/// hesaplanır. Böylece ödüller veriyle hiç çelişmez ve şema değişmez.
class GameStats {
  const GameStats({
    this.lessons = 0,
    this.perfectLessons = 0,
    this.lessonXpSum = 0,
    this.stories = 0,
    this.storyXpSum = 0,
    this.cardsReviewed = 0,
    this.cardsMature = 0,
    this.studiedDays = 0,
    this.currentStreak = 0,
    this.bestStreak = 0,
    this.levelUps = 0,
  });

  final int lessons;
  final int perfectLessons;

  /// Derslerin [lessonXp] toplamı (ders başına yuvarlanmış).
  final int lessonXpSum;
  final int stories;

  /// Hikaye testlerinin [storyXp] toplamı.
  final int storyXpSum;
  final int cardsReviewed;
  final int cardsMature;
  final int studiedDays;
  final int currentStreak;
  final int bestStreak;

  /// Haftalık raporla uygulanan seviye yükselişi sayısı.
  final int levelUps;
}

/// Bir dersin kazandırdığı XP — sonuç ekranında da aynı formül gösterilir.
int lessonXp(double scorePercent) => 20 + (scorePercent / 5).round();

/// Bitirilen bir hikaye testinin XP'si.
int storyXp(double scorePercent) => 15 + (scorePercent / 10).round();

const xpPerCardReview = 2;
const xpPerStudiedDay = 10;
const xpPerLevelUp = 100;

/// Haftalık raporla uygulanan seviye yükselişi sayacının
/// SharedPreferences anahtarı. Rapor yenilenince kaybolmasın diye rapordan
/// türetilmez, ayrı tutulur.
const levelUpsKey = 'level_ups';

/// Toplam XP. Ders ve hikaye XP'si sonuç ekranlarında gösterilenle birebir
/// aynı olsun diye öğe başına hesaplanıp toplanır.
int totalXp(GameStats s) =>
    s.lessonXpSum +
    s.storyXpSum +
    s.cardsReviewed * xpPerCardReview +
    s.studiedDays * xpPerStudiedDay +
    s.levelUps * xpPerLevelUp;

/// [level]'e ulaşmak için gereken toplam XP: 0, 100, 300, 600, 1000, …
///
/// Her seviye bir öncekinden 100 XP daha uzun: başta hızlı ilerleme hissi,
/// sonra kazanılmış bir unvan.
int xpForLevel(int level) => 50 * level * (level - 1);

const _titles = [
  'Çaylak',
  'Meraklı',
  'Kaşif',
  'Gezgin',
  'Azimli',
  'Usta',
  'Bilge',
  'Efsane',
];

/// Oyuncu seviyesi (CEFR seviyesinden bağımsız, motivasyon için).
class PlayerLevel {
  const PlayerLevel({
    required this.level,
    required this.xp,
    required this.levelStartXp,
    required this.nextLevelXp,
  });

  factory PlayerLevel.fromXp(int xp) {
    var level = 1;
    while (xp >= xpForLevel(level + 1)) {
      level++;
    }
    return PlayerLevel(
      level: level,
      xp: xp,
      levelStartXp: xpForLevel(level),
      nextLevelXp: xpForLevel(level + 1),
    );
  }

  final int level;
  final int xp;
  final int levelStartXp;
  final int nextLevelXp;

  String get title => _titles[(level - 1).clamp(0, _titles.length - 1)];

  /// Bu seviyenin içindeki ilerleme (0-1).
  double get progress => (xp - levelStartXp) / (nextLevelXp - levelStartXp);

  int get xpToNext => nextLevelXp - xp;
}

/// Rozet tanımı: koşul ve ilerleme [GameStats]'tan okunur.
class BadgeDef {
  const BadgeDef({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.target,
    required this.measure,
  });

  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final int target;
  final int Function(GameStats) measure;

  int progressOf(GameStats s) => measure(s).clamp(0, target);
  bool earnedBy(GameStats s) => measure(s) >= target;
}

const badges = <BadgeDef>[
  BadgeDef(
    id: 'first_lesson',
    title: 'İlk adım',
    description: 'İlk dersini bitir',
    icon: Icons.flag_rounded,
    color: Color(0xFF9BC427),
    target: 1,
    measure: _lessons,
  ),
  BadgeDef(
    id: 'streak_3',
    title: 'Kıvılcım',
    description: '3 gün üst üste çalış',
    icon: Icons.local_fire_department_rounded,
    color: Color(0xFFFB923C),
    target: 3,
    measure: _bestStreak,
  ),
  BadgeDef(
    id: 'perfect',
    title: 'Kusursuz',
    description: 'Bir dersi %100 bitir',
    icon: Icons.workspace_premium_rounded,
    color: Color(0xFFFBBF24),
    target: 1,
    measure: _perfect,
  ),
  BadgeDef(
    id: 'reader',
    title: 'Kitap kurdu',
    description: '5 hikaye oku',
    icon: Icons.auto_stories_rounded,
    color: Color(0xFF60A5FA),
    target: 5,
    measure: _stories,
  ),
  BadgeDef(
    id: 'cards_50',
    title: 'Hafıza avcısı',
    description: '50 flash kart tekrarı yap',
    icon: Icons.style_rounded,
    color: Color(0xFFA78BFA),
    target: 50,
    measure: _cardsReviewed,
  ),
  BadgeDef(
    id: 'streak_7',
    title: 'Alev',
    description: '7 gün üst üste çalış',
    icon: Icons.whatshot_rounded,
    color: Color(0xFFF87171),
    target: 7,
    measure: _bestStreak,
  ),
  BadgeDef(
    id: 'lessons_10',
    title: 'Azimli',
    description: '10 ders bitir',
    icon: Icons.school_rounded,
    color: Color(0xFF34D399),
    target: 10,
    measure: _lessons,
  ),
  BadgeDef(
    id: 'mature_10',
    title: 'Kalıcı hafıza',
    description: '10 kartı kalıcı öğren (21+ gün aralık)',
    icon: Icons.psychology_rounded,
    color: Color(0xFF22D3EE),
    target: 10,
    measure: _mature,
  ),
  BadgeDef(
    id: 'level_up',
    title: 'Bir üst lig',
    description: 'Haftalık raporla seviye atla',
    icon: Icons.trending_up_rounded,
    color: Color(0xFFC6F432),
    target: 1,
    measure: _levelUps,
  ),
  BadgeDef(
    id: 'streak_30',
    title: 'Yanardağ',
    description: '30 gün üst üste çalış',
    icon: Icons.volcano_rounded,
    color: Color(0xFFEF4444),
    target: 30,
    measure: _bestStreak,
  ),
];

int _lessons(GameStats s) => s.lessons;
int _bestStreak(GameStats s) => s.bestStreak;
int _perfect(GameStats s) => s.perfectLessons;
int _stories(GameStats s) => s.stories;
int _cardsReviewed(GameStats s) => s.cardsReviewed;
int _mature(GameStats s) => s.cardsMature;
int _levelUps(GameStats s) => s.levelUps;

/// Ekranlara verilen hazır ödül durumu.
class GameState {
  GameState(this.stats) : level = PlayerLevel.fromXp(totalXp(stats));

  final GameStats stats;
  final PlayerLevel level;

  Set<String> get earnedBadgeIds => {
    for (final b in badges)
      if (b.earnedBy(stats)) b.id,
  };
}

/// Bugünkü hedefin bir adımı.
enum DailyTask {
  lesson('Günün dersi', Icons.school_rounded, '/lesson'),
  story('Günün hikayesi', Icons.auto_stories_rounded, '/story'),
  cards('Flash kart tekrarı', Icons.style_rounded, '/flashcards');

  const DailyTask(this.label, this.icon, this.route);

  final String label;
  final IconData icon;
  final String route;
}

/// Bugünkü hedef: hangi adımlar var, hangileri bitti.
class DailyGoal {
  const DailyGoal({required this.tasks, required this.done});

  /// Bugün geçerli adımlar (deste boşsa kart adımı yoktur).
  final List<DailyTask> tasks;
  final Set<DailyTask> done;

  int get doneCount => tasks.where(done.contains).length;
  double get progress => tasks.isEmpty ? 0 : doneCount / tasks.length;
  bool get complete => tasks.isNotEmpty && doneCount == tasks.length;

  /// Kullanıcının sıradaki adımı; hepsi bittiyse null.
  DailyTask? get next {
    for (final task in tasks) {
      if (!done.contains(task)) return task;
    }
    return null;
  }
}
