import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/review_models.dart';

WeeklyStats _stats({
  int days = 5,
  int lessons = 4,
  double? average = 90,
  double? storyAverage,
  int stories = 0,
  int openMistakes = 0,
}) =>
    WeeklyStats(
      weekStart: DateTime(2026, 10, 26),
      daysCompleted: days,
      lessonsCompleted: lessons,
      averageLessonScore: average,
      studyMinutes: 60,
      storiesRead: stories,
      averageStoryScore: storyAverage,
      cardsReviewed: 30,
      openMistakes: openMistakes,
      topMistakes: const ['make a decision', 'used to'],
    );

void main() {
  group('recommendLevelDelta', () {
    test('yüksek ve yeterli sayıda skor bir kademe yükseltir', () {
      expect(recommendLevelDelta(_stats()), 1);
    });

    test('tek iyi ders yükseltmeye yetmez', () {
      expect(recommendLevelDelta(_stats(lessons: 2, average: 100)), 0);
    });

    test('okuma testi zayıfsa yükseltme yapılmaz', () {
      expect(
        recommendLevelDelta(_stats(stories: 2, storyAverage: 50)),
        0,
      );
    });

    test('düşük ortalama bir kademe düşürür', () {
      expect(recommendLevelDelta(_stats(lessons: 3, average: 40)), -1);
    });

    test('ders yoksa öneri yok', () {
      expect(recommendLevelDelta(_stats(lessons: 0, average: null)), 0);
    });

    test('orta skorlar seviyeyi korur', () {
      expect(recommendLevelDelta(_stats(average: 70)), 0);
    });
  });

  group('shiftLevel', () {
    test('kademe kademe ilerler', () {
      expect(shiftLevel('B1+', 1), 'B2-');
      expect(shiftLevel('B2-', -1), 'B1+');
    });

    test('uçlarda sınırda kalır', () {
      expect(shiftLevel('B2+', 1), 'B2+');
      expect(shiftLevel('B1-', -1), 'B1-');
    });
  });

  test('yerel yorum her zaman dolu döner', () {
    final empty = localCommentary(
      _stats(days: 0, lessons: 0, average: null),
      0,
    );
    expect(empty.summary, isNotEmpty);
    expect(empty.strengths, isNotEmpty);
    expect(empty.focus, isNotEmpty);

    final busy = localCommentary(_stats(openMistakes: 2), 1);
    expect(busy.focus.join(' '), contains('make a decision'));
    expect(busy.tip, contains('zorlaştır'));
  });

  test('rapor JSON üzerinden kayıpsız geri okunur', () {
    final report = WeeklyReport(
      stats: _stats(storyAverage: 75, stories: 1),
      summary: 'Harika bir hafta.',
      strengths: const ['Düzenli'],
      focus: const ['Okuma'],
      tip: 'Devam et.',
      fromLevel: 'B1',
      suggestedLevel: 'B1+',
      offline: true,
    );
    final decoded = WeeklyReport.decode(report.copyWith(applied: true).encode())!;

    expect(decoded.summary, report.summary);
    expect(decoded.stats.averageStoryScore, 75);
    expect(decoded.stats.topMistakes, report.stats.topMistakes);
    expect(decoded.suggestsChange, isTrue);
    expect(decoded.applied, isTrue);
    expect(decoded.offline, isTrue);
  });

  test('Gemini rapor yanıtı ayrıştırılır, bozuksa null', () {
    String envelope(String text) => jsonEncode({
          'candidates': [
            {
              'content': {
                'parts': [
                  {'text': text},
                ],
              },
            },
          ],
        });

    final parsed = parseReportResponse(envelope(jsonEncode({
      'summary': 'İyi iş.',
      'strengths': ['Seri'],
      'focus': ['Kelime'],
      'tip': 'Her gün 5 dk.',
    })));
    expect(parsed?.summary, 'İyi iş.');
    expect(parsed?.strengths, ['Seri']);

    expect(parseReportResponse(envelope('{"summary": ""}')), isNull);
    expect(parseReportResponse('bozuk'), isNull);
  });
}
