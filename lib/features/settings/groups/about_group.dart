import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants.dart';
import '../../../app/logo.dart';
import '../../../app/motion.dart';
import '../../../data/feedback.dart';
import '../../../data/providers.dart';
import '../settings_section.dart';
import '../sheets/privacy_sheet.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_tile.dart';

/// HAKKINDA: sürüm, gizlilik, geri bildirim, lisanslar ve alttaki logo.
class AboutGroup extends StatelessWidget {
  const AboutGroup({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        SettingsGroup(
          section: SettingsSection.about,
          children: [
            const SettingsTile(
              icon: Icons.info_rounded,
              title: 'Sürüm',
              trailing: Text(AppConstants.appVersion),
            ),
            SettingsTile(
              icon: Icons.lock_rounded,
              title: 'Gizlilik',
              subtitle:
                  'İlerlemen cihazda; dersler için konu ve cevaplar '
                  'Google Gemini\'ye gider, adın gitmez',
              onTap: () => openPrivacySheet(context),
            ),
            const FeedbackTile(),
            SettingsTile(
              icon: Icons.description_rounded,
              title: 'Açık kaynak lisansları',
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(12),
                  child: PaceoraMark(size: 56),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const PaceoraMark(size: 44)
            .animate(onPlay: Motion.loop(reverse: true))
            .moveY(
              begin: -3,
              end: 3,
              duration: 1600.ms,
              curve: Curves.easeInOut,
            ),
        const SizedBox(height: 10),
        Text(
          'Learn English. Go Further.',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// E-posta ile geri bildirim: sürüm ve platform hazır gelir, hata kaydı
/// yalnızca kullanıcı isterse eklenir.
class FeedbackTile extends ConsumerWidget {
  const FeedbackTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsTile(
      icon: Icons.mail_rounded,
      title: 'Geri bildirim gönder',
      subtitle: 'Öneri, hata ya da soru: e-posta ile yaz',
      onTap: () => _send(context, ref),
    );
  }

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final log = ref.read(errorLogProvider);
    final messenger = ScaffoldMessenger.of(context);
    var attachLog = false;
    if (log.entries.isNotEmpty) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            title: const Text('Geri bildirim gönder'),
            content: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: attachLog,
              onChanged: (v) => setState(() => attachLog = v ?? false),
              title: Text('Hata kaydını ekle (${log.entries.length})'),
              subtitle: const Text(
                'Sorunu bulmamıza yardım eder; kişisel bilgi içermez.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('E-postayı aç'),
              ),
            ],
          ),
        ),
      );
      if (choice != true) return;
    }
    final uri = feedbackMailUri(
      platform: defaultTargetPlatform.name,
      errorReport: attachLog
          ? log.report(appVersion: AppConstants.appVersion)
          : null,
    );
    final opened = await ref.read(mailLauncherProvider)(uri);
    if (opened) return;
    // E-posta uygulaması yoksa adres panoya kopyalanır.
    await Clipboard.setData(
      const ClipboardData(text: AppConstants.supportEmail),
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'E-posta uygulaması açılamadı. Adres kopyalandı: '
          '${AppConstants.supportEmail}',
        ),
      ),
    );
  }
}
