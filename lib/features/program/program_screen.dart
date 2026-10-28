import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';

/// Haftalık program: günler bir zaman çizelgesinde, bugün öne çıkarılmış.
class ProgramScreen extends ConsumerWidget {
  const ProgramScreen({super.key});

  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(weekPlanProvider.notifier).regenerate();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.offline
                ? 'Gemini\'ye ulaşılamadı; hazır program yüklendi.'
                : 'Haftalık programın yenilendi.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Plan yenilenemedi: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final plan = ref.watch(weekPlanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Haftalık program'),
        actions: [
          IconButton(
            tooltip: 'Programı yenile',
            onPressed: plan.isLoading ? null : () => _regenerate(context, ref),
            icon: const Icon(Icons.autorenew_rounded),
          ),
        ],
      ),
      body: switch (plan) {
        AsyncError(:final error) => Center(child: Text('$error')),
        AsyncData(:final value) when value.days.isEmpty => const Center(
          child: Text('Bu hafta için program yok. Yenile düğmesine dokun.'),
        ),
        AsyncData(:final value) => _Timeline(week: value),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Bir günün takvimdeki konumu.
enum _DayState { done, today, missed, upcoming }

class _Timeline extends StatelessWidget {
  const _Timeline({required this.week});

  final WeekPlan week;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final todayIndex = DateTime.now().weekday - DateTime.monday;
    final monday = mondayOf(DateTime.now());
    final done = week.days.where((d) => d.status == 'completed').length;

    _DayState stateOf(WeeklyPlanDay day) {
      if (day.status == 'completed') return _DayState.done;
      if (day.dayIndex == todayIndex) return _DayState.today;
      return day.dayIndex < todayIndex ? _DayState.missed : _DayState.upcoming;
    }

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _WeekHeader(
          monday: monday,
          done: done,
          total: week.days.length,
          offline: week.offline,
        ).entrance(0),
        const SizedBox(height: 24),
        for (final (i, day) in week.days.indexed)
          _TimelineRow(
            day: day,
            date: DateTime(
              monday.year,
              monday.month,
              monday.day + day.dayIndex,
            ),
            state: stateOf(day),
            isFirst: i == 0,
            isLast: i == week.days.length - 1,
          ).entrance(i + 1),
        const SizedBox(height: 8),
        Text(
          'Pazar günleri haftanın tekrarına ayrılır. Program her pazartesi '
          'seviyene göre kendiliğinden yenilenir.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ).entrance(9),
      ],
    );
  }
}

class _WeekHeader extends StatelessWidget {
  const _WeekHeader({
    required this.monday,
    required this.done,
    required this.total,
    required this.offline,
  });

  final DateTime monday;
  final int done;
  final int total;
  final bool offline;

  static const _months = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final sunday = DateTime(monday.year, monday.month, monday.day + 6);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [AppColors.graphite700, AppColors.limeDark]
              : [AppColors.limeDark, const Color(0xFF7A9A1E)],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${monday.day} ${_months[monday.month - 1]} – '
            '${sunday.day} ${_months[sunday.month - 1]}',
            style: theme.textTheme.labelLarge?.copyWith(
              color: Colors.white.withValues(alpha: 0.85),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              CountUpText(
                value: done,
                style: theme.textTheme.displaySmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: Colors.white,
                ),
              ),
              Padding(
                padding: const EdgeInsets.only(bottom: 8, left: 4),
                child: Text(
                  '/ $total gün tamam',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white.withValues(alpha: 0.85),
                  ),
                ),
              ),
              const Spacer(),
              if (offline)
                Tooltip(
                  message: 'Hazır program (çevrimdışı)',
                  child: Icon(
                    Icons.cloud_off,
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: total == 0 ? 0 : done / total),
              duration: Motion.slow,
              curve: Motion.curve,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 10,
                color: AppColors.limeSpark,
                backgroundColor: Colors.white.withValues(alpha: 0.2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TimelineRow extends StatelessWidget {
  const _TimelineRow({
    required this.day,
    required this.date,
    required this.state,
    required this.isFirst,
    required this.isLast,
  });

  final WeeklyPlanDay day;
  final DateTime date;
  final _DayState state;
  final bool isFirst;
  final bool isLast;

  void _showDetails(BuildContext context) {
    Haptics.tap();
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) =>
          _DayDetails(day: day, date: date, state: state),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? AppColors.limeSpark : AppColors.limeDark;

    final (icon, color, label) = switch (state) {
      _DayState.done => (Icons.check_rounded, AppColors.success, 'Tamamlandı'),
      _DayState.today => (Icons.play_arrow_rounded, accent, 'Bugün'),
      _DayState.missed => (
        Icons.close_rounded,
        theme.colorScheme.outline,
        'Kaçırıldı',
      ),
      _DayState.upcoming => (
        Icons.lock_clock,
        theme.colorScheme.outline,
        'Yakında',
      ),
    };
    final isToday = state == _DayState.today;
    final lineColor = theme.colorScheme.outlineVariant;

    Widget dot = Container(
      width: isToday ? 34 : 28,
      height: isToday ? 34 : 28,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: state == _DayState.done || isToday
            ? color
            : theme.colorScheme.surfaceContainerHighest,
        boxShadow: isToday
            ? [BoxShadow(color: accent.withValues(alpha: 0.5), blurRadius: 14)]
            : null,
      ),
      child: Icon(
        icon,
        size: 18,
        color: state == _DayState.done || isToday
            ? (isDark ? AppColors.graphite900 : Colors.white)
            : theme.colorScheme.outline,
      ),
    );
    if (isToday) {
      dot = dot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 1,
            end: 1.12,
            duration: 900.ms,
            curve: Curves.easeInOut,
          );
    }

    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(
            width: 44,
            child: Column(
              children: [
                Container(
                  width: 2,
                  height: 18,
                  color: isFirst ? Colors.transparent : lineColor,
                ),
                dot,
                Expanded(
                  child: Container(
                    width: 2,
                    color: isLast ? Colors.transparent : lineColor,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: PressableScale(
                onTap: () => _showDetails(context),
                child: Ink(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.surfaceContainer,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: isToday
                          ? accent
                          : theme.colorScheme.outlineVariant,
                      width: isToday ? 2 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(
                            '${AppConstants.weekdayNames[day.dayIndex]} · '
                            '${date.day}.${date.month}',
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: theme.colorScheme.onSurface.withValues(
                                alpha: 0.6,
                              ),
                            ),
                          ),
                          const Spacer(),
                          Text(
                            label,
                            style: theme.textTheme.labelMedium?.copyWith(
                              color: color,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        day.grammarTopic,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          color: state == _DayState.missed
                              ? theme.colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                )
                              : null,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        day.vocabTheme,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(
                            alpha: 0.65,
                          ),
                        ),
                      ),
                      if (isToday) ...[
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton.icon(
                            onPressed: () => context.push('/lesson'),
                            icon: const Icon(Icons.play_arrow_rounded),
                            label: const Text('Derse git'),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DayDetails extends StatelessWidget {
  const _DayDetails({
    required this.day,
    required this.date,
    required this.state,
  });

  final WeeklyPlanDay day;
  final DateTime date;
  final _DayState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final note = switch (state) {
      _DayState.done =>
        'Bu günü tamamladın. Dersi tekrar açıp gözden geçirebilirsin.',
      _DayState.today =>
        'Bugünün konusu bu. Ders yaklaşık günlük süren kadar sürer.',
      _DayState.missed =>
        'Bu gün kaçırıldı. Pazar günkü tekrar dersinde bu konuya da değinilir.',
      _DayState.upcoming =>
        'Bu gün henüz gelmedi; o gün ders konuya göre üretilecek.',
    };

    // Alt sayfa ekranın yarısıyla sınırlı; kısa ekranlarda ve büyük yazı
    // boyutunda içerik taşmasın diye kaydırılabilir.
    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${AppConstants.weekdayNames[day.dayIndex]}, ${date.day}.${date.month}',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
            _DetailRow(
              icon: Icons.menu_book_rounded,
              title: 'Dilbilgisi',
              value: day.grammarTopic,
            ),
            const SizedBox(height: 12),
            _DetailRow(
              icon: Icons.style_rounded,
              title: 'Kelime teması',
              value: day.vocabTheme,
            ),
            const SizedBox(height: 16),
            Text(note, style: theme.textTheme.bodyMedium),
            // Ders ekranı her zaman bugünün dersini açar; geçmiş günler için
            // buton gösterilmez.
            if (date == dayOf(DateTime.now())) ...[
              const SizedBox(height: 20),
              FilledButton(
                onPressed: () {
                  Navigator.of(context).pop();
                  context.push('/lesson');
                },
                child: Text(
                  state == _DayState.today ? 'Derse başla' : 'Dersi aç',
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  final IconData icon;
  final String title;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: theme.colorScheme.primary),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: theme.textTheme.labelMedium),
              Text(
                value,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
