import 'package:flutter/material.dart';

/// Ayarlar ekranının bölümleri, sırasıyla.
///
/// Ayarlar bilerek renksizdir: tüm simgeler aynı nötr tonda durur
/// ([iconColor], [iconTint]). Renk yalnızca seçili değerlerde (vurgu rengi)
/// ve geri alınamaz işlemlerde (kırmızı, "Verileri sıfırla") kullanılır.
/// Önceki sürümde her bölümün kendi rengi vardı; ekran fazla renkli
/// bulunduğu için kaldırıldı.
///
/// Ana sayfada her bölüm bir kart olarak görünür ([label], [icon]); karta
/// dokununca bölümün kendi sayfası açılır.
enum SettingsSection {
  study('ÇALIŞMA', 'Çalışma', Icons.school_rounded),
  appearance('GÖRÜNÜM', 'Görünüm', Icons.palette_rounded),
  notifications('BİLDİRİMLER', 'Bildirimler', Icons.notifications_rounded),
  data('VERİLERİM', 'Verilerim', Icons.save_rounded),
  advanced('GELİŞMİŞ', 'Gelişmiş', Icons.build_rounded),
  about('HAKKINDA', 'Hakkında', Icons.info_outline_rounded);

  const SettingsSection(this.title, this.label, this.icon);

  /// Bölüm başlığı (büyük harf). Doğrudan büyük yazıldı: `toUpperCase`
  /// Türkçeye duyarsız ("Verilerim" → "VERILERIM").
  final String title;

  /// Kartta ve sayfa başlığında görünen ad.
  final String label;

  /// Kartın simgesi.
  final IconData icon;

  /// Satır ve kart simgelerinin nötr rengi.
  static Color iconColor(BuildContext context) =>
      Theme.of(context).colorScheme.onSurfaceVariant;

  /// Simge kutusunun nötr zemini.
  static Color iconTint(BuildContext context) =>
      Theme.of(context).colorScheme.surfaceContainerHighest;
}
