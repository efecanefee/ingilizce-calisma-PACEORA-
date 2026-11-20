import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/profile_style.dart';
import '../data/rewards.dart';
import 'motion.dart';
import 'theme.dart';

/// Rozetin ayrıntısı; kazanılmışsa vitrine ekleme/çıkarma düğmesiyle.
Future<void> showBadgeSheet(
  BuildContext context, {
  required BadgeDef badge,
  required GameStats stats,
}) {
  Haptics.tap();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    builder: (_) => _BadgeSheet(badge: badge, stats: stats),
  );
}

class _BadgeSheet extends ConsumerWidget {
  const _BadgeSheet({required this.badge, required this.stats});

  final BadgeDef badge;
  final GameStats stats;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final earned = badge.earnedBy(stats);
    final earnedIds = GameState(stats).earnedBadgeIds;
    final style = ref.watch(profileStyleProvider);
    final inShowcase = style
        .showcaseBadges(earnedIds)
        .any((b) => b.id == badge.id);

    return SafeArea(
      // Kısa ekranda taşmasın diye kaydırılabilir.
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            BadgeMedal(badge: badge, earned: earned, size: 84),
            const SizedBox(height: 16),
            Text(
              badge.title,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(badge.description, textAlign: TextAlign.center),
            const SizedBox(height: 14),
            Text(
              earned
                  ? 'Kazandın!'
                  : 'İlerleme: ${badge.progressOf(stats)}/${badge.target}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: earned ? AppColors.success : theme.colorScheme.primary,
              ),
            ),
            if (earned) ...[
              const SizedBox(height: 18),
              inShowcase
                  ? OutlinedButton.icon(
                      onPressed: () => ref
                          .read(profileStyleProvider.notifier)
                          .toggleShowcase(badge.id, earnedIds),
                      icon: const Icon(Icons.remove_circle_outline),
                      label: const Text('Vitrinden çıkar'),
                    )
                  : FilledButton.icon(
                      onPressed: () => ref
                          .read(profileStyleProvider.notifier)
                          .toggleShowcase(badge.id, earnedIds),
                      icon: const Icon(Icons.star_rounded),
                      label: const Text('Vitrine ekle'),
                    ),
              const SizedBox(height: 6),
              Text(
                'Vitrindeki $showcaseSize rozet profilinde görünür.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Rozet madalyası: kazanıldıysa renkli ve parıltılı, değilse kilitli.
class BadgeMedal extends StatelessWidget {
  const BadgeMedal({
    super.key,
    required this.badge,
    required this.earned,
    required this.size,
  });

  final BadgeDef badge;
  final bool earned;
  final double size;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final medal = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: earned
            ? RadialGradient(
                colors: [badge.color, badge.color.withValues(alpha: 0.6)],
              )
            : null,
        color: earned ? null : theme.colorScheme.surfaceContainerHighest,
        boxShadow: earned
            ? [
                BoxShadow(
                  color: badge.color.withValues(alpha: 0.45),
                  blurRadius: 12,
                ),
              ]
            : null,
      ),
      child: Icon(
        earned ? badge.icon : Icons.lock_rounded,
        size: size * 0.5,
        color: earned ? AppColors.graphite900 : theme.colorScheme.outline,
      ),
    );
    return earned
        ? medal
              .animate(onPlay: Motion.loop())
              .shimmer(
                delay: 3.seconds,
                duration: 1.seconds,
                color: Colors.white,
              )
        : medal;
  }
}
