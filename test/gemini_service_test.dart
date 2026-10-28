import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/data/gemini_service.dart';

/// Gemini `generateContent` yanıtını taklit eder.
String _response(String modelText) => jsonEncode({
      'candidates': [
        {
          'content': {
            'parts': [
              {'text': modelText},
            ],
          },
        },
      ],
    });

const _sevenDays = '''
[
  {"grammarTopic": "Present Simple", "vocabTheme": "Günlük rutin"},
  {"grammarTopic": "Past Simple", "vocabTheme": "Seyahat"},
  {"grammarTopic": "Present Perfect", "vocabTheme": "Deneyimler"},
  {"grammarTopic": "Comparatives", "vocabTheme": "Alışveriş"},
  {"grammarTopic": "Future forms", "vocabTheme": "Planlar"},
  {"grammarTopic": "First conditional", "vocabTheme": "Hava durumu"},
  {"grammarTopic": "Tekrar", "vocabTheme": "Karışık"}
]
''';

void main() {
  group('parseWeeklyPlanResponse', () {
    test('düz JSON dizisini 7 güne çevirir', () {
      final days = parseWeeklyPlanResponse(_response(_sevenDays));

      expect(days, hasLength(7));
      expect(days.first.grammarTopic, 'Present Simple');
      expect(days.first.vocabTheme, 'Günlük rutin');
      expect(days.last.grammarTopic, 'Tekrar');
    });

    test('```json bloğuna sarılmış yanıtı da okur', () {
      final days = parseWeeklyPlanResponse(_response('```json\n$_sevenDays\n```'));

      expect(days, hasLength(7));
    });

    test('{"days": [...]} sarmalını kurtarır', () {
      final days = parseWeeklyPlanResponse(
        _response('{"days": $_sevenDays}'),
      );

      expect(days, hasLength(7));
    });

    test('boş alanlı günleri eler', () {
      final days = parseWeeklyPlanResponse(
        _response('''
[
  {"grammarTopic": "Present Simple", "vocabTheme": "Günlük rutin"},
  {"grammarTopic": "  ", "vocabTheme": "Seyahat"},
  {"grammarTopic": "Past Simple"}
]
'''),
      );

      expect(days, hasLength(1));
      expect(days.single.grammarTopic, 'Present Simple');
    });

    test('bozuk yanıtlarda boş liste döner, hata fırlatmaz', () {
      expect(parseWeeklyPlanResponse('bu JSON değil'), isEmpty);
      expect(parseWeeklyPlanResponse('{}'), isEmpty);
      expect(parseWeeklyPlanResponse(_response('yine JSON değil')), isEmpty);
      expect(parseWeeklyPlanResponse(jsonEncode({'candidates': <Object>[]})), isEmpty);
    });
  });

  group('fallbackWeeklyPlan', () {
    test('B1 ve B2 için 7 günlük farklı programlar verir', () {
      final b1 = fallbackWeeklyPlan('B1');
      final b2 = fallbackWeeklyPlan('B2');

      expect(b1, hasLength(7));
      expect(b2, hasLength(7));
      expect(b1.first.grammarTopic, isNot(b2.first.grammarTopic));
    });

    test('ara kademeler en yakın sete düşer', () {
      expect(
        fallbackWeeklyPlan('B2+').first.grammarTopic,
        fallbackWeeklyPlan('B2').first.grammarTopic,
      );
      expect(
        fallbackWeeklyPlan('B1-').first.grammarTopic,
        fallbackWeeklyPlan('B1').first.grammarTopic,
      );
    });
  });

  group('GeminiService', () {
    test('anahtar yokken ağa çıkmadan yedek programa düşer', () async {
      final service = GeminiService();
      addTearDown(service.dispose);
      expect(service.hasApiKey, isFalse,
          reason: 'test ortamında GEMINI_API_KEY tanımlı olmamalı');

      final result = await service.generateWeeklyPlan(
        name: 'Efecan',
        level: 'B2',
        dailyMinutes: 20,
      );

      expect(result.offline, isTrue);
      expect(result.error, contains('GEMINI_API_KEY'));
      expect(result.days, hasLength(7));
      expect(result.days.first.grammarTopic,
          fallbackWeeklyPlan('B2').first.grammarTopic);
    });
  });
}
