import 'dart:convert';

/// Gemini `generateContent` yanıtlarının ortak ayrıştırma yardımcıları.
///
/// Hem haftalık plan hem günlük ders aynı zarf biçimini kullandığı için
/// zarf açma tek yerde toplandı.

/// Yanıt zarfının içindeki model metnini çıkarır ve kod bloğu sarmalını temizler.
///
/// Yanıt beklenen biçimde değilse null döner — hiçbir koşulda hata fırlatmaz;
/// çağıran taraf null'ı yedeğe geçiş sinyali olarak kullanır.
String? extractModelText(String responseBody) {
  try {
    final decoded = jsonDecode(responseBody);
    if (decoded is! Map<String, dynamic>) return null;

    final candidates = decoded['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;

    final content = (candidates.first as Map<String, dynamic>)['content'];
    if (content is! Map<String, dynamic>) return null;

    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return null;

    final text = (parts.first as Map<String, dynamic>)['text'];
    if (text is! String || text.trim().isEmpty) return null;

    return stripCodeFence(text);
  } catch (_) {
    return null;
  }
}

/// Model bazen JSON'u ```json ... ``` bloğuna sarar; sarmalı temizler.
String stripCodeFence(String text) {
  final trimmed = text.trim();
  if (!trimmed.startsWith('```')) return trimmed;
  final withoutOpen = trimmed.replaceFirst(RegExp(r'^```[a-zA-Z]*\s*'), '');
  return withoutOpen.replaceFirst(RegExp(r'```\s*$'), '').trim();
}

/// JSON haritasından boşluğu kırpılmış metin alanı okur; yoksa boş string.
String readString(Map<String, dynamic> map, String key) {
  final value = map[key];
  return value is String ? value.trim() : '';
}

/// JSON haritasından metin listesi okur; boş/geçersiz öğeler elenir.
List<String> readStringList(Map<String, dynamic> map, String key) {
  final value = map[key];
  if (value is! List) return const [];
  return [
    for (final item in value)
      if (item is String && item.trim().isNotEmpty) item.trim(),
  ];
}
