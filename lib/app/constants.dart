/// Uygulama geneli sabitler.
abstract class AppConstants {
  static const appName = 'Paceora';

  /// Gemini API anahtarı derleme zamanında verilir:
  /// flutter run --dart-define=GEMINI_API_KEY=xxxx
  static const geminiApiKey = String.fromEnvironment('GEMINI_API_KEY');

  static const geminiModel = 'gemini-2.0-flash';
  static const geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models';

  /// Günlük çalışma süresi seçenekleri (dakika)
  static const dailyMinuteOptions = [10, 15, 20];

  /// Onboarding tamamlandı bayrağı (SharedPreferences anahtarı).
  static const prefOnboardingDone = 'onboarding_done';

  /// Kullanıcının Ayarlar'dan girdiği Gemini anahtarı; boşsa derleme zamanı
  /// anahtarı kullanılır.
  static const prefApiKey = 'gemini_api_key';

  /// Tema tercihi: system | light | dark
  static const prefThemeMode = 'theme_mode';

  /// Günlük hatırlatma açık mı ve hangi saatte (dakika cinsinden, 0-1439).
  static const prefReminderEnabled = 'reminder_enabled';
  static const prefReminderMinutes = 'reminder_minutes';

  /// Hatırlatmanın varsayılan saati: 20:00
  static const defaultReminderMinutes = 20 * 60;

  /// Bir derste modele hatırlatılacak en fazla çözülmemiş hata sayısı.
  static const maxReviewItems = 8;

  /// Haftanın günleri — plan listesinde dayIndex 0..6 ile eşleşir.
  static const weekdayNames = [
    'Pazartesi',
    'Salı',
    'Çarşamba',
    'Perşembe',
    'Cuma',
    'Cumartesi',
    'Pazar',
  ];
}

/// CEFR tabanlı zorluk kademeleri (adaptif zorluk için).
enum DifficultyLevel {
  b1Minus('B1-', 'B1 (kolay)'),
  b1('B1', 'B1'),
  b1Plus('B1+', 'B1 (zor)'),
  b2Minus('B2-', 'B2 (kolay)'),
  b2('B2', 'B2'),
  b2Plus('B2+', 'B2 (zor)');

  const DifficultyLevel(this.code, this.label);
  final String code;
  final String label;

  static DifficultyLevel fromCode(String code) =>
      DifficultyLevel.values.firstWhere(
        (e) => e.code == code,
        orElse: () => DifficultyLevel.b1,
      );

  DifficultyLevel step(int delta) {
    final i = (index + delta).clamp(0, DifficultyLevel.values.length - 1);
    return DifficultyLevel.values[i];
  }
}
