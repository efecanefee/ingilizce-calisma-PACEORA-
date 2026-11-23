import 'package:flutter/material.dart';

import '../settings_section.dart';
import '../widgets/settings_sheet.dart';

/// Gizlilik ayrıntılarını alt sayfada açar.
Future<void> openPrivacySheet(BuildContext context) =>
    openSettingsSheet(context, 'Gizlilik', const PrivacyDetails());

/// Hangi verinin nerede durduğu ve Gemini'ye ne gittiği.
class PrivacyDetails extends StatelessWidget {
  const PrivacyDetails({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = SettingsSection.iconColor(context);
    Widget section(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          Icons.phone_android_rounded,
          'Cihazında kalanlar',
          'Profilin, ilerlemen, serin, hata defterin, kartların ve '
              'ayarların yalnızca bu telefonda saklanır. Hesap ya da Paceora '
              'sunucusu yoktur.',
        ),
        section(
          Icons.auto_awesome_rounded,
          'Google Gemini\'ye gidenler',
          'Program, ders, hikaye, rapor ve sohbet üretmek için seviyen, '
              'günlük süren, günün konusu, tekrar edilecek ifadeler ve sohbet '
              'mesajların Google\'ın Gemini API\'sine gönderilir. Adın '
              'gönderilmez. Ücretsiz Gemini anahtarlarında Google bu içerikleri '
              'ürünlerini geliştirmek için kullanabilir.',
        ),
        section(
          Icons.mic_rounded,
          'Mikrofon',
          'Konuşma pratiğinde sesin telefonun konuşma tanıma servisiyle '
              'metne çevrilir; ses kaydı Paceora tarafından saklanmaz.',
        ),
        section(
          Icons.key_rounded,
          'API anahtarın',
          'Kendi anahtarını girersen telefonun güvenli kasasında şifreli '
              'saklanır ve yedeklere girmez.',
        ),
        section(
          Icons.delete_outline_rounded,
          'Silme',
          'Ayarlar > Verileri sıfırla her şeyi bu cihazdan siler.',
        ),
      ],
    );
  }
}
