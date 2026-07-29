import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app/constants.dart';
import 'repository.dart';

/// Haftalık plan üretiminin sonucu.
///
/// [offline] true ise plan Gemini'den değil, yerleşik yedek programdan geldi
/// (anahtar yok, ağ hatası veya bozuk yanıt). Arayüz bunu kullanıcıya belli eder.
class WeeklyPlanResult {
  const WeeklyPlanResult({required this.days, required this.offline, this.error});

  final List<PlanDaySpec> days;
  final bool offline;
  final String? error;
}

/// Gemini ile içerik üretimi.
///
/// Anahtar derleme zamanında verilir:
/// `flutter run -d windows --dart-define-from-file=env.json`
class GeminiService {
  GeminiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  bool get hasApiKey => AppConstants.geminiApiKey.isNotEmpty;

  void dispose() => _client.close();

  /// Kullanıcının seviyesine göre 7 günlük çalışma programı üretir.
  ///
  /// Hiçbir koşulda hata fırlatmaz — başarısızlıkta [fallbackWeeklyPlan]
  /// döner, böylece onboarding akışı kilitlenmez.
  Future<WeeklyPlanResult> generateWeeklyPlan({
    required String name,
    required String level,
    required int dailyMinutes,
  }) async {
    if (!hasApiKey) {
      return WeeklyPlanResult(
        days: fallbackWeeklyPlan(level),
        offline: true,
        error: 'GEMINI_API_KEY tanımlı değil',
      );
    }

    final uri = Uri.parse(
      '${AppConstants.geminiBaseUrl}/${AppConstants.geminiModel}:generateContent'
      '?key=${AppConstants.geminiApiKey}',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': _prompt(name: name, level: level, dailyMinutes: dailyMinutes)},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': _planSchema,
        'temperature': 1.0,
      },
    });

    try {
      final response = await _client
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        return WeeklyPlanResult(
          days: fallbackWeeklyPlan(level),
          offline: true,
          error: 'Gemini ${response.statusCode}',
        );
      }

      final days = parseWeeklyPlanResponse(utf8.decode(response.bodyBytes));
      if (days.length != 7) {
        return WeeklyPlanResult(
          days: fallbackWeeklyPlan(level),
          offline: true,
          error: 'Yanıt 7 gün içermiyor',
        );
      }
      return WeeklyPlanResult(days: days, offline: false);
    } catch (e) {
      return WeeklyPlanResult(
        days: fallbackWeeklyPlan(level),
        offline: true,
        error: e.toString(),
      );
    }
  }

  String _prompt({
    required String name,
    required String level,
    required int dailyMinutes,
  }) {
    return '''
Sen bir İngilizce öğretmenisin. Türkçe konuşan bir öğrenci için haftalık çalışma programı hazırlıyorsun.

Öğrenci: $name
CEFR seviyesi: $level
Günlük çalışma süresi: $dailyMinutes dakika

Pazartesiden pazara 7 günlük bir program üret. Her gün için:
- grammarTopic: O günün dilbilgisi konusu. İngilizce konu adı, seviyeye uygun (örn. "Present Perfect vs Past Simple").
- vocabTheme: O günün kelime teması. TÜRKÇE yazılmış kısa bir tema (örn. "Seyahat ve ulaşım").

Kurallar:
- Konular hafta boyunca birbirini tamamlasın, kolaydan zora ilerlesin.
- Aynı konu iki kez tekrar etmesin.
- 7. gün (pazar) haftanın tekrarı olsun.
- $dailyMinutes dakikada bitirilebilecek kapsamda tut.
''';
  }

  static const Map<String, dynamic> _planSchema = {
    'type': 'ARRAY',
    'items': {
      'type': 'OBJECT',
      'properties': {
        'grammarTopic': {'type': 'STRING'},
        'vocabTheme': {'type': 'STRING'},
      },
      'required': ['grammarTopic', 'vocabTheme'],
    },
  };
}

/// Gemini `generateContent` yanıtını [PlanDaySpec] listesine çevirir.
///
/// Yanıt beklenen biçimde değilse boş liste döner — çağıran taraf bunu
/// yedek programa geçiş sinyali olarak kullanır.
List<PlanDaySpec> parseWeeklyPlanResponse(String responseBody) {
  try {
    final decoded = jsonDecode(responseBody) as Map<String, dynamic>;
    final candidates = decoded['candidates'] as List<dynamic>?;
    if (candidates == null || candidates.isEmpty) return const [];

    final parts = ((candidates.first as Map<String, dynamic>)['content']
        as Map<String, dynamic>?)?['parts'] as List<dynamic>?;
    if (parts == null || parts.isEmpty) return const [];

    final text = (parts.first as Map<String, dynamic>)['text'] as String?;
    if (text == null || text.trim().isEmpty) return const [];

    final raw = jsonDecode(_stripCodeFence(text));
    // responseSchema bir dizi istiyor; yine de nesne sarmalı gelirse kurtar.
    final list = switch (raw) {
      List<dynamic> l => l,
      Map<String, dynamic> m => m['days'] as List<dynamic>? ?? const [],
      _ => const [],
    };

    return [
      for (final item in list)
        if (item is Map<String, dynamic>)
          PlanDaySpec(
            grammarTopic: (item['grammarTopic'] as String?)?.trim() ?? '',
            vocabTheme: (item['vocabTheme'] as String?)?.trim() ?? '',
          ),
    ].where((d) => d.grammarTopic.isNotEmpty && d.vocabTheme.isNotEmpty).toList();
  } catch (_) {
    return const [];
  }
}

/// Model bazen JSON'u ```json ... ``` bloğuna sarar; sarmalı temizler.
String _stripCodeFence(String text) {
  final trimmed = text.trim();
  if (!trimmed.startsWith('```')) return trimmed;
  final withoutOpen = trimmed.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
  return withoutOpen.replaceFirst(RegExp(r'```\s*$'), '').trim();
}

/// API erişimi olmadığında kullanılan yerleşik haftalık program.
///
/// B1 ve B2 için ayrı iki set; ara kademeler (B1-, B1+) en yakın sete düşer.
List<PlanDaySpec> fallbackWeeklyPlan(String levelCode) {
  final isB2 = levelCode.startsWith('B2');
  return isB2 ? _fallbackB2 : _fallbackB1;
}

const _fallbackB1 = <PlanDaySpec>[
  PlanDaySpec(
    grammarTopic: 'Present Simple vs Present Continuous',
    vocabTheme: 'Günlük rutin ve ev işleri',
  ),
  PlanDaySpec(
    grammarTopic: 'Past Simple: regular & irregular verbs',
    vocabTheme: 'Seyahat ve ulaşım',
  ),
  PlanDaySpec(
    grammarTopic: 'Present Perfect: ever, never, just, already',
    vocabTheme: 'Deneyimler ve hobiler',
  ),
  PlanDaySpec(
    grammarTopic: 'Comparatives and superlatives',
    vocabTheme: 'Şehir hayatı ve alışveriş',
  ),
  PlanDaySpec(
    grammarTopic: 'Future forms: will, going to, present continuous',
    vocabTheme: 'Planlar ve randevular',
  ),
  PlanDaySpec(
    grammarTopic: 'First conditional',
    vocabTheme: 'Hava durumu ve doğa',
  ),
  PlanDaySpec(
    grammarTopic: 'Haftanın tekrarı: karışık zaman alıştırmaları',
    vocabTheme: 'Hafta boyunca öğrenilen kelimeler',
  ),
];

const _fallbackB2 = <PlanDaySpec>[
  PlanDaySpec(
    grammarTopic: 'Present Perfect Continuous vs Present Perfect',
    vocabTheme: 'İş hayatı ve kariyer',
  ),
  PlanDaySpec(
    grammarTopic: 'Past Perfect and narrative tenses',
    vocabTheme: 'Haberler ve güncel olaylar',
  ),
  PlanDaySpec(
    grammarTopic: 'Passive voice in all tenses',
    vocabTheme: 'Bilim ve teknoloji',
  ),
  PlanDaySpec(
    grammarTopic: 'Second and third conditionals',
    vocabTheme: 'Pişmanlıklar ve varsayımlar',
  ),
  PlanDaySpec(
    grammarTopic: 'Reported speech',
    vocabTheme: 'Tartışma ve fikir belirtme',
  ),
  PlanDaySpec(
    grammarTopic: 'Relative clauses: defining & non-defining',
    vocabTheme: 'Sağlık ve yaşam tarzı',
  ),
  PlanDaySpec(
    grammarTopic: 'Haftanın tekrarı: karışık yapı alıştırmaları',
    vocabTheme: 'Hafta boyunca öğrenilen kelimeler',
  ),
];
