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
                              color: SettingsSection.notifications.color(
                                context,
                              ),
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
      ],
    );
  }
}
