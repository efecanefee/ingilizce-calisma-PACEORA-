import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants.dart';
import '../../../app/motion.dart';
import '../../../app/theme.dart';
import '../../../app/turkish_text.dart';
import '../../../data/database.dart';
import '../../../data/providers.dart';
import 'profile_form.dart';

/// Ayarların en üstündeki profil kartı: baş harf, ad, seviye ve özet sayılar.
class ProfileHeader extends ConsumerWidget {
  const ProfileHeader({super.key, required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final game = ref.watch(gameProvider).value;
    final cards = ref.watch(flashcardSummaryProvider).value;
    final first = user.name.isEmpty ? '?' : user.name.characters.first;
    final initial = trUpper(first);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.graphite900,
            AppColors.graphite700,
            context.pace.accentDark,
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [context.pace.accent, context.pace.accentDim],
                      ),
                    ),
                    child: Text(
                      initial,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.graphite900,
                      ),
                    ),
                  )
                  .animate(onPlay: Motion.loop(reverse: true))
                  .boxShadow(
                    begin: const BoxShadow(
                      color: Colors.transparent,
                      blurRadius: 0,
                    ),
                    end: BoxShadow(
                      color: context.pace.accent.withValues(alpha: 0.5),
                      blurRadius: 18,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    duration: 1400.ms,
                  ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DifficultyLevel.fromCode(user.level).code} · '
                      '${game == null ? '' : 'Lv ${game.level.level} ${game.level.title}'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.pace.accent,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Profili düzenle',
                onPressed: () => openProfileSheet(context, user),
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeaderStat(
                value: ref.watch(streakDisplayProvider).streak,
                label: 'gün seri',
              ),
              _HeaderStat(value: game?.stats.lessons ?? 0, label: 'ders'),
              _HeaderStat(value: cards?.total ?? 0, label: 'kart'),
              _HeaderStat(value: game?.level.xp ?? 0, label: 'XP'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          CountUpText(
            value: value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
