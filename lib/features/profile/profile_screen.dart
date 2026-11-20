import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/avatar.dart';
import '../../app/badge_medal.dart';
import '../../app/constants.dart';
import '../../app/mascot.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/profile_style.dart';
import '../../data/providers.dart';
import '../../data/rewards.dart';
import '../wardrobe/wardrobe_sheet.dart';

/// Profil: avatar, oyuncu seviyesi, rozet vitrini ve özet istatistikler.
class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).value;
    final game = ref.watch(gameProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profilim'),
        actions: [
          IconButton(
            tooltip: 'Görünümü düzenle',
            icon: const Icon(Icons.edit_rounded),
            onPressed: () => showProfileEditor(context),
          ),
        ],
      ),
      body: user == null || game == null
          ? const Center(child: CircularProgressIndicator())
          : _ProfileBody(user: user, game: game),
    );
  }
}

class _ProfileBody extends ConsumerWidget {
  const _ProfileBody({required this.user, required this.game});

  final UserProfile user;
  final GameState game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final style = ref.watch(profileStyleProvider);
    final records = ref.watch(matchRecordsProvider);
    final level = game.level;
    final earned = game.earnedBadgeIds;
    final s = game.stats;
    final nextFrame = AvatarFrame.values
        .where((f) => !f.unlockedAt(level.level))
        .firstOrNull;
    final sectionStyle = theme.textTheme.titleMedium?.copyWith(
      fontWeight: FontWeight.w700,
    );

    var index = 0;
    Widget item(Widget child) => child.entrance(index++);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        item(
          _Header(user: user, style: style, level: level, nextFrame: nextFrame),
        ),
        const SizedBox(height: 28),
        item(
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Vitrin', style: sectionStyle),
              const SizedBox(height: 2),
              Text(
                'Öne çıkardığın rozetler; boş yuvaya dokunup ekle.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        item(_Showcase(stats: s, earned: earned)),
        const SizedBox(height: 28),
        item(Text('Özet', style: sectionStyle)),
        const SizedBox(height: 12),
        item(
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Column(
                children: [
                  Row(
                    children: [
                      _Stat(
                        icon: Icons.bolt_rounded,
                        value: '${level.xp}',
                        label: 'Toplam XP',
                      ),
                      _Stat(
                        icon: Icons.local_fire_department_rounded,
                        value: '${s.bestStreak}',
                        label: 'En uzun seri',
                      ),
                      _Stat(
                        icon: Icons.school_rounded,
                        value: '${s.lessons}',
                        label: 'Biten ders',
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      _Stat(
                        icon: Icons.auto_stories_rounded,
                        value: '${s.stories}',
                        label: 'Okunan hikaye',
                      ),
                      _Stat(
                        icon: Icons.psychology_rounded,
                        value: '${s.cardsMature}',
                        label: 'Kalıcı kelime',
                      ),
                      _Stat(
                        icon: Icons.emoji_events_rounded,
                        value: records.games > 0 ? '${records.bestScore}' : '–',
                        label: 'Ralli rekoru',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 12),
        item(
          Card(
            child: ListTile(
              leading: const Icon(Icons.military_tech_rounded),
              title: const Text('Tüm rozetler'),
              subtitle: Text('${earned.length}/${badges.length} kazanıldı'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () => context.go('/progress'),
            ),
          ),
        ),
        const SizedBox(height: 12),
        item(const _WardrobeCard()),
      ],
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.user,
    required this.style,
    required this.level,
    required this.nextFrame,
  });

  final UserProfile user;
  final ProfileStyle style;
  final PlayerLevel level;
  final AvatarFrame? nextFrame;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            style.color.withValues(alpha: 0.28),
            theme.colorScheme.surfaceContainer,
          ],
        ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Semantics(
            button: true,
            label: 'Profili düzenle',
            child: GestureDetector(
              onTap: () => showProfileEditor(context),
              child: PlayerAvatar.of(style, level: level.level, size: 104)
                .animate()
                .scale(
                  begin: const Offset(0.8, 0.8),
                  curve: Curves.elasticOut,
                  duration: Motion.slow,
                ),
          ),
          ),
          const SizedBox(height: 14),
          Text(
            user.name,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 6,
            children: [
              _Pill(
                text: 'Lv ${level.level} · ${level.title}',
                color: context.pace.accent,
                dark: true,
              ),
              _Pill(
                text: 'İngilizce ${DifficultyLevel.fromCode(user.level).label}',
                color: theme.colorScheme.surfaceContainerHighest,
              ),
            ],
          ),
          const SizedBox(height: 18),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: LinearProgressIndicator(
              value: level.progress.clamp(0, 1),
              minHeight: 8,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${level.xp} XP · Seviye ${level.level + 1} için '
            '${level.xpToNext} XP',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
          if (nextFrame case final frame?) ...[
            const SizedBox(height: 4),
            Text(
              'Seviye ${frame.unlockLevel}\'te ${frame.label} çerçeve açılır',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ],
      ),
    );
  }
}

/// Pace'in dolabına giriş: giyili formayla Pace ve dolap düğmesi.
class _WardrobeCard extends ConsumerWidget {
  const _WardrobeCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final kit = ref.watch(wardrobeProvider).equipped;
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: () => showWardrobeSheet(context),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 16, 8),
          child: Row(
            children: [
              const EquippedPace(size: 76, animate: false),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      "Pace'in dolabı",
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Forma: ${kit.label}',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.checkroom_rounded),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill({required this.text, required this.color, this.dark = false});

  final String text;
  final Color color;
  final bool dark;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: theme.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w800,
          color: dark ? AppColors.graphite900 : null,
        ),
      ),
    );
  }
}

/// Üç vitrin yuvası: dolu yuva rozetin ayrıntısını, boş yuva seçiciyi açar.
class _Showcase extends ConsumerWidget {
  const _Showcase({required this.stats, required this.earned});

  final GameStats stats;
  final Set<String> earned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final shown = ref.watch(profileStyleProvider).showcaseBadges(earned);

    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < showcaseSize; i++)
              Expanded(
                child: i < shown.length
                    ? _FilledSlot(
                        badge: shown[i],
                        onTap: () => showBadgeSheet(
                          context,
                          badge: shown[i],
                          stats: stats,
                        ),
                      )
                    : _EmptySlot(
                        onTap: () {
                          if (earned.isEmpty) {
                            ScaffoldMessenger.of(context)
                              ..hideCurrentSnackBar()
                              ..showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Henüz rozet kazanmadın; ilk dersini '
                                    'bitirince ilk rozetin gelir.',
                                  ),
                                ),
                              );
                            return;
                          }
                          _pick(context, ref);
                        },
                        // outline grisi koyu temada 3:1'in altında kalıyordu.
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.7,
                        ),
                      ),
              ),
          ],
        ),
      ),
    );
  }

  void _pick(BuildContext context, WidgetRef ref) {
    Haptics.tap();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) => _ShowcasePicker(stats: stats, earned: earned),
    );
  }
}

class _FilledSlot extends StatelessWidget {
  const _FilledSlot({required this.badge, required this.onTap});

  final BadgeDef badge;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            BadgeMedal(badge: badge, earned: true, size: 64),
            const SizedBox(height: 8),
            Text(
              badge.title,
              textAlign: TextAlign.center,
              maxLines: 2,
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptySlot extends StatelessWidget {
  const _EmptySlot({required this.onTap, required this.color});

  final VoidCallback onTap;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Column(
          children: [
            Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(
                  color: color.withValues(alpha: 0.6),
                  width: 2,
                ),
              ),
              child: Icon(Icons.add_rounded, color: color),
            ),
            const SizedBox(height: 8),
            Text(
              'Rozet ekle',
              style: theme.textTheme.labelMedium?.copyWith(color: color),
            ),
          ],
        ),
      ),
    );
  }
}

/// Kazanılan rozetler arasından vitrine seçim.
class _ShowcasePicker extends ConsumerWidget {
  const _ShowcasePicker({required this.stats, required this.earned});

  final GameStats stats;
  final Set<String> earned;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final shownIds = {
      for (final b in ref.watch(profileStyleProvider).showcaseBadges(earned))
        b.id,
    };
    final available = badges.where((b) => earned.contains(b.id)).toList();

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.7,
        ),
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
              child: Text(
                'Vitrine en fazla $showcaseSize rozet koyabilirsin. '
                'Doluyken eklediğin, en eskisinin yerini alır.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            for (final badge in available)
              ListTile(
                leading: BadgeMedal(badge: badge, earned: true, size: 40),
                title: Text(badge.title),
                subtitle: Text(badge.description),
                trailing: Icon(
                  shownIds.contains(badge.id)
                      ? Icons.star_rounded
                      : Icons.star_outline_rounded,
                  color: shownIds.contains(badge.id) ? AppColors.warning : null,
                ),
                onTap: () {
                  Haptics.tap();
                  ref
                      .read(profileStyleProvider.notifier)
                      .toggleShowcase(badge.id, earned);
                },
              ),
          ],
        ),
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.icon, required this.value, required this.label});

  final IconData icon;
  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(height: 4),
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

/// Avatar, renk ve çerçeve seçimi; değişiklikler anında uygulanır.
Future<void> showProfileEditor(BuildContext context) {
  Haptics.tap();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _ProfileEditor(),
  );
}

class _ProfileEditor extends ConsumerWidget {
  const _ProfileEditor();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final style = ref.watch(profileStyleProvider);
    final notifier = ref.read(profileStyleProvider.notifier);
    final level = ref.watch(gameProvider).value?.level.level ?? 1;
    final current = style.frameFor(level);
    final label = theme.textTheme.labelMedium?.copyWith(
      fontWeight: FontWeight.w800,
      letterSpacing: 1.2,
      color: theme.colorScheme.primary,
    );

    return SafeArea(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.85,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: PlayerAvatar.of(style, level: level, size: 88)),
              const SizedBox(height: 20),
              Text('AVATAR', style: label),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final emoji in avatarEmojis)
                    _Choice(
                      selected: emoji == style.emoji,
                      onTap: () => notifier.setEmoji(emoji),
                      child: Text(
                        emoji,
                        textScaler: TextScaler.noScaling,
                        style: const TextStyle(fontSize: 24),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('RENK', style: label),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (i, color) in avatarColors.indexed)
                    _Choice(
                      selected: i == style.colorIndex % avatarColors.length,
                      onTap: () => notifier.setColor(i),
                      child: Container(
                        width: 28,
                        height: 28,
                        decoration: BoxDecoration(
                          color: color,
                          shape: BoxShape.circle,
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 20),
              Text('ÇERÇEVE', style: label),
              const SizedBox(height: 10),
              Row(
                children: [
                  for (final frame in AvatarFrame.values)
                    Expanded(
                      child: _FrameOption(
                        frame: frame,
                        style: style,
                        locked: !frame.unlockedAt(level),
                        selected: frame == current,
                        onTap: () => notifier.setFrame(frame),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              // Alt sayfa açıkken SnackBar arkada kalıyordu; bilgi burada.
              Text(
                'Çerçeveler oyuncu seviyenle açılır: '
                '${[for (final f in AvatarFrame.values.skip(1)) '${f.label} Lv ${f.unlockLevel}'].join(', ')}. Şu an Lv $level.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Choice extends StatelessWidget {
  const _Choice({
    required this.selected,
    required this.onTap,
    required this.child,
  });

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      button: true,
      selected: selected,
      child: GestureDetector(
      onTap: () {
        Haptics.tap();
        onTap();
      },
      child: AnimatedContainer(
        duration: Motion.fast,
        width: 48,
        height: 48,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: theme.colorScheme.surfaceContainerHighest,
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 2.5,
          ),
        ),
        child: child,
      ),
    ),
    );
  }
}

class _FrameOption extends StatelessWidget {
  const _FrameOption({
    required this.frame,
    required this.style,
    required this.locked,
    required this.selected,
    required this.onTap,
  });

  final AvatarFrame frame;
  final ProfileStyle style;
  final bool locked;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: locked
          ? null
          : () {
              Haptics.tap();
              onTap();
            },
      child: AnimatedContainer(
        duration: Motion.fast,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? theme.colorScheme.primary : Colors.transparent,
            width: 2,
          ),
        ),
        child: Column(
          children: [
            Opacity(
              opacity: locked ? 0.35 : 1,
              child: PlayerAvatar(
                emoji: style.emoji,
                color: style.color,
                frame: frame,
                size: 48,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              locked ? 'Lv ${frame.unlockLevel}' : frame.label,
              style: theme.textTheme.labelSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            if (locked)
              Icon(
                Icons.lock_rounded,
                size: 12,
                color: theme.colorScheme.outline,
              ),
          ],
        ),
      ),
    );
  }
}
