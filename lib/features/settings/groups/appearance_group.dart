import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/motion.dart';
import '../../../app/theme.dart';
import '../../../data/settings_providers.dart';
import '../settings_section.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_tile.dart';

/// GÖRÜNÜM: tema, vurgu rengi, titreşim ve ses.
class AppearanceGroup extends ConsumerWidget {
  const AppearanceGroup({super.key});

  static String _modeLabel(ThemeMode mode) => switch (mode) {
    ThemeMode.system => 'Telefonun ayarını izler',
    ThemeMode.light => 'Açık tema',
    ThemeMode.dark => 'Koyu tema',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final accent = ref.watch(accentProvider);
    final haptics = ref.watch(hapticsProvider);
    final sounds = ref.watch(soundsProvider);

    return SettingsGroup(
      section: SettingsSection.appearance,
      children: [
        SettingsTile(
          icon: Icons.contrast_rounded,
          title: 'Tema',
          subtitle: _modeLabel(mode),
          below: SegmentedButton<ThemeMode>(
            segments: const [
              ButtonSegment(
                value: ThemeMode.system,
                label: Text('Sistem'),
                icon: Icon(Icons.brightness_auto_rounded),
              ),
              ButtonSegment(
                value: ThemeMode.light,
                label: Text('Açık'),
                icon: Icon(Icons.light_mode_rounded),
              ),
              ButtonSegment(
                value: ThemeMode.dark,
                label: Text('Koyu'),
                icon: Icon(Icons.dark_mode_rounded),
              ),
            ],
            selected: {mode},
            showSelectedIcon: false,
            onSelectionChanged: (selection) {
              Haptics.tap();
              ref.read(themeModeProvider.notifier).save(selection.first);
            },
          ),
        ),
        SettingsTile(
          icon: Icons.palette_rounded,
          title: 'Vurgu rengi',
          subtitle: accent.label,
          below: const AccentPicker(),
        ),
        SettingsTile(
          icon: Icons.vibration_rounded,
          title: 'Titreşim',
          subtitle: 'Dokunuşlarda hafif titreşim',
          trailing: Switch(
            value: haptics,
            onChanged: (v) => ref.read(hapticsProvider.notifier).set(v),
          ),
        ),
        SettingsTile(
          icon: Icons.volume_up_rounded,
          title: 'Ses efektleri',
          subtitle: 'Cevap, ders bitişi ve başarı sesleri',
          trailing: Switch(
            value: sounds,
            onChanged: (v) => ref.read(soundsProvider.notifier).set(v),
          ),
        ),
      ],
    );
  }
}

/// Vurgu rengi seçici: her seçenek için renk yuvarlağı, seçili olan tikli.
class AccentPicker extends ConsumerWidget {
  const AccentPicker({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(accentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 4,
      runSpacing: 4,
      children: [
        for (final accent in AppAccent.values)
          Semantics(
            button: true,
            selected: accent == selected,
            label: '${accent.label} vurgu rengi',
            child: Tooltip(
              message: accent.label,
              child: InkResponse(
                onTap: () {
                  Haptics.tap();
                  ref.read(accentProvider.notifier).save(accent);
                },
                radius: 26,
                // 40 dp yuvarlak, 48 dp dokunma alanı.
                child: SizedBox.square(
                  dimension: 48,
                  child: Center(
                    child: AnimatedContainer(
                      duration: Motion.fast,
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: isDark
                              ? [accent.spark, accent.dim]
                              : [accent.dim, accent.dark],
                        ),
                        border: Border.all(
                          color: accent == selected
                              ? Theme.of(context).colorScheme.onSurface
                              : Colors.transparent,
                          width: 2.5,
                        ),
                      ),
                      child: accent == selected
                          ? Icon(
                              Icons.check_rounded,
                              size: 20,
                              color: isDark
                                  ? AppColors.graphite900
                                  : Colors.white,
                            )
                          : null,
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
