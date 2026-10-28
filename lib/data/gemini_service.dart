import 'dart:convert';

import 'package:http/http.dart' as http;

import '../app/constants.dart';
import 'gemini_json.dart';
import 'lesson_models.dart';
import 'repository.dart';
import 'review_models.dart';
import 'story_models.dart';

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

/// Günlük ders üretiminin sonucu.
///
/// Haftalık planın aksine dersin gömülü yedeği yok: her konu için hazır içerik
/// taşımak gerçekçi değil. Üretilemezse [lesson] null kalır ve arayüz kullanıcıya
/// "tekrar dene" ile "günü elle işaretle" seçeneklerini sunar.
class DailyLessonResult {
  const DailyLessonResult({this.lesson, this.error});

  final DailyLesson? lesson;
  final String? error;

  bool get isSuccess => lesson != null;
}

/// Gemini ile içerik üretimi.
///
/// [apiKey] varsayılan olarak derleme zamanında verilen anahtardır
/// (`--dart-define-from-file=env.json`), ancak kullanıcı Ayarlar'dan kendi
/// anahtarını girerse `geminiServiceProvider` onu geçirir.
class GeminiService {
  GeminiService({http.Client? client, String? apiKey})
      : _client = client ?? http.Client(),
        _apiKey = (apiKey ?? AppConstants.geminiApiKey).trim();

  final http.Client _client;
  final String _apiKey;

  bool get hasApiKey => _apiKey.isNotEmpty;

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
    final response = await _post(
      prompt: _planPrompt(name: name, level: level, dailyMinutes: dailyMinutes),
      schema: _planSchema,
      timeout: const Duration(seconds: 30),
    );

    if (response.body == null) {
      return WeeklyPlanResult(
        days: fallbackWeeklyPlan(level),
        offline: true,
        error: response.error,
      );
    }

    final days = parseWeeklyPlanResponse(response.body!);
    if (days.length != 7) {
      return WeeklyPlanResult(
        days: fallbackWeeklyPlan(level),
        offline: true,
        error: 'Yanıt 7 gün içermiyor',
      );
    }
    return WeeklyPlanResult(days: days, offline: false);
  }

  /// Günün konusundan çok adımlı bir ders üretir.
  ///
  /// [reviewItems] daha önce yanlış yapılıp henüz çözülmemiş kelime/kalıplardır;
  /// modele verilerek dersin bir kısmının bunların tekrarına ayrılması sağlanır.
  Future<DailyLessonResult> generateDailyLesson({
    required String name,
    required String level,
    required int dailyMinutes,
    required String grammarTopic,
    required String vocabTheme,
    List<String> reviewItems = const [],
  }) async {
    final response = await _post(
      prompt: _lessonPrompt(
        name: name,
        level: level,
        dailyMinutes: dailyMinutes,
        grammarTopic: grammarTopic,
        vocabTheme: vocabTheme,
        reviewItems: reviewItems,
      ),
      schema: _lessonSchema,
      // Ders plandan çok daha büyük bir yanıt; daha uzun süre tanınıyor.
      timeout: const Duration(seconds: 60),
      temperature: 0.9,
    );

    if (response.body == null) return DailyLessonResult(error: response.error);

    final lesson = parseDailyLessonResponse(response.body!);
    if (lesson == null) {
      return const DailyLessonResult(error: 'Ders içeriği okunamadı');
    }
    return DailyLessonResult(lesson: lesson);
  }

  /// Günün temasında kısa bir hikaye ve okuduğunu anlama soruları üretir.
  ///
  /// Hiçbir koşulda hata fırlatmaz: üretilemezse yerleşik yedek hikaye döner
  /// ve `offline` true olur, böylece çevrimdışıyken de okuma yapılabilir.
  Future<({DailyStory story, bool offline})> generateDailyStory({
    required String name,
    required String level,
    required int dailyMinutes,
    required String grammarTopic,
    required String vocabTheme,
    List<String> targetWords = const [],
    DateTime? date,
  }) async {
    final response = await _post(
      prompt: _storyPrompt(
        name: name,
        level: level,
        dailyMinutes: dailyMinutes,
        grammarTopic: grammarTopic,
        vocabTheme: vocabTheme,
        targetWords: targetWords,
      ),
      schema: _storySchema,
      timeout: const Duration(seconds: 45),
      temperature: 1.0,
    );

    final story =
        response.body == null ? null : parseDailyStoryResponse(response.body!);
    if (story == null) {
      return (story: fallbackStory(level, date ?? DateTime.now()), offline: true);
    }
    return (story: story, offline: false);
  }

  /// Haftanın istatistiklerinden Türkçe değerlendirme yorumu üretir.
  ///
  /// Seviye önerisi burada verilmez; [recommendLevelDelta] cihazda hesaplar ve
  /// modele yalnızca bilgi olarak geçilir. Ulaşılamazsa yerel şablon kullanılır.
  Future<({ReportCommentary commentary, bool offline})> generateWeeklyReport({
    required String name,
    required String level,
    required WeeklyStats stats,
    required int levelDelta,
  }) async {
    final response = await _post(
      prompt: _reportPrompt(
        name: name,
        level: level,
        stats: stats,
        levelDelta: levelDelta,
      ),
      schema: _reportSchema,
      timeout: const Duration(seconds: 30),
      temperature: 0.7,
    );

    final commentary =
        response.body == null ? null : parseReportResponse(response.body!);
    if (commentary == null) {
      return (commentary: localCommentary(stats, levelDelta), offline: true);
    }
    return (commentary: commentary, offline: false);
  }

  String _storyPrompt({
    required String name,
    required String level,
    required int dailyMinutes,
    required String grammarTopic,
    required String vocabTheme,
    required List<String> targetWords,
  }) {
    final length = switch (dailyMinutes) {
      <= 10 => '120-170',
      <= 15 => '170-230',
      _ => '230-300',
    };
    final words = targetWords.isEmpty
        ? ''
        : '\nHikayede şu kelimelerden olabildiğince çoğunu doğal biçimde kullan: '
            '${targetWords.join(", ")}.\n';

    return '''
Sen bir İngilizce öğretmenisin. Türkçe konuşan bir öğrenci için kısa bir okuma parçası hazırlıyorsun.

Öğrenci: $name
CEFR seviyesi: $level
Tema: $vocabTheme
Dilbilgisi konusu: $grammarTopic
$words
Üret:
- title: hikayenin İngilizce başlığı
- paragraphs: toplam $length kelimelik, 3-5 paragraftan oluşan özgün bir İngilizce hikaye. Dilbilgisi konusundaki yapıları doğal biçimde kullan.
- glossary: hikayede geçen ve seviyeye göre zor olabilecek 4-6 kelime/kalıp; word (İngilizce) ve meaning (TÜRKÇE)
- questions: 4 adet okuduğunu anlama sorusu
  - question: İngilizce soru
  - options: 4 İngilizce seçenek
  - answerIndex: doğru seçeneğin 0'dan başlayan sırası
  - explanationTr: cevabın metnin neresinden çıktığını anlatan TÜRKÇE açıklama

Kurallar:
- Hikaye ve sorular $level seviyesine uygun olsun.
- Soruların cevabı yalnızca metinden çıkarılabilsin; genel kültür sorusu sorma.
- En az bir soru çıkarım (inference) gerektirsin.
''';
  }

  String _reportPrompt({
    required String name,
    required String level,
    required WeeklyStats stats,
    required int levelDelta,
  }) {
    final levelNote = switch (levelDelta) {
      1 => 'Sonuçlar seviyenin üstünde; uygulama bir kademe yukarı önerecek.',
      -1 => 'Öğrenci zorlandı; uygulama bir kademe aşağı önerecek.',
      _ => 'Seviye değişikliği önerilmiyor.',
    };

    return '''
Sen destekleyici bir İngilizce koçusun. Öğrencinin haftalık çalışma verisini değerlendir.

Öğrenci: $name
CEFR seviyesi: $level
Çalışılan gün: ${stats.daysCompleted}/7
Bitirilen ders: ${stats.lessonsCompleted}
Ortalama ders skoru: ${stats.averageLessonScore?.round() ?? 'yok'}
Toplam ders süresi: ${stats.studyMinutes} dakika
Okunan hikaye: ${stats.storiesRead}, ortalama anlama skoru: ${stats.averageStoryScore?.round() ?? 'yok'}
Tekrar edilen flash kart: ${stats.cardsReviewed}
Henüz pekişmemiş ifadeler (${stats.openMistakes}): ${stats.topMistakes.join(", ")}
Seviye notu: $levelNote

TÜRKÇE yaz:
- summary: 2-3 cümlelik genel değerlendirme, öğrenciye "sen" diye hitap et
- strengths: 2-3 maddelik güçlü yönler
- focus: 2-3 maddelik gelecek hafta odaklanılacak somut konular (pekişmemiş ifadeleri kullan)
- tip: tek cümlelik pratik bir öneri

Verilerde olmayan bir şey uydurma. Veri azsa bunu nazikçe belirt.
''';
  }

  static const Map<String, dynamic> _storySchema = {
    'type': 'OBJECT',
    'properties': {
      'title': {'type': 'STRING'},
      'paragraphs': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'glossary': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'word': {'type': 'STRING'},
            'meaning': {'type': 'STRING'},
          },
          'required': ['word', 'meaning'],
        },
      },
      'questions': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'question': {'type': 'STRING'},
            'options': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
            'answerIndex': {'type': 'INTEGER'},
            'explanationTr': {'type': 'STRING'},
          },
          'required': ['question', 'options', 'answerIndex', 'explanationTr'],
        },
      },
    },
    'required': ['title', 'paragraphs', 'glossary', 'questions'],
  };

  static const Map<String, dynamic> _reportSchema = {
    'type': 'OBJECT',
    'properties': {
      'summary': {'type': 'STRING'},
      'strengths': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'focus': {
        'type': 'ARRAY',
        'items': {'type': 'STRING'},
      },
      'tip': {'type': 'STRING'},
    },
    'required': ['summary', 'strengths', 'focus', 'tip'],
  };

  /// Gemini `generateContent` çağrısının ortak gövdesi.
  ///
  /// Başarısızlıkta hata fırlatmaz; `body` null, `error` dolu döner.
  Future<({String? body, String? error})> _post({
    required String prompt,
    required Map<String, dynamic> schema,
    required Duration timeout,
    double temperature = 1.0,
  }) async {
    if (!hasApiKey) return (body: null, error: 'GEMINI_API_KEY tanımlı değil');

    final uri = Uri.parse(
      '${AppConstants.geminiBaseUrl}/${AppConstants.geminiModel}:generateContent'
      '?key=$_apiKey',
    );

    final body = jsonEncode({
      'contents': [
        {
          'parts': [
            {'text': prompt},
          ],
        },
      ],
      'generationConfig': {
        'responseMimeType': 'application/json',
        'responseSchema': schema,
        'temperature': temperature,
      },
    });

    try {
      final response = await _client
          .post(uri, headers: {'Content-Type': 'application/json'}, body: body)
          .timeout(timeout);

      if (response.statusCode != 200) {
        return (body: null, error: _errorMessage(response.statusCode));
      }
      return (body: utf8.decode(response.bodyBytes), error: null);
    } catch (e) {
      return (body: null, error: e.toString());
    }
  }

  /// HTTP hatalarını kullanıcının anlayacağı dile çevirir.
  static String _errorMessage(int statusCode) => switch (statusCode) {
        400 => 'İstek reddedildi (400) — API anahtarı geçersiz olabilir',
        403 => 'Erişim reddedildi (403) — anahtarı kontrol et',
        429 => 'Kota doldu (429) — bir süre sonra tekrar dene',
        >= 500 => 'Gemini şu an yanıt vermiyor ($statusCode)',
        _ => 'Gemini $statusCode',
      };

  String _planPrompt({
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

  String _lessonPrompt({
    required String name,
    required String level,
    required int dailyMinutes,
    required String grammarTopic,
    required String vocabTheme,
    required List<String> reviewItems,
  }) {
    final size = LessonSize.forMinutes(dailyMinutes);
    final review = reviewItems.isEmpty
        ? ''
        : '\nÖğrencinin daha önce yanlış yaptığı ve hâlâ pekişmemiş ifadeler: '
            '${reviewItems.join(", ")}.\n'
            'Soruların bir kısmını bunların tekrarına ayır.\n';

    return '''
Sen bir İngilizce öğretmenisin. Türkçe konuşan bir öğrenci için bugünkü dersi hazırlıyorsun.

Öğrenci: $name
CEFR seviyesi: $level
Bugünün dilbilgisi konusu: $grammarTopic
Bugünün kelime teması: $vocabTheme
Ders süresi: $dailyMinutes dakika
$review
Şu bölümleri üret:

1) vocab — tam ${size.vocab} kelime/kalıp:
   - word: İngilizce kelime veya kalıp
   - meaning: TÜRKÇE karşılığı
   - example: kelimeyi kullanan, bugünün dilbilgisi konusuna uygun İngilizce örnek cümle

2) gapFill — tam ${size.gapFill} boşluk doldurma sorusu:
   - sentence: içinde tam olarak bir tane "___" geçen İngilizce cümle
   - answer: boşluğa gelecek doğru ifade
   - options: doğru cevabın da içinde olduğu 4 seçenek
   - hintTr: cümlenin TÜRKÇE anlamı

3) translate — tam ${size.translate} çeviri sorusu (Türkçeden İngilizceye):
   - tr: çevrilecek TÜRKÇE cümle
   - en: beklenen İngilizce çeviri
   - accepted: aynı anlama gelen 2-4 alternatif İngilizce çeviri.
     ÖNEMLİ: Cevap bilgisayarda metin karşılaştırmasıyla puanlanıyor. Bu yüzden
     kelime sırası, eşanlamlı ve kısaltmasız/kısaltmalı biçim farklarını burada
     mutlaka say. Hatalı puanlama olmasın.

4) quiz — tam ${size.quiz} çoktan seçmeli soru:
   - question: bugünün dilbilgisi konusunu ölçen İngilizce soru
   - options: 4 seçenek
   - answerIndex: doğru seçeneğin 0'dan başlayan sırası
   - explanationTr: doğru cevabın neden doğru olduğunun TÜRKÇE açıklaması

Kurallar:
- Tüm İngilizce içerik $level seviyesine uygun olsun.
- Kelimeler ve cümleler "$vocabTheme" temasıyla, dilbilgisi yapıları "$grammarTopic" konusuyla ilgili olsun.
- Aynı cümleyi iki bölümde tekrar kullanma.
- Türkçe alanlar Türkçe, İngilizce alanlar İngilizce olsun; karıştırma.
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

  static const Map<String, dynamic> _lessonSchema = {
    'type': 'OBJECT',
    'properties': {
      'vocab': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'word': {'type': 'STRING'},
            'meaning': {'type': 'STRING'},
            'example': {'type': 'STRING'},
          },
          'required': ['word', 'meaning', 'example'],
        },
      },
      'gapFill': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'sentence': {'type': 'STRING'},
            'answer': {'type': 'STRING'},
            'options': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
            'hintTr': {'type': 'STRING'},
          },
          'required': ['sentence', 'answer', 'options', 'hintTr'],
        },
      },
      'translate': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'tr': {'type': 'STRING'},
            'en': {'type': 'STRING'},
            'accepted': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
          },
          'required': ['tr', 'en', 'accepted'],
        },
      },
      'quiz': {
        'type': 'ARRAY',
        'items': {
          'type': 'OBJECT',
          'properties': {
            'question': {'type': 'STRING'},
            'options': {
              'type': 'ARRAY',
              'items': {'type': 'STRING'},
            },
            'answerIndex': {'type': 'INTEGER'},
            'explanationTr': {'type': 'STRING'},
          },
          'required': ['question', 'options', 'answerIndex', 'explanationTr'],
        },
      },
    },
    'required': ['vocab', 'gapFill', 'translate', 'quiz'],
  };
}

/// Gemini `generateContent` yanıtını [PlanDaySpec] listesine çevirir.
///
/// Yanıt beklenen biçimde değilse boş liste döner — çağıran taraf bunu yedek
/// programa geçiş sinyali olarak kullanır.
List<PlanDaySpec> parseWeeklyPlanResponse(String responseBody) {
  final text = extractModelText(responseBody);
  if (text == null) return const [];

  try {
    final raw = jsonDecode(text);
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
            grammarTopic: readString(item, 'grammarTopic'),
            vocabTheme: readString(item, 'vocabTheme'),
          ),
    ].where((d) => d.grammarTopic.isNotEmpty && d.vocabTheme.isNotEmpty).toList();
  } catch (_) {
    return const [];
  }
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
