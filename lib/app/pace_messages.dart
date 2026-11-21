import '../data/streak_freeze.dart';

/// Pace'in ana ekrandaki konuşma balonu için kısa mesaj.
///
/// Serinin durumuna, günün saatine ve yaklaşan seri hedefine göre seçilir.
/// Aynı gün içinde mesaj değişmez (günün sırasına göre döner), ertesi gün
/// farklı bir cümle gelir.
String paceMessage({
  required StreakStatus status,
  required int streak,
  required DateTime now,
}) {
  final rotation = now.difference(DateTime(now.year)).inDays;
  String pick(List<String> options) => options[rotation % options.length];

  switch (status) {
    case StreakStatus.done:
      return pick([
        'Bugünü tamamladın, harikasın! Yarın görüşürüz.',
        'Serin $streak gün oldu. Böyle devam!',
        'Bugünlük bu kadar. İstersen kartlarla biraz tekrar yap.',
      ]);
    case StreakStatus.protected:
      return 'Dün kaçırdın ama hakların serini koruyor. Bugün çalışalım!';
    case StreakStatus.broken:
      return pick([
        'Yeni bir seri başlatmak için harika bir gün.',
        'Her uzun seri tek bir günle başlar. Hadi başlayalım!',
      ]);
    case StreakStatus.pending:
      break;
  }

  // Bugün henüz çalışılmadı.
  final next = streakMilestone(streak).to;
  if (streak > 0 && next - streak == 1) {
    return 'Bugün çalışırsan $next günlük seriye ulaşıyorsun!';
  }
  final hour = now.hour;
  if (hour < 5) return 'Geç oldu; kısa bir ders yapıp dinlenebilirsin.';
  if (hour < 12) {
    return pick([
      'Günaydın! Bugünkü dersin hazır.',
      'Güne İngilizceyle başlamaya ne dersin?',
    ]);
  }
  if (hour < 18) {
    return pick([
      'Kısa bir ders öğleden sonrayı canlandırır.',
      'Birkaç dakikan varsa bugünün dersine bakalım.',
    ]);
  }
  return streak > 0
      ? 'Gün bitmeden dersini yapalım, serin $streak gün!'
      : 'Gün bitmeden kısa bir ders yapalım mı?';
}
