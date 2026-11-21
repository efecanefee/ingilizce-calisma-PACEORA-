import 'package:flutter/material.dart';

import 'theme.dart';

/// Uygulamanın bölümleri. Her bölümün her ekranda aynı kalan kendi rengi
/// vardır; kullanıcı neyin ne olduğunu renginden tanır.
///
/// Renk seçimi:
/// - [bright]: koyu zeminde (graphite700) okunur parlak ton.
/// - [deep]: açık zeminde (beyaz) okunur koyu ton.
/// İkisi de metin ve ikon için WCAG AA (4.5:1) kontrastını sağlar;
/// `test/feature_colors_test.dart` bunu denetler.
enum Feature {
  /// Günün dersi; kullanıcının seçtiği vurgu rengini kullanır.
  lesson('Günün dersi', Icons.school_rounded, null, null),
  flashcards(
    'Flash kartlar',
    Icons.style_rounded,
    Color(0xFFA78BFA), // mor
    Color(0xFF6D28D9),
  ),
  story(
    'Günün hikayesi',
    Icons.auto_stories_rounded,
    Color(0xFF60A5FA), // mavi
    Color(0xFF1D4ED8),
  ),
  speaking(
    'Konuşma',
    Icons.record_voice_over_rounded,
    Color(0xFFF472B6), // pembe
    Color(0xFFBE185D),
  ),
  dictation(
    'Dinle ve yaz',
    Icons.hearing_rounded,
    Color(0xFF34D399), // nane
    Color(0xFF047857),
  ),
  mistakes(
    'Hata defterim',
    Icons.edit_note_rounded,
    Color(0xFFFB923C), // mercan
    Color(0xFFC2410C),
  ),
  review(
    'Haftalık rapor',
    Icons.assessment_rounded,
    Color(0xFF2DD4BF), // turkuaz
    Color(0xFF0F766E),
  ),
  roleplay(
    'AI ile sohbet',
    Icons.forum_rounded,
    Color(0xFF7DD3FC), // buz mavisi
    Color(0xFF0369A1),
  ),
  rally(
    'Kelime Rallisi',
    Icons.bolt_rounded,
    Color(0xFFFBBF24), // kehribar
    Color(0xFFB45309),
  );

  const Feature(this.label, this.icon, this.bright, this.deep);

  final String label;
  final IconData icon;

  /// Koyu tema tonu; [lesson] için null (vurgu rengi kullanılır).
  final Color? bright;

  /// Açık tema tonu; [lesson] için null (vurgu rengi kullanılır).
  final Color? deep;

  /// Etkin temada metin ve ikon için okunur renk.
  Color color(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    if (this == Feature.lesson) {
      final pace = context.pace;
      return dark ? pace.accent : pace.accentDark;
    }
    return dark ? bright! : deep!;
  }

  /// Kart ve ikon kutusu zemini için yumuşak ton.
  Color tint(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return color(context).withValues(alpha: dark ? 0.16 : 0.10);
  }

  /// Kart kenarlığı için orta ton.
  Color border(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return color(context).withValues(alpha: dark ? 0.45 : 0.35);
  }
}
