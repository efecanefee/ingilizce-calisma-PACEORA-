import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paceora/data/gemini_service.dart';
import 'package:paceora/data/roleplay.dart';

/// Kullanıcının adı Gemini'ye giden hiçbir isteğe girmemeli.
void main() {
  const secretName = 'Zeynepcik Gizliadsoyad';

  test('ad, Gemini isteklerinde yer almaz', () async {
    final bodies = <String>[];
    final client = MockClient((request) async {
      bodies.add(request.body);
      return http.Response.bytes(
        utf8.encode(jsonEncode({'candidates': <Object>[]})),
        200,
      );
    });
    final gemini = GeminiService(client: client, apiKey: 'test-key');

    await gemini.generateWeeklyPlan(
      name: secretName,
      level: 'B1',
      dailyMinutes: 15,
    );
    await gemini.generateDailyLesson(
      name: secretName,
      level: 'B1',
      dailyMinutes: 15,
      grammarTopic: 'Present perfect',
      vocabTheme: 'Seyahat',
    );
    await gemini.generateDailyStory(
      name: secretName,
      level: 'B1',
      dailyMinutes: 15,
      grammarTopic: 'Present perfect',
      vocabTheme: 'Seyahat',
    );
    await gemini.roleplayTurn(
      scenario: roleplayScenarios.first,
      level: 'B1',
      name: secretName,
      history: const [],
    );

    final generateCalls = bodies.where((b) => b.contains('contents'));
    expect(generateCalls, isNotEmpty);
    for (final body in bodies) {
      expect(body, isNot(contains('Zeynepcik')));
      expect(body, isNot(contains('Gizliadsoyad')));
    }
  });
}
