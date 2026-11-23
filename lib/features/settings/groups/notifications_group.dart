import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/motion.dart';
import '../../../data/settings_providers.dart';
import '../settings_section.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_tile.dart';

/// BİLDİRİMLER: günlük hatırlatma ve saati.
class NotificationsGroup extends ConsumerWidget {
  const NotificationsGroup({super.key});

  Future<void> _toggleReminder(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(reminderProvider.notifier).setEnabled(value);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Bildirim izni verilmedi. Telefon ayarlarından Paceora için '
            'bildirimlere izin verebilirsin.',
          ),
        ),
      );
    }
  }

  static String _format(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  Future<void> _toggleExtra(
    BuildContext context,
    Future<bool> Function() toggle,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    if (!await toggle()) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Bildirim izni verilmedi. Telefon ayarlarından Paceora için '
            'bildirimlere izin verebilirsin.',
          ),
        ),
      );
    }
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final current = ref.read(reminderProvider).time;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'Hatırlatma saati',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      await ref.read(reminderProvider.notifier).setTime(picked);
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reminder = ref.watch(reminderProvider);
    final extras = ref.watch(extraNotificationsProvider);
    final suggestion = reminder.enabled
        ? ref.watch(reminderSuggestionProvider).value
        : null;
    final time =
        '${reminder.time.hour.toString().padLeft(2, '0')}:${reminder.time.minute.toString().padLeft(2, '0')}';

    return SettingsGroup(
      section: SettingsSection.notifications,
      children: [
        // Saat satırı ayırıcısıyla birlikte açılıp kapanır; bu yüzden ikisi
        // tek hücrede.
        Column(
          children: [
            SettingsTile(
              icon: Icons.notifications_active_rounded,
              title: 'Her gün hatırlat',
              subtitle: reminder.enabled
                  ? 'Her gün $time\'da bildirim'
                  : 'Serini kaybetmemen için bildirim gönderir',
              trailing: Switch(
                value: reminder.enabled,
                onChanged: (v) => _toggleReminder(context, ref, v),
              ),
            ),
            AnimatedSize(
              duration: Motion.medium,
              curve: Motion.curve,
              child: reminder.enabled
                  ? Column(
                      children: [
                        const Divider(height: 1, indent: 64),
                        SettingsTile(
                          icon: Icons.schedule_rounded,
                          title: 'Hatırlatma saati',
                          trailing: Text(
                            time,
                            style: theme.textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: theme.colorScheme.primary,
                            ),
                          ),
                          onTap: () => _pickTime(context, ref),
                        ),
                      ],
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
        if (suggestion != null)
          SettingsTile(
            icon: Icons.auto_awesome_rounded,
            title: 'Önerilen saat: ${_format(suggestion)}',
            subtitle:
                'Genelde bu saatlerde çalışıyorsun; hatırlatma biraz önce '
                'gelsin.',
            trailing: TextButton(
              onPressed: () =>
                  ref.read(reminderProvider.notifier).setTime(suggestion),
              child: const Text('Uygula'),
            ),
          ),
        SettingsTile(
          icon: Icons.assessment_rounded,
          title: 'Haftalık rapor',
          subtitle: "Pazar 19:00'da haftanın özeti",
          trailing: Switch(
            value: extras.weekly,
            onChanged: (v) => _toggleExtra(
              context,
              () => ref.read(extraNotificationsProvider.notifier).setWeekly(v),
            ),
          ),
        ),
        SettingsTile(
          icon: Icons.wb_twilight_rounded,
          title: 'Günün kelimesi',
          subtitle: "Her sabah 09:00'da destenden bir kelime",
          trailing: Switch(
            value: extras.wordOfDay,
            onChanged: (v) => _toggleExtra(
              context,
              () =>
                  ref.read(extraNotificationsProvider.notifier).setWordOfDay(v),
            ),
          ),
        ),
      ],
    );
  }
}
