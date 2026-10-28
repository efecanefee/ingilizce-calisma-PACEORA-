import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';

/// İlerleme: seri takvimi, haftalık skor grafiği ve genel istatistikler.
class ProgressScreen extends ConsumerWidget {
  const ProgressScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final progress = ref.watch(progressProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('İlerlemem')),
      body: switch (progress) {
        AsyncError(:final error) => Center(child: Text('$error')),
        AsyncData(:final value) => _ProgressBody(data: value),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({required this.data});

  final ProgressData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final title = theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 12,
          crossAxisSpacing: 12,
          childAspectRatio: 1.7,
          children: [
            _StatTile(
              icon: Icons.local_fire_department,
              label: 'Şu anki seri',
              value: data.currentStreak,
              suffix: ' gün',
              color: AppColors.warning,
            ),
            _StatTile(
              icon: Icons.emoji_events,
              label: 'En uzun seri',
              value: data.bestStreak,
              suffix: ' gün',
              color: AppColors.success,
            ),
            _StatTile(
              icon: Icons.school,
              label: 'Biten ders',
              value: data.lessonsCompleted,
              color: theme.colorScheme.primary,
            ),
            _StatTile(
              icon: Icons.style,
              label: 'Öğrenilen kart',
              value: data.cardsMature,
              suffix: '/${data.cardsTotal}',
              color: AppColors.limeDim,
            ),
          ].indexed.map((e) => e.$2.entrance(e.$1)).toList(),
        ),
        const SizedBox(height: 28),
        Text('Seri takvimi', style: title).entrance(4),
        const SizedBox(height: 4),
        Text(
          'Son 5 hafta — çalıştığın her gün yanar.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ).entrance(4),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: _StreakCalendar(days: data.studiedDays),
          ),
        ).entrance(5),
        const SizedBox(height: 28),
        Text('Haftalık skor', style: title).entrance(6),
        const SizedBox(height: 4),
        Text(
          'Ders testlerindeki ortalama başarı, son 8 hafta.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ).entrance(6),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(12, 20, 12, 12),
            child: _WeeklyScoreChart(scores: data.weeklyScores),
          ),
        ).entrance(7),
        const SizedBox(height: 12),
        Text(
          'Toplam ders süresi: ${data.totalMinutes} dakika',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall,
        ).entrance(8),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
    this.suffix = '',
  });

  final IconData icon;
  final String label;
  final int value;
  final String suffix;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    label,
                    style: theme.textTheme.labelMedium,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            CountUpText(
              value: value,
              suffix: suffix,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
          ],
        ),
      ),
    );
  }
}

/// Pazartesiden başlayan 5 haftalık ızgara; bugün çerçeveli.
class _StreakCalendar extends StatelessWidget {
  const _StreakCalendar({required this.days});

  final Set<DateTime> days;

  static const _weeks = 5;
  static const _labels = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final today = dayOf(DateTime.now());
    final firstMonday = DateTime(
      mondayOf(today).year,
      mondayOf(today).month,
      mondayOf(today).day - 7 * (_weeks - 1),
    );
    final lit = isDark ? AppColors.limeSpark : AppColors.limeDark;

    return Column(
      children: [
        Row(
          children: [
            for (final label in _labels)
              Expanded(
                child: Center(
                  child: Text(label, style: theme.textTheme.labelSmall),
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        for (var w = 0; w < _weeks; w++)
          Row(
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: Builder(builder: (context) {
                    final date = DateTime(
                      firstMonday.year,
                      firstMonday.month,
                      firstMonday.day + w * 7 + d,
                    );
                    final studied = days.contains(date);
                    final isToday = date == today;
                    final future = date.isAfter(today);

                    final cell = AspectRatio(
                      aspectRatio: 1,
                      child: Container(
                        margin: const EdgeInsets.all(3),
                        decoration: BoxDecoration(
                          color: studied
                              ? lit
                              : future
                                  ? Colors.transparent
                                  : theme.colorScheme.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(8),
                          border: isToday
                              ? Border.all(
                                  color: theme.colorScheme.onSurface,
                                  width: 2,
                                )
                              : null,
                        ),
                        child: Center(
                          child: Text(
                            '${date.day}',
                            style: theme.textTheme.labelSmall?.copyWith(
                              fontWeight:
                                  studied ? FontWeight.w800 : FontWeight.w400,
                              // Açık temada zemin koyu yeşil: yazı beyaz.
                              color: studied
                                  ? (isDark ? AppColors.graphite900 : Colors.white)
                                  : theme.colorScheme.onSurface.withValues(
                                      alpha: future ? 0.25 : 0.6,
                                    ),
                            ),
                          ),
                        ),
                      ),
                    );

                    final delay = (w * 7 + d) * 18;
                    return studied
                        ? cell
                            .animate(delay: delay.ms)
                            .scale(
                              begin: const Offset(0.4, 0.4),
                              duration: Motion.medium,
                              curve: Curves.elasticOut,
                            )
                            .fadeIn()
                        : cell.animate(delay: delay.ms).fadeIn(duration: Motion.fast);
                  }),
                ),
            ],
          ),
      ],
    );
  }
}

/// Haftalık ortalama skor çubukları; çubuklar sırayla büyüyerek gelir.
class _WeeklyScoreChart extends StatelessWidget {
  const _WeeklyScoreChart({required this.scores});

  final List<({DateTime weekStart, double? average})> scores;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    const maxHeight = 150.0;

    if (scores.every((s) => s.average == null)) {
      return SizedBox(
        height: maxHeight,
        child: Center(
          child: Text(
            'Ders bitirdikçe burada haftalık skorların görünecek.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
        ),
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (final (i, week) in scores.indexed)
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  height: 18,
                  child: week.average == null
                      ? null
                      : Text(
                          '${week.average!.round()}',
                          style: theme.textTheme.labelSmall
                              ?.copyWith(fontWeight: FontWeight.w700),
                        ).animate(delay: (300 + i * 80).ms).fadeIn(),
                ),
                const SizedBox(height: 4),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: (week.average ?? 0) / 100),
                  duration: Motion.slow + Duration(milliseconds: i * 80),
                  curve: Curves.easeOutBack,
                  builder: (context, v, _) => Container(
                    height: week.average == null ? 4 : (maxHeight * v).clamp(4, maxHeight),
                    margin: const EdgeInsets.symmetric(horizontal: 5),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(8),
                      gradient: week.average == null
                          ? null
                          : LinearGradient(
                              begin: Alignment.bottomCenter,
                              end: Alignment.topCenter,
                              colors: isDark
                                  ? [AppColors.limeDark, AppColors.limeSpark]
                                  : [AppColors.limeDim, AppColors.limeDark],
                            ),
                      color: week.average == null
                          ? theme.colorScheme.surfaceContainerHighest
                          : null,
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  i == scores.length - 1
                      ? 'Bu h.'
                      : '${week.weekStart.day}/${week.weekStart.month}',
                  style: theme.textTheme.labelSmall?.copyWith(
                    fontWeight: i == scores.length - 1 ? FontWeight.w800 : null,
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
