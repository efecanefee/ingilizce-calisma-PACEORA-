import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../app/constants.dart';
import 'level_check.dart';
import 'placement.dart';

/// Seviye atlama sınavı: bir üst kademeden 10 soru. Geçen bir üst kademeye
/// geçebilir.
///
/// Sorular seviye testinin soru bankasından gelir (dinleme hariç: sınav
/// sessiz ortamda da çözülebilsin); yetmezse kademenin kontrol soruları
/// eklenir.
const levelExamQuestionCount = 10;

/// Geçme sınırı: soruların %70'i.
int levelExamPassMark(int questionCount) => (questionCount * 0.7).ceil();

/// Sınavın hedef kademesi; en üst kademedeyse null.
DifficultyLevel? levelExamTarget(DifficultyLevel current) {
  final next = current.step(1);
  return next == current ? null : next;
}

List<PlacementQuestion> drawLevelExam(
  PlacementBank bank,
  DifficultyLevel target, [
  Random? random,
]) {
  final rng = random ?? Random();
  final upper = target.step(1);
  final pool =
      bank.questions
          .where(
            (q) =>
                (q.level == target || q.level == upper) &&
                q.skill != PlacementSkill.listening,
          )
          .toList()
        ..shuffle(rng);
  // Hedef kademenin soruları önce gelsin; üst kademe yalnızca tamamlar.
  pool.sort(
    (a, b) => (a.level == target ? 0 : 1).compareTo(b.level == target ? 0 : 1),
  );
  final picked = <PlacementQuestion>[];
  final topics = <String, int>{};
  for (final q in pool) {
    if (picked.length >= levelExamQuestionCount) break;
    // Aynı konudan en çok iki soru.
    if (q.topic.isNotEmpty && (topics[q.topic] ?? 0) >= 2) continue;
    picked.add(q);
    if (q.topic.isNotEmpty) topics[q.topic] = (topics[q.topic] ?? 0) + 1;
  }
  for (final q in LevelPreview.of(target).questions) {
    if (picked.length >= levelExamQuestionCount) break;
    if (!picked.contains(q)) picked.add(q);
  }
  return picked..shuffle(rng);
}

/// Son sınav tarihi (SharedPreferences). Ana ekrandaki öneri kartı sınav
/// yapıldıktan sonra bir süre görünmez.
const levelExamAtKey = 'level_exam_at';

/// Ana ekranda sınav önerilsin mi? Programın 4. haftasından itibaren ve son
/// sınavdan 3 hafta geçtiyse.
bool shouldOfferLevelExam({
  required SharedPreferences prefs,
  required DifficultyLevel level,
  required int weekNumber,
  required DateTime now,
}) {
  if (levelExamTarget(level) == null || weekNumber < 4) return false;
  final last = DateTime.tryParse(prefs.getString(levelExamAtKey) ?? '');
  return last == null || now.difference(last).inDays >= 21;
}
