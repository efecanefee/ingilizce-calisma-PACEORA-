import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants.dart';
import '../../app/logo.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/rewards.dart';

/// Ana ekran ("Bugün" sekmesi): karşılama, bugünün dersi, günlük hedef,
/// haftanın özeti ve pratik alanları.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final plan = ref.watch(weekPlanProvider);

    return Scaffold(
      appBar: AppBar(title: const PaceoraWordmark(markSize: 28)),
      body: switch ((profile, plan)) {
        (AsyncError(:final error), _) || (_, AsyncError(:final error)) =>
          _ErrorView(message: '$error'),
        (AsyncData(value: null), _) => const _NoProfileView(),
        (AsyncData(value: final user?), AsyncData(value: final week)) =>
          _HomeBody(user: user, week: week),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.user, required this.week});

  final UserProfile user;
  final WeekPlan week;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = week.today;
    final lesson = ref.watch(todayLessonProvider).value;
    final game = ref.watch(gameProvider).value;
    final sectionStyle = Theme.of(context)
        .textTheme
        .titleMedium
        ?.copyWith(fontWeight: FontWeight.w700);

    var index = 0;
    Widget item(Widget child) => child.entrance(index++);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(gameProvider);
        ref.invalidate(flashcardSummaryProvider);
        await ref.read(gameProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          item(_HeroCard(user: user, level: game?.level)),
          const SizedBox(height: 16),
          if (week.offline) ...[
            item(const _OfflineBadge()),
            const SizedBox(height: 12),
          ],
          if (today == null)
            item(const _EmptyPlanCard())
          else
            item(
              _TodayCard(
                day: today,
                dailyMinutes: user.dailyMinutes,
                lesson: lesson,
                onStudy: () => context.push('/lesson'),
                onComplete: () =>
                    ref.read(weekPlanProvider.notifier).completeDay(today),
              ),
            ),
          const SizedBox(height: 16),
          item(const _DailyGoalCard()),
          const SizedBox(height: 28),
          item(
            Row(
              children: [
                Text('Bu hafta', style: sectionStyle),
                const Spacer(),
                TextButton(
                  onPressed: () => context.go('/program'),
                  child: const Text('Programı gör'),
                ),
              ],
            ),
          ),
          item(_WeekStrip(week: week)),
          const SizedBox(height: 28),
          item(Text('Pratik alanı', style: sectionStyle)),
          const SizedBox(height: 12),
          item(const _PracticeGrid()),
        ],
      ),
    );
  }
}

/// Hareketli gradyanlı karşılama kartı: selam, seri ve oyuncu seviyesi.
class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.user, required this.level});

  final UserProfile user;
  final PlayerLevel? level;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard>
    with SingleTickerProviderStateMixin {
  // Gradyanın yavaşça "nefes alması" kartı canlı gösterir.
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;
    final level = widget.level;
    const onHero = Colors.white;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment(-1 + t, -1),
              end: Alignment(1, 1 - t),
              colors: const [
                AppColors.graphite900,
                AppColors.graphite700,
                AppColors.limeDark,
              ],
              stops: [0, 0.55 + 0.15 * t, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: AppColors.limeDark.withValues(alpha: 0.25 + 0.15 * t),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Stack(
        children: [
          // Köşede dönen soluk şimşek: markanın imzası.
          Positioned(
            right: -18,
            top: -18,
            child: Icon(
              Icons.bolt_rounded,
              size: 140,
              color: AppColors.limeSpark.withValues(alpha: 0.08),
            )
                .animate(onPlay: (c) => c.repeat(reverse: true))
                .rotate(begin: -0.03, end: 0.03, duration: 3.seconds),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Merhaba, ${user.name}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: onHero,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Seviye ${DifficultyLevel.fromCode(user.level).label} · '
                            'günde ${user.dailyMinutes} dk',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: onHero.withValues(alpha: 0.75),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    _StreakChip(streak: user.streak),
                  ],
                ),
                const SizedBox(height: 20),
                if (level != null) _XpBar(level: level),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _StreakChip extends StatelessWidget {
  const _StreakChip({required this.streak});

  final int streak;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          PulsingFlame(active: streak > 0),
          const SizedBox(width: 6),
          // Seri arttığında yeni sayı aşağıdan kayarak gelir.
          AnimatedSwitcher(
            duration: Motion.medium,
            transitionBuilder: (child, animation) => SlideTransition(
              position: Tween(
                begin: const Offset(0, 0.6),
                end: Offset.zero,
              ).animate(animation),
              child: FadeTransition(opacity: animation, child: child),
            ),
            child: Text(
              '$streak gün',
              key: ValueKey(streak),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Oyuncu seviyesi ve bir sonraki seviyeye kalan XP.
class _XpBar extends StatelessWidget {
  const _XpBar({required this.level});

  final PlayerLevel level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.limeSpark,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Lv ${level.level}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.graphite900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Text(
              level.title,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const Spacer(),
            CountUpText(
              value: level.xp,
              suffix: ' XP',
              style: theme.textTheme.labelLarge?.copyWith(
                color: AppColors.limeSpark,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: level.progress),
            duration: const Duration(milliseconds: 900),
            curve: Motion.curve,
            builder: (context, v, _) => Stack(
              children: [
                Container(height: 10, color: Colors.white.withValues(alpha: 0.12)),
                FractionallySizedBox(
                  widthFactor: v.clamp(0.02, 1.0),
                  child: Container(
                    height: 10,
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        colors: [AppColors.limeDim, AppColors.limeSpark],
                      ),
                    ),
                  ),
                ).animate(onPlay: (c) => c.repeat()).shimmer(
                      delay: 2.seconds,
                      duration: 1200.ms,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Seviye ${level.level + 1} için ${level.xpToNext} XP',
          style: theme.textTheme.labelSmall
              ?.copyWith(color: Colors.white.withValues(alpha: 0.65)),
        ),
      ],
    );
  }
}

/// Bugünkü hedef: halka + sıradaki adıma yönlendiren görev listesi.
class _DailyGoalCard extends ConsumerWidget {
  const _DailyGoalCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goal = ref.watch(dailyGoalProvider).value;
    if (goal == null) return const SizedBox.shrink();
    final next = goal.next;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                _GoalRing(progress: goal.progress, complete: goal.complete),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bugünkü hedefin',
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: Motion.medium,
                        child: Text(
                          goal.complete
                              ? 'Hepsi tamam! Serin güvende 🎉'
                              : '${goal.doneCount}/${goal.tasks.length} adım · '
                                  'sıradaki: ${next!.label.toLowerCase()}',
                          key: ValueKey(goal.doneCount),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface
                                .withValues(alpha: 0.7),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final task in goal.tasks)
              _GoalTaskRow(
                task: task,
                done: goal.done.contains(task),
                isNext: task == next,
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalTaskRow extends ConsumerWidget {
  const _GoalTaskRow({
    required this.task,
    required this.done,
    required this.isNext,
  });

  final DailyTask task;
  final bool done;
  final bool isNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    final row = PressableScale(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await context.push(task.route);
        // Satır bu arada listeden kalkmış olabilir; ölü ref kullanılamaz.
        if (!context.mounted) return;
        ref.invalidate(flashcardSummaryProvider);
        ref.invalidate(gameProvider);
      },
      child: AnimatedContainer(
        duration: Motion.medium,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isNext
              ? accent.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.4),
          border: Border.all(
            color: isNext ? accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(task.icon, size: 20, color: done ? AppColors.success : accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                      : null,
                ),
              ),
            ),
            if (isNext)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'SIRADAKİ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: Motion.medium,
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: Icon(
                done ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                key: ValueKey(done),
                color: done ? AppColors.success : theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );

    return isNext
        ? row
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1, end: 1.015, duration: 1100.ms, curve: Curves.easeInOut)
        : row;
  }
}

/// Animasyonla dolan ilerleme halkası.
class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.progress, required this.complete});

  final double progress;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = complete
        ? AppColors.success
        : (isDark ? AppColors.limeSpark : AppColors.limeDark);

    final ring = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (context, v, _) => SizedBox(
        width: 64,
        height: 64,
        child: CustomPaint(
          painter: _RingPainter(
            progress: v,
            color: color,
            track: theme.colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: complete
                ? const Icon(Icons.emoji_events_rounded,
                    color: AppColors.success, size: 28)
                : Text(
                    '%${(v * 100).round().clamp(0, 100)}',
                    style: theme.textTheme.labelLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
          ),
        ),
      ),
    );

    return complete
        ? ring
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .scaleXY(begin: 1, end: 1.08, duration: 900.ms)
        : ring;
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({required this.progress, required this.color, required this.track});

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arcRect, 0, 2 * pi, false, base);

    if (progress <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [color.withValues(alpha: 0.6), color],
        transform: const GradientRotation(-pi / 2),
      ).createShader(rect);
    canvas.drawArc(arcRect, -pi / 2, 2 * pi * progress.clamp(0, 1), false, paint);
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// Haftanın 7 günü tek satırda; dokununca Program sekmesine geçer.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.week});

  final WeekPlan week;

  static const _initials = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.limeSpark : AppColors.limeDark;
    final todayIndex = DateTime.now().weekday - DateTime.monday;
    final status = {for (final d in week.days) d.dayIndex: d.status};

    return PressableScale(
      onTap: () => context.go('/program'),
      child: Ink(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(
                child: Column(
                  children: [
                    Text(
                      _initials[i],
                      style: theme.textTheme.labelSmall?.copyWith(
                        fontWeight: i == todayIndex ? FontWeight.w800 : null,
                        color: i == todayIndex ? accent : null,
                      ),
                    ),
                    const SizedBox(height: 6),
                    _DayDot(
                      done: status[i] == 'completed',
                      today: i == todayIndex,
                      past: i < todayIndex,
                      accent: accent,
                    )
                        .animate(delay: (60 * i).ms)
                        .scale(
                          begin: const Offset(0.3, 0.3),
                          duration: Motion.medium,
                          curve: Curves.easeOutBack,
                        ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _DayDot extends StatelessWidget {
  const _DayDot({
    required this.done,
    required this.today,
    required this.past,
    required this.accent,
  });

  final bool done;
  final bool today;
  final bool past;
  final Color accent;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: 30,
      height: 30,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: done
            ? AppColors.success
            : today
                ? accent.withValues(alpha: 0.15)
                : theme.colorScheme.surfaceContainerHighest
                    .withValues(alpha: past ? 0.9 : 0.4),
        border: today ? Border.all(color: accent, width: 2) : null,
      ),
      child: done
          ? const Icon(Icons.check_rounded, size: 18, color: Colors.white)
          : past
              ? Icon(Icons.remove_rounded,
                  size: 16, color: theme.colorScheme.outline)
              : null,
    );
  }
}

/// Dersin dışındaki çalışma alanlarına kısayollar.
class _PracticeGrid extends ConsumerWidget {
  const _PracticeGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(flashcardSummaryProvider).value;
    final due = cards?.due ?? 0;

    Future<void> open(String route) async {
      await context.push(route);
      if (!context.mounted) return;
      ref.invalidate(flashcardSummaryProvider);
      ref.invalidate(gameProvider);
    }

    final tiles = [
      _PracticeTile(
        icon: Icons.style_rounded,
        title: 'Flash kartlar',
        subtitle: due > 0
            ? '$due kart seni bekliyor'
            : cards == null || cards.total == 0
                ? 'Ders bitirince dolar'
                : 'Bugünlük tamam',
        badge: due > 0 ? '$due' : null,
        onTap: () => open('/flashcards'),
      ),
      _PracticeTile(
        icon: Icons.auto_stories_rounded,
        title: 'Günün hikayesi',
        subtitle: 'Oku ve anla',
        onTap: () => open('/story'),
      ),
      _PracticeTile(
        icon: Icons.edit_note_rounded,
        title: 'Hata defterim',
        subtitle: 'Pekişmeyenler',
        onTap: () => open('/mistakes'),
      ),
      _PracticeTile(
        icon: Icons.assessment_rounded,
        title: 'Haftalık rapor',
        subtitle: 'Seviye önerisi',
        onTap: () => open('/review'),
      ),
    ];

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.45,
      children: [
        for (final (i, tile) in tiles.indexed)
          tile
              .animate(delay: Motion.stagger * i)
              .fadeIn(duration: Motion.medium)
              .scale(begin: const Offset(0.9, 0.9), curve: Curves.easeOutBack),
      ],
    );
  }
}

class _PracticeTile extends StatelessWidget {
  const _PracticeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PressableScale(
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? AppColors.limeSpark : AppColors.limeDark)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: theme.colorScheme.primary),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      badge!,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onPrimary,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .scaleXY(begin: 1, end: 1.12, duration: 800.ms),
              ],
            ),
            const Spacer(),
            Text(
              title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Çevrimdışı plan — Gemini\'ye ulaşılamadığı için hazır program kullanılıyor.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.day,
    required this.dailyMinutes,
    required this.lesson,
    required this.onStudy,
    required this.onComplete,
  });

  final WeeklyPlanDay day;
  final int dailyMinutes;

  /// Bugünkü ders kaydı; henüz üretilmediyse null.
  final Lesson? lesson;

  final VoidCallback onStudy;
  final VoidCallback onComplete;

  /// Tamamlanmış gün için skor/süre özeti.
  ///
  /// Gün elle işaretlenmişse ders kaydı ve skor olmaz; o durumda düz mesaj.
  String _completedSummary() {
    final score = lesson?.score;
    if (score == null) return 'Bugünkü çalışman tamam. Yarın görüşürüz!';

    final minutes = ((lesson?.durationSeconds ?? 0) / 60).ceil();
    final duration = minutes > 0 ? ' · $minutes dk' : '';
    return 'Ders tamam · %${score.round()}$duration';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = day.status == 'completed';
    // Ders başlanmış ama bitmemişse buton "devam et" der.
    final inProgress = lesson != null && !lesson!.completed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'BUGÜN',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '$dailyMinutes dk',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              day.grammarTopic,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(Icons.style_outlined,
                    size: 18, color: theme.colorScheme.outline),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(day.vocabTheme, style: theme.textTheme.bodyMedium),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (done) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: Color(0xFF4ADE80))
                      .animate()
                      .scale(duration: Motion.slow, curve: Curves.elasticOut),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _completedSummary(),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onStudy,
                  child: const Text('Dersi tekrar aç'),
                ),
              ),
            ] else ...[
              FilledButton.icon(
                onPressed: onStudy,
                icon: Icon(inProgress ? Icons.play_arrow : Icons.school_outlined),
                label: Text(inProgress ? 'Derse devam et' : 'Bugünü çalış'),
              )
                  // Ara ara geçen parıltı asıl eyleme dikkat çeker.
                  .animate(onPlay: (c) => c.repeat())
                  .shimmer(
                    delay: 2500.ms,
                    duration: 1200.ms,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
              // Ders üretilemediği ya da başka bir yerde çalışıldığı durumlar
              // için elle işaretleme yolu açık kalıyor.
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onComplete,
                  child: const Text('Çalışmadan tamamlandı işaretle'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyPlanCard extends ConsumerWidget {
  const _EmptyPlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu hafta için henüz plan yok',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('Yeni bir haftalık program oluşturalım.'),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => ref.read(weekPlanProvider.notifier).regenerate(),
              child: const Text('Programımı oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profil yokken ana ekrana düşülürse (ör. prefs sıfırlanmışsa) çıkış yolu.
class _NoProfileView extends StatelessWidget {
  const _NoProfileView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Profilini henüz oluşturmadın.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/onboarding'),
              child: const Text('Kuruluma başla'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.error_outline,
                size: 40, color: Theme.of(context).colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
