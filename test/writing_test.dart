import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/gemini_service.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/data/writing.dart';
import 'package:paceora/features/writing/writing_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

const _feedback = {
  'score': 72,
  'corrected': 'Yesterday I went to the park with my friends.',
  'issues': [
    {
      'original': 'I goed',
      'fix': 'I went',
      'explanationTr': 'go fiilinin geçmiş hali düzensizdir: went.',
      'type': 'grammar',
    },
    {
      'original': 'yok böyle bir parça',
      'fix': 'x',
      'explanationTr': '',
      'type': 'style',
    },
  ],
  'feedbackTr': 'Güzel başlangıç!',
};

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

void main() {
  group('markIssues', () {
    test('hataları metindeki yerinde işaretler, bulunamayanı atlar', () {
      final issues = WritingFeedback.tryParse(_feedback)!.issues;
      final spans = markIssues('Yesterday I goed to the park.', issues);
      expect(spans.map((s) => s.text).join(), 'Yesterday I goed to the park.');
      final marked = spans.where((s) => s.issue != null).toList();
      expect(marked, hasLength(1));
      expect(marked.single.text, 'I goed');
    });

    test('çakışan hatalar ikinci kez işaretlenmez', () {
      const a = WritingIssue(
        original: 'he go',
        fix: 'he goes',
        explanationTr: '',
        type: 'grammar',
      );
      const b = WritingIssue(
        original: 'go to',
        fix: 'goes to',
        explanationTr: '',
        type: 'grammar',
      );
      final spans = markIssues('Every day he go to school.', [a, b]);
      expect(spans.where((s) => s.issue != null), hasLength(1));
    });
  });

  test('yanıt ayrıştırılır; aynı ya da boş düzeltme atlanır', () {
    final f = WritingFeedback.tryParse({
      ..._feedback,
      'score': 140,
      'issues': [
        {'original': 'a', 'fix': 'a', 'explanationTr': '', 'type': 'x'},
        {'original': '', 'fix': 'b', 'explanationTr': '', 'type': 'x'},
      ],
    })!;
    expect(f.score, 100);
    expect(f.issues, isEmpty);
    expect(WritingFeedback.tryParse({'score': 'x'}), isNull);
    expect(parseWritingResponse(_envelope(_feedback))!.issues, hasLength(2));
  });

  test('kayıt sayıyı, XP\'yi ve en iyi puanı tutar', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    expect(await WritingRecords.save(prefs, 80), writingXp(80));
    await WritingRecords.save(prefs, 60);
    final r = WritingRecords.read(prefs);
    expect(r.count, 2);
    expect(r.bestScore, 80);
    expect(r.xp, writingXp(80) + writingXp(60));
  });

  testWidgets('yazı gönderilir, hatalar gösterilir ve deftere işlenir', (
    tester,
  ) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    await Repository(
      db,
    ).saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 15);
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    String? sent;
    final client = MockClient((request) async {
      sent = request.body;
      return http.Response.bytes(utf8.encode(_envelope(_feedback)), 200);
    });

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          databaseProvider.overrideWithValue(db),
          geminiServiceProvider.overrideWithValue(
            GeminiService(client: client, apiKey: 'test'),
          ),
        ],
        child: const MaterialApp(home: WritingScreen()),
      ),
    );
    await tester.pump();

    final button = find.widgetWithText(FilledButton, 'Düzelt');
    expect(tester.widget<FilledButton>(button).onPressed, isNull);
    await tester.enterText(
      find.byType(TextField),
      'Yesterday I goed to the park with my friends and we played.',
    );
    await tester.pump();
    await tester.tap(button);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }

    expect(sent, contains('I goed to the park'));
    expect(sent, isNot(contains('Efe')));
    expect(find.text('Güzel başlangıç!'), findsOneWidget);
    expect(find.textContaining('2 düzeltme'), findsOneWidget);
    expect(
      find.text('go fiilinin geçmiş hali düzensizdir: went.'),
      findsOneWidget,
    );
    final mistakes = await tester.runAsync(() => db.select(db.mistakes).get());
    expect(mistakes!.map((m) => m.item), contains('I went'));
    expect(mistakes.every((m) => m.type == 'writing'), isTrue);
    expect(WritingRecords.read(prefs).count, 1);
  });
}
