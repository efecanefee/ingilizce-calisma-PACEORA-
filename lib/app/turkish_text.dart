/// Türkçe büyük harf: "i" → "İ", "ı" → "I" (String.toUpperCase "i"yi "I"
/// yapar).
String trUpper(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();
