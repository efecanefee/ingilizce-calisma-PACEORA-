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

/// SM-2 algoritmasıyla bir sonraki tekrarı hesaplar.
///
/// - Bilinemeyen kart ([ReviewGrade.again]) baştan başlar ve ertesi gün sorulur.
/// - İlk başarılı tekrar 1 gün, ikincisi 6 gün sonra; sonrakiler önceki aralık
///   ile kolaylık katsayısının çarpımı kadar ileri atılır.
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
    newInterval = 1;
  } else {
    newReps = reps + 1;
    newInterval = switch (newReps) {
      1 => 1,
      2 => 6,
      _ => (intervalDays * newEase).round(),
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
