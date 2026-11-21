import 'package:flutter/material.dart';

/// Ayarlar ekranının bölümleri, sırasıyla.
///
/// Her bölümün tek bir rengi vardır: başlık yazısı ve o bölümdeki tüm satır
/// simgeleri bu rengi kullanır, böylece renk = bölüm olur. Tonlar bilerek
/// sakin (az doygun) seçildi ve pratik bölümlerinin renklerinden
/// (`lib/app/feature_colors.dart`) ve durum renklerinden (başarı, uyarı,
/// hata) ayrı tutuldu; ayarlarda bir rengin "anlam" taşıdığı izlenimi
/// oluşmasın. Kırmızı yalnızca "Verileri sıfırla" satırına ayrılmıştır.
///
/// - [bright]: koyu temada kart zemininde (graphite700) okunur ton.
/// - [deep]: açık temada beyaz kart zemininde okunur ton.
///
/// İkisi de metin ve simge için WCAG AA (4.5:1) kontrastını sağlar;
/// `test/settings_section_test.dart` bunu denetler.
enum SettingsSection {
  /// Çivit: seviye, günlük süre, program.
  study('ÇALIŞMA', Color(0xFF9AA8FF), Color(0xFF4250C4)),

  /// Orkide: tema, vurgu, titreşim, ses.
  appearance('GÖRÜNÜM', Color(0xFFE3A0F0), Color(0xFF9333A8)),

  /// Kum: hatırlatma.
  notifications('BİLDİRİMLER', Color(0xFFE2C07E), Color(0xFF86621A)),

  /// Adaçayı: yedekleme ve geri yükleme.
  data('VERİLERİM', Color(0xFF9FD4AE), Color(0xFF2F7A47)),

  /// Çelik mavisi: kendi anahtarın, bağlantı testi, hata kaydı.
  advanced('GELİŞMİŞ', Color(0xFF9FC0DA), Color(0xFF3A6485)),

  /// Taş: sürüm, gizlilik, geri bildirim, lisanslar.
  about('HAKKINDA', Color(0xFFC2BAAE), Color(0xFF6B6257));

  const SettingsSection(this.title, this.bright, this.deep);

  /// Bölüm başlığı. Doğrudan büyük yazıldı: `toUpperCase` Türkçeye duyarsız
  /// ("Verilerim" → "VERILERIM").
  final String title;

  /// Koyu tema tonu.
  final Color bright;

  /// Açık tema tonu.
  final Color deep;

  /// Etkin temada başlık ve simge rengi.
  Color color(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark ? bright : deep;

  /// Simge kutusunun zemini için yumuşak ton.
  Color tint(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    return color(
      context,
    ).withValues(alpha: dark ? tintAlphaDark : tintAlphaLight);
  }

  /// Simge kutusu zemininin koyu temadaki saydamlığı.
  static const tintAlphaDark = 0.16;

  /// Simge kutusu zemininin açık temadaki saydamlığı.
  static const tintAlphaLight = 0.10;
}
