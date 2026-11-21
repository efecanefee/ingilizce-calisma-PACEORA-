import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../profile/profile_form.dart';
import '../settings_section.dart';
import '../sheets/daily_minutes_sheet.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_tile.dart';

/// ÇALIŞMA: seviye, günlük süre ve haftalık program.
class StudyGroup extends ConsumerWidget {
  const StudyGroup({super.key, required this.user});

  final UserProfile user;

  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Haftalık program hazırlanıyor…')),
    );
    final result = await ref.read(weekPlanProvider.notifier).regenerate();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.offline
                ? 'Gemini\'ye ulaşılamadı; hazır program yüklendi.'
                : 'Haftalık programın yenilendi.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsGroup(
      section: SettingsSection.study,
      children: [
        SettingsTile(
          icon: Icons.signal_cellular_alt_rounded,
          title: 'Seviye',
          subtitle: DifficultyLevel.fromCode(user.level).label,
          onTap: () => openProfileSheet(context, user),
        ),
        SettingsTile(
          icon: Icons.timer_rounded,
          title: 'Günlük çalışma süresi',
          subtitle: 'Günde ${user.dailyMinutes} dakika',
          onTap: () => openDailyMinutesSheet(context, user),
        ),
        SettingsTile(
          icon: Icons.autorenew_rounded,
          title: 'Haftalık programı yenile',
          subtitle: 'Seviyene göre yeni konular üretir; ilerlemen korunur',
          onTap: () => _regenerate(context, ref),
        ),
      ],
    );
  }
}
