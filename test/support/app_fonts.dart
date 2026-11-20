import 'dart:convert';

import 'package:flutter/services.dart';

/// Testlerde uygulamanın gerçek yazı tiplerini (Inter ve Material ikonları)
/// yükler; varsayılan Ahem kutuları yerine ekrandaki gibi çizilir.
Future<void> loadAppFonts() async {
  final manifest = jsonDecode(
    await rootBundle.loadString('FontManifest.json'),
  ) as List<dynamic>;
  for (final family in manifest.cast<Map<String, dynamic>>()) {
    final loader = FontLoader(family['family'] as String);
    for (final font in (family['fonts'] as List<dynamic>)
        .cast<Map<String, dynamic>>()) {
      loader.addFont(rootBundle.load(font['asset'] as String));
    }
    await loader.load();
  }
}
