import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paceora/app/translate_help.dart';
import 'package:paceora/data/gemini_service.dart';
import 'package:paceora/data/lesson_models.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/translation.dart';
import 'package:paceora/features/lesson/lesson_steps.dart';
import 'package:shared_preferences/shared_preferences.dart';

String _envelope(Object json) => jsonEncode({
  'candidates': [
    {
      'content': {
        'parts': [
          {'text': jsonEncode(json)},
        ],
      },
    },
  ],
});

Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  late SharedPreferences prefs;
  var requests = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    requests = 0;
  });

  Widget app(Widget child) => ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      geminiServiceProvider.overrideWithValue(
        GeminiService(
          apiKey: 'test',
          client: MockClient((request) async {
            if (request.method == 'POST') requests++;
            return http.Response.bytes(
              utf8.encode(_envelope({'tr': 'Dün parka gittim.'})),
              200,
            );
          }),
        ),
      ),
    ],
    child: MaterialApp(
      home: Scaffold(body: SingleChildScrollView(child: child)),
    ),
  );

  testWidgets('dersin kendi Türkçesi varsa yapay zekaya sorulmaz', (
    tester,
  ) async {
    await tester.pumpWidget(
      app(const TranslateHelp(english: 'I went.', known: 'Gittim.')),
    );
    expect(find.text('Gittim.'), findsNothing);
    await tester.tap(find.text('Türkçesi'));
    await _advance(tester);
    expect(find.text('Gittim.'), findsOneWidget);
    expect(requests, 0);
    await tester.tap(find.text('Gizle'));
    await _advance(tester);
    expect(find.text('Gittim.'), findsNothing);
  });

  testWidgets('Türkçesi yoksa yapay zeka çevirir ve saklanır', (tester) async {
    await tester.pumpWidget(
      app(const TranslateHelp(english: 'I went to the park yesterday.')),
    );
    await tester.tap(find.text('Türkçesi'));
    await _advance(tester);
    expect(find.text('Dün parka gittim.'), findsOneWidget);
    expect(requests, 1);
    expect(
      TranslationCache(prefs).get('I went to the park yesterday.'),
      'Dün parka gittim.',
    );
  });

  test('önbellek en eski kayıtları atar', () async {
    final cache = TranslationCache(prefs);
    for (var i = 0; i < TranslationCache.maxEntries + 5; i++) {
      await cache.put('en $i', 'tr $i');
    }
    expect(cache.get('en 0'), isNull);
    expect(cache.get('en ${TranslationCache.maxEntries + 4}'), isNotNull);
  });

  testWidgets('çeviri sorusunda ipucu: kelime kutusu, sonra cümlenin başı', (
    tester,
  ) async {
    String? submitted;
    await tester.pumpWidget(
      app(
        TranslateQuestionCard(
          number: 1,
          item: const TranslateItem(
            tr: 'Dün parka gittim.',
            en: 'I went to the park yesterday.',
            accepted: [],
          ),
          given: null,
          correct: false,
          onSubmit: (v) => submitted = v,
        ),
      ),
    );
    await tester.tap(find.text('İpucu'));
    await _advance(tester);
    for (final w in ['I', 'went', 'to', 'the', 'park', 'yesterday']) {
      expect(find.widgetWithText(ActionChip, w), findsOneWidget, reason: w);
    }
    await tester.tap(find.widgetWithText(ActionChip, 'went'));
    await tester.pump();
    expect(find.text('went '), findsOneWidget);

    await tester.tap(find.text('Biraz daha yardım'));
    await _advance(tester);
    final field = tester.widget<TextField>(find.byType(TextField));
    expect(field.controller!.text, 'I went to ');
    expect(find.text('Biraz daha yardım'), findsNothing);

    await tester.enterText(
      find.byType(TextField),
      'I went to the park yesterday',
    );
    await tester.tap(find.text('Kontrol et'));
    expect(submitted, 'I went to the park yesterday');
  });
}
