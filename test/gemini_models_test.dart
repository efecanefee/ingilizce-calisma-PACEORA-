import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paceora/app/constants.dart';
import 'package:paceora/data/gemini_models.dart';
import 'package:paceora/data/gemini_service.dart';

/// `generateContent` yanıt zarfı.
String _content(Object json) => jsonEncode({
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

/// `models.list` yanıtı.
String _modelList(List<String> names) => jsonEncode({
  'models': [
    for (final n in names)
      {
        'name': 'models/$n',
        'supportedGenerationMethods': ['generateContent', 'countTokens'],
      },
  ],
});

final _plan = [
  for (var i = 0; i < 7; i++)
    {'grammarTopic': 'Konu $i', 'vocabTheme': 'Tema $i'},
];

bool _isList(http.Request r) => r.method == 'GET';
String _modelOf(http.Request r) => r.url.pathSegments.last.split(':').first;

void main() {
  group('rankFlashModels', () {
    test('önce en yeni Flash-Lite, sonra en yeni Flash', () {
      expect(
        rankFlashModels([
          'models/gemini-2.5-flash',
          'models/gemini-3.8-flash',
          'models/gemini-3.5-flash-lite',
          'models/gemini-3.1-flash-lite',
          'models/gemini-3.6-flash',
        ]),
        [
          'gemini-3.5-flash-lite',
          'gemini-3.8-flash',
          'gemini-3.6-flash',
          'gemini-3.1-flash-lite',
          'gemini-2.5-flash',
        ],
      );
    });

    test('özel ve Flash olmayan modeller elenir', () {
      expect(
        rankFlashModels([
          'models/gemini-3.1-flash-image',
          'models/gemini-2.5-flash-preview-tts',
          'models/gemini-live-2.5-flash',
          'models/gemini-embedding-001',
          'models/gemini-3.5-pro',
          'models/gemini-3.8-flash',
        ]),
        ['gemini-3.8-flash'],
      );
    });

    test('kararlı sürüm önizlemeden önce gelir', () {
      expect(rankFlashModels(['gemini-3-flash-preview', 'gemini-2.5-flash']), [
        'gemini-2.5-flash',
        'gemini-3-flash-preview',
      ]);
    });

    test('model listesi yalnızca generateContent destekleyenleri okur', () {
      final body = jsonEncode({
        'models': [
          {
            'name': 'models/gemini-3.8-flash',
            'supportedGenerationMethods': ['generateContent'],
          },
          {
            'name': 'models/text-embedding',
            'supportedGenerationMethods': ['embedContent'],
          },
        ],
      });
      expect(parseModelList(body), ['models/gemini-3.8-flash']);
      expect(parseModelList('bozuk'), isEmpty);
    });
  });

  group('GeminiService model seçimi', () {
    test(
      'anahtarın eriştiği listeden model seçer, anahtar başlıkta gider',
      () async {
        final posted = <String>[];
        final service = GeminiService(
          apiKey: 'test-key',
          retryDelay: Duration.zero,
          client: MockClient((r) async {
            expect(r.headers['x-goog-api-key'], 'test-key');
            expect(r.url.queryParameters.containsKey('key'), isFalse);
            if (_isList(r)) {
              return http.Response(
                _modelList(['gemini-3.8-flash', 'gemini-3.5-flash-lite']),
                200,
              );
            }
            posted.add(_modelOf(r));
            return http.Response.bytes(utf8.encode(_content(_plan)), 200);
          }),
        );

        final result = await service.generateWeeklyPlan(
          level: 'B1',
          dailyMinutes: 10,
        );
        expect(result.offline, isFalse);
        expect(posted, ['gemini-3.5-flash-lite']);
      },
    );

    test('404 dönen model atlanır, 503 bir kez yeniden denenir', () async {
      final posted = <String>[];
      final service = GeminiService(
        apiKey: 'k',
        retryDelay: Duration.zero,
        client: MockClient((r) async {
          if (_isList(r)) {
            return http.Response(
              _modelList([
                'gemini-3.5-flash-lite',
                'gemini-3.8-flash',
                'gemini-3.1-flash-lite',
              ]),
              200,
            );
          }
          final model = _modelOf(r);
          posted.add(model);
          return switch (model) {
            'gemini-3.5-flash-lite' => http.Response('gone', 404),
            'gemini-3.8-flash' => http.Response('overloaded', 503),
            _ => http.Response.bytes(utf8.encode(_content(_plan)), 200),
          };
        }),
      );

      final result = await service.generateWeeklyPlan(
        level: 'B1',
        dailyMinutes: 10,
      );
      expect(result.offline, isFalse);
      expect(posted, [
        'gemini-3.5-flash-lite',
        'gemini-3.8-flash',
        'gemini-3.8-flash',
        'gemini-3.1-flash-lite',
      ]);
    });

    test('zaman aşımında sıradaki modele geçer', () async {
      final posted = <String>[];
      final service = GeminiService(
        apiKey: 'k',
        retryDelay: Duration.zero,
        client: MockClient((r) async {
          if (_isList(r)) {
            return http.Response(
              _modelList(['gemini-3.5-flash-lite', 'gemini-3.8-flash']),
              200,
            );
          }
          posted.add(_modelOf(r));
          if (_modelOf(r) == 'gemini-3.5-flash-lite') {
            throw TimeoutException('yavaş');
          }
          return http.Response.bytes(utf8.encode(_content(_plan)), 200);
        }),
      );

      final result = await service.generateWeeklyPlan(
        level: 'B1',
        dailyMinutes: 10,
      );
      expect(result.offline, isFalse);
      expect(posted, ['gemini-3.5-flash-lite', 'gemini-3.8-flash']);
    });

    test('düşünme ayarı tanınmazsa ayarsız tekrar gönderilir', () async {
      final configs = <Map<String, dynamic>>[];
      final service = GeminiService(
        apiKey: 'k',
        retryDelay: Duration.zero,
        client: MockClient((r) async {
          if (_isList(r)) {
            return http.Response(_modelList(['gemini-3.8-flash']), 200);
          }
          final config =
              (jsonDecode(r.body) as Map<String, dynamic>)['generationConfig']
                  as Map<String, dynamic>;
          configs.add(config);
          return config.containsKey('thinkingConfig')
              ? http.Response('Unknown name "thinkingConfig"', 400)
              : http.Response.bytes(utf8.encode(_content(_plan)), 200);
        }),
      );

      final result = await service.generateWeeklyPlan(
        level: 'B1',
        dailyMinutes: 10,
      );
      expect(result.offline, isFalse);
      expect(configs.first['thinkingConfig'], {'thinkingLevel': 'low'});
      expect(configs.last.containsKey('thinkingConfig'), isFalse);
    });

    test('anahtar hatasında başka model denenmez', () async {
      var posts = 0;
      final service = GeminiService(
        apiKey: 'bozuk',
        retryDelay: Duration.zero,
        client: MockClient((r) async {
          if (_isList(r)) return http.Response('bad key', 400);
          posts++;
          return http.Response('bad key', 400);
        }),
      );

      final result = await service.generateWeeklyPlan(
        level: 'B1',
        dailyMinutes: 10,
      );
      expect(result.offline, isTrue);
      expect(result.error, contains('400'));
      expect(posts, 1);
    });

    test('liste alınamazsa yerleşik yedek modeller denenir', () async {
      final posted = <String>[];
      final service = GeminiService(
        apiKey: 'k',
        retryDelay: Duration.zero,
        client: MockClient((r) async {
          if (_isList(r)) return http.Response('down', 500);
          posted.add(_modelOf(r));
          return http.Response.bytes(utf8.encode(_content(_plan)), 200);
        }),
      );

      await service.generateWeeklyPlan(
        level: 'B1',
        dailyMinutes: 10,
      );
      expect(posted, [AppConstants.geminiFallbackModels.first]);
    });
  });

  group('testConnection', () {
    test('başarılı bağlantıyı model ve süreyle raporlar', () async {
      final service = GeminiService(
        apiKey: 'k',
        retryDelay: Duration.zero,
        client: MockClient((r) async {
          if (_isList(r)) {
            return http.Response(_modelList(['gemini-3.5-flash-lite']), 200);
          }
          return http.Response.bytes(utf8.encode(_content({'ok': true})), 200);
        }),
      );

      final report = await service.testConnection();
      expect(report.ok, isTrue);
      expect(report.model, 'gemini-3.5-flash-lite');
      expect(report.listedFromApi, isTrue);
      expect(report.elapsed, isNotNull);
      expect(report.error, isNull);
    });

    test('geçersiz anahtarı açıkça bildirir', () async {
      final service = GeminiService(
        apiKey: 'bozuk',
        client: MockClient((r) async => http.Response('denied', 403)),
      );

      final report = await service.testConnection();
      expect(report.ok, isFalse);
      expect(report.error, contains('403'));
    });

    test('anahtar yoksa istek atılmaz', () async {
      var calls = 0;
      final service = GeminiService(
        apiKey: '',
        client: MockClient((r) async {
          calls++;
          return http.Response('', 200);
        }),
      );
      expect((await service.testConnection()).ok, isFalse);
      expect(calls, 0);
    });
  });
}
