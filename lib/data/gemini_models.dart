import 'dart:convert';

/// Gemini model listesinden ders üretimine uygun modelleri seçer ve sıralar.
///
/// Model adları Google tarafında sık değişiyor (ör. gemini-2.0-flash kapatıldı,
/// 2.5 modelleri yeni anahtarlara açık değil). Sabit bir ad yerine anahtarın
/// gerçekten erişebildiği modeller `models.list` ile sorulur ve buradan seçilir.
///
/// Sıra: önce en yeni Flash-Lite (yapılandırılmış JSON'u saniyeler içinde
/// üretir), sonra en yeni Flash (daha güçlü ama yavaş), sonra kalanlar.
/// Kararlı sürümler önizlemelerden önce gelir.
List<String> rankFlashModels(Iterable<String> names) {
  final candidates = <_Candidate>[];
  for (final raw in names) {
    final id = raw.startsWith('models/')
        ? raw.substring('models/'.length)
        : raw;
    if (!id.startsWith('gemini-') || !id.contains('flash')) continue;
    // Metin üretimi dışındaki özel modeller.
    if (_excluded.hasMatch(id)) continue;
    final match = _version.firstMatch(id);
    if (match == null) continue;
    candidates.add(
      _Candidate(
        id: id,
        version: double.parse(match.group(1)!),
        lite: id.contains('lite'),
        preview: id.contains('preview'),
      ),
    );
  }

  int compare(_Candidate a, _Candidate b) {
    if (a.preview != b.preview) return a.preview ? 1 : -1;
    final byVersion = b.version.compareTo(a.version);
    if (byVersion != 0) return byVersion;
    // Aynı sürümde kısa ad (takma ad) tarihli/numaralı varyanttan önce.
    return a.id.length.compareTo(b.id.length);
  }

  final lites = candidates.where((c) => c.lite).toList()..sort(compare);
  final flashes = candidates.where((c) => !c.lite).toList()..sort(compare);
  final rest = [...lites.skip(1), ...flashes.skip(1)]..sort(compare);

  return [
    if (lites.isNotEmpty) lites.first.id,
    if (flashes.isNotEmpty) flashes.first.id,
    for (final c in rest) c.id,
  ];
}

/// `models.list` yanıtından `generateContent` destekleyen model adlarını okur.
///
/// Yanıt beklenen biçimde değilse boş liste döner.
List<String> parseModelList(String responseBody) {
  try {
    final raw = jsonDecode(responseBody);
    if (raw is! Map<String, dynamic>) return const [];
    final models = raw['models'];
    if (models is! List) return const [];
    return [
      for (final model in models)
        if (model is Map<String, dynamic> &&
            model['name'] is String &&
            (model['supportedGenerationMethods'] as List?)?.contains(
                  'generateContent',
                ) ==
                true)
          model['name'] as String,
    ];
  } catch (_) {
    return const [];
  }
}

final _excluded = RegExp(r'image|tts|audio|live|embedding|exp|native|robotics');
final _version = RegExp(r'^gemini-(\d+(?:\.\d+)?)');

class _Candidate {
  const _Candidate({
    required this.id,
    required this.version,
    required this.lite,
    required this.preview,
  });

  final String id;
  final double version;
  final bool lite;
  final bool preview;
}
