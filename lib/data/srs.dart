import 'dart:math';

import 'repository.dart';

/// Flash kart değerlendirmesinde kullanıcının verdiği not.
///
/// SM-2'nin 0-5 ölçeği dört düğmeye indirildi; [quality] algoritmaya giden
/// değerdir. 3'ün altı "bilemedim" sayılır ve kart baştan öğrenilir.
enum ReviewGrade {
  again(1, 'Tekrar'),
  hard(3, 'Zor'),
  good(4, 'İyi'),
  easy(5, 'Kolay');

  const ReviewGrade(this.quality, this.label);

  final int quality;
  final String label;
}

/// Bir kartın aralıklı tekrar durumu.
class SrsSchedule {
  const SrsSchedule({
    required this.ease,
    required this.intervalDays,
    required this.reps,
    required this.dueDate,
  });

  /// Kolaylık katsayısı; SM-2'de 1.3'ün altına inmez.
  final double ease;
  final int intervalDays;

  /// Üst üste başarılı tekrar sayısı.
  final int reps;

  /// Kartın yeniden sorulacağı gün (00:00).
  final DateTime dueDate;
}

/// SM-2 en düşük kolaylık katsayısı.
const minEase = 1.3;

/// SM-2 temelli, notlara göre ayrışan tekrar aralığı.
///
/// - "Tekrar": kart baştan başlar ve bugün yeniden sorulur (0 gün).
/// - İlk tekrar: Zor 1, İyi 3, Kolay 5 gün. İkinci: Zor 3, İyi 6, Kolay 9.
/// - Sonrakiler: Zor ×1.2, İyi ×katsayı, Kolay ×katsayı×1.3.
/// - Aralıklar her zaman Zor < İyi < Kolay sırasındadır; klasik SM-2'de yeni
///   kartta hepsi 1 gündü ve not vermenin bir farkı görünmüyordu.
/// - Kolaylık katsayısı her notta güncellenir: "Zor" düşürür, "Kolay" artırır.
SrsSchedule nextSchedule({
  required double ease,
  required int intervalDays,
  required int reps,
  required ReviewGrade grade,
  required DateTime today,
}) {
  final q = grade.quality;
  final newEase = (ease + (0.1 - (5 - q) * (0.08 + (5 - q) * 0.02)))
      .clamp(minEase, double.infinity)
      .toDouble();

  final int newReps;
  final int newInterval;
  if (q < 3) {
    newReps = 0;
    newInterval = 0;
  } else {
    newReps = reps + 1;
    final step = q - 3; // 0: Zor, 1: İyi, 2: Kolay
    newInterval = switch (newReps) {
      1 => const [1, 3, 5][step],
      2 => const [3, 6, 9][step],
      _ => () {
        // Eski kayıtlardaki kısa aralıklar da sıralı kalsın diye taban var.
        final base = intervalDays < 1 ? 1 : intervalDays;
        final hard = max(base + 1, (base * 1.2).round());
        final good = max(hard + 1, (base * newEase).round());
        final easy = max(good + 1, (base * newEase * 1.3).round());
        return [hard, good, easy][step];
      }(),
    };
  }

  final day = dayOf(today);
  return SrsSchedule(
    ease: newEase,
    intervalDays: newInterval,
    reps: newReps,
    dueDate: DateTime(day.year, day.month, day.day + newInterval),
  );
}
