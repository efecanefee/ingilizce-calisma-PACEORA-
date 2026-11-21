import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/constants.dart';
import '../../../app/error_reporting.dart';
import '../../../data/providers.dart';
import '../../../data/settings_providers.dart';
import '../settings_section.dart';
import '../sheets/api_key_sheet.dart';
import '../sheets/connection_test_sheet.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_tile.dart';

/// GELİŞMİŞ: çoğu kullanıcının dokunmasına gerek olmayan ayarlar.
class AdvancedGroup extends ConsumerWidget {
  const AdvancedGroup({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCustomKey = ref.watch(apiKeyProvider).isNotEmpty;
    final service = ref.watch(geminiServiceProvider);
    final usable = service.hasApiKey;

    return SettingsGroup(
      section: SettingsSection.advanced,
      children: [
        SettingsTile(
          icon: Icons.key_rounded,
          title: 'Kendi Gemini anahtarın',
          subtitle: hasCustomKey
              ? 'Kendi anahtarın kullanılıyor'
              : usable
              ? 'İsteğe bağlı. Genelde gerekmez; yapay zeka uygulamayla gelir'
              : 'Anahtar yok — dersler üretilemez',
          onTap: () => showApiKeySheet(context),
        ),
        SettingsTile(
          icon: Icons.network_check_rounded,
          title: 'Bağlantıyı test et',
          subtitle: service.viaFirebase
              ? 'Yapay zeka bağlantısını ve yanıt süresini kontrol eder'
              : 'Anahtar, model ve yanıt süresini kontrol eder',
          onTap: () => openConnectionTestSheet(context),
        ),
        const ErrorLogTile(),
      ],
    );
  }
}

/// Cihazdaki hata kaydı: kaç hata olduğu, paylaşma ve temizleme.
class ErrorLogTile extends ConsumerStatefulWidget {
  const ErrorLogTile({super.key});

  @override
  ConsumerState<ErrorLogTile> createState() => _ErrorLogTileState();
}

class _ErrorLogTileState extends ConsumerState<ErrorLogTile> {
  @override
  Widget build(BuildContext context) {
    final log = ref.watch(errorLogProvider);
    final count = log.entries.length;
    return SettingsTile(
      icon: Icons.bug_report_rounded,
      title: 'Hata kaydı',
      subtitle: count == 0
          ? 'Kayıtlı hata yok'
          : '$count hata kaydı · yalnızca bu cihazda',
      onTap: count == 0 ? null : () => _open(log),
    );
  }

  Future<void> _open(ErrorLog log) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hata kaydı'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text(
                'Bu kayıt yalnızca bu cihazda tutulur ve kendiliğinden hiçbir '
                'yere gönderilmez. Bir sorunu bildirmek istersen paylaşabilirsin.',
              ),
              const SizedBox(height: 12),
              for (final e in log.entries.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    e.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('clear'),
            child: const Text('Temizle'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(dialogContext).pop('share'),
            child: const Text('Paylaş'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'share':
        await SharePlus.instance.share(
          ShareParams(
            text: log.report(appVersion: AppConstants.appVersion),
            subject: 'Paceora hata kaydı',
          ),
        );
      case 'clear':
        await log.clear();
        setState(() {});
    }
  }
}
