import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants.dart';
import '../../../app/motion.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import '../widgets/settings_sheet.dart';

/// Günlük çalışma süresi seçicisini alt sayfada açar.
Future<void> openDailyMinutesSheet(BuildContext context, UserProfile user) =>
    openSettingsSheet(
      context,
      'Günlük çalışma süresi',
      DailyMinutesPicker(user: user),
    );

/// Süre seçenekleri ve her birinin kısa açıklaması; dokununca kaydeder.
class DailyMinutesPicker extends ConsumerStatefulWidget {
  const DailyMinutesPicker({super.key, required this.user});

  final UserProfile user;

  @override
  ConsumerState<DailyMinutesPicker> createState() => _DailyMinutesPickerState();
}

class _DailyMinutesPickerState extends ConsumerState<DailyMinutesPicker> {
  bool _saving = false;

  Future<void> _pick(int minutes) async {
    final navigator = Navigator.of(context);
    if (minutes == widget.user.dailyMinutes) {
      navigator.pop();
      return;
    }
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    // Snackbar eylemi sayfa kapandıktan sonra çalışır; notifier önceden alınır.
    final planNotifier = ref.read(weekPlanProvider.notifier);
    try {
      await ref
          .read(profileProvider.notifier)
          .save(
            name: widget.user.name,
            level: widget.user.level,
            dailyMinutes: minutes,
          );
      navigator.pop();
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Günlük süren $minutes dakika oldu.'),
            action: SnackBarAction(
              label: 'Programı yenile',
              onPressed: planNotifier.regenerate,
            ),
          ),
        );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Seçili değer vurgu renginde; ayarlarda renk yalnızca seçimi gösterir.
    final color = theme.colorScheme.primary;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Her gün ne kadar zaman ayırmak istersin? Dersler ve haftalık '
          'program bu süreye göre hazırlanır.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        for (final minutes in AppConstants.dailyMinuteOptions)
          Builder(
            builder: (context) {
              final selected = minutes == widget.user.dailyMinutes;
              return Semantics(
                selected: selected,
                inMutuallyExclusiveGroup: true,
                child: ListTile(
                  contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                  enabled: !_saving,
                  onTap: () {
                    Haptics.tap();
                    _pick(minutes);
                  },
                  title: Text(
                    '$minutes dakika',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                    ),
                  ),
                  subtitle: Text(AppConstants.dailyMinuteHint(minutes)),
                  trailing: Icon(
                    selected
                        ? Icons.check_circle_rounded
                        : Icons.circle_outlined,
                    color: selected ? color : theme.colorScheme.outline,
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}
