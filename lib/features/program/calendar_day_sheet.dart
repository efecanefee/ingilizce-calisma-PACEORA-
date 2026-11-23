import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants.dart';
import '../../app/mascot.dart';
import '../../app/motion.dart';
import '../../data/database.dart';
import '../../data/lesson_models.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';

/// Takvimdeki bir günün ayrıntısı: plan, ders kaydı ve çözümün kendisi.
class CalendarDay {
  const CalendarDay({
    required this.date,
    required this.plan,
    required this.lesson,
    required this.state,
    required this.studied,
    required this.programStart,
  });

  final DateTime date;
  final WeeklyPlanDay? plan;
  final Lesson? lesson;

  /// Kayıtlı dersin içeriği ve cevapları; ders yoksa null.
  final LessonState? state;
  final bool studied;
  final DateTime? programStart;
}

final calendarDayProvider = FutureProvider.autoDispose
    .family<CalendarDay, DateTime>((ref, date) async {
      ref.watch(weekPlanProvider);
      final repository = ref.read(repositoryProvider);
      final lesson = await repository.lessonFor(date);
      return CalendarDay(
        date: dayOf(date),
        plan: await repository.planDayOn(date),
        lesson: lesson,
        state: lesson == null ? null : LessonState.decode(lesson.contentJson),
        studied: (await repository.studiedDays()).contains(dayOf(date)),
        programStart: await repository.programStart(),
      );
    });

/// Takvimdeki güne dokununca açılır.
void showCalendarDaySheet(BuildContext context, DateTime date) {
  Haptics.tap();
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => CalendarDaySheet(date: dayOf(date)),
  );
}

/// Günün durumu.
enum CalendarDayKind { studied, today, upcoming, missed, beforeStart, empty }

CalendarDayKind kindOf(CalendarDay day, DateTime today) {
  final start = day.programStart == null ? null : dayOf(day.programStart!);
  if (day.studied) return CalendarDayKind.studied;
  if (day.date == today) return CalendarDayKind.today;
  if (start == null || day.date.isBefore(start)) {
    return CalendarDayKind.beforeStart;
  }
  if (day.date.isAfter(today)) {
    return day.plan == null ? CalendarDayKind.empty : CalendarDayKind.upcoming;
  }
  return day.plan == null ? CalendarDayKind.empty : CalendarDayKind.missed;
}

/// "2026-11-16" — ders rotasındaki tarih.
String routeDate(DateTime d) =>
    '${d.year}-${d.month.toString().padLeft(2, '0')}-'
    '${d.day.toString().padLeft(2, '0')}';

const _months = [
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

String longDate(DateTime d) =>
    '${AppConstants.weekdayNames[d.weekday - 1]}, ${d.day} ${_months[d.month - 1]}';

class CalendarDaySheet extends ConsumerWidget {
  const CalendarDaySheet({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final data = ref.watch(calendarDayProvider(date)).value;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: data == null
            ? const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              )
            : _Body(day: data, theme: theme),
      ),
    );
  }
}

class _Body extends ConsumerStatefulWidget {
  const _Body({required this.day, required this.theme});

  final CalendarDay day;
  final ThemeData theme;

  @override
  ConsumerState<_Body> createState() => _BodyState();
}

class _BodyState extends ConsumerState<_Body> {
  var _busy = false;

  Future<void> _changeTopic(WeeklyPlanDay plan) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final topic = await ref.read(weekPlanProvider.notifier).replaceDay(plan);
    if (!mounted) return;
    setState(() => _busy = false);
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          topic == null
              ? 'Yeni bir konu bulunamadı; daha sonra tekrar dene.'
              : 'Konu değişti: $topic',
        ),
      ),
    );
  }

  void _open(String path) {
    final router = GoRouter.of(context);
    Navigator.of(context).pop();
    router.push(path);
  }

  @override
  Widget build(BuildContext context) {
    final theme = widget.theme;
    final day = widget.day;
    final kind = kindOf(day, dayOf(clock.now()));
    final plan = day.plan;
    final lesson = day.lesson;
    final state = day.state;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.65);

    final (String badge, Color badgeColor) = switch (kind) {
      CalendarDayKind.studied => ('Çalıştın', theme.colorScheme.primary),
      CalendarDayKind.today => ('Bugün', theme.colorScheme.primary),
      CalendarDayKind.upcoming => ('Yakında', muted),
      CalendarDayKind.missed => ('Kaçırıldı', theme.colorScheme.error),
      CalendarDayKind.beforeStart => ('Programdan önce', muted),
      CalendarDayKind.empty => ('Program yok', muted),
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                longDate(day.date),
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            Text(
              badge,
              style: theme.textTheme.labelLarge?.copyWith(
                color: badgeColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        if (plan != null) ...[
          _Row(
            icon: Icons.menu_book_rounded,
            label: 'Dilbilgisi',
            value: plan.grammarTopic,
          ),
          _Row(
            icon: Icons.style_rounded,
            label: 'Kelime teması',
            value: plan.vocabTheme,
          ),
        ],
        if (kind == CalendarDayKind.studied && lesson != null) ...[
          const SizedBox(height: 6),
          Row(
            children: [
              _Stat(
                value: lesson.score == null ? '–' : '%${lesson.score!.round()}',
                label: 'puan',
              ),
              _Stat(
                value: '${(lesson.durationSeconds / 60).ceil()} dk',
                label: 'süre',
              ),
              _Stat(
                value: '${state?.lesson.vocab.length ?? 0}',
                label: 'kelime',
              ),
              _Stat(
                value:
                    '${state?.outcomes().where((o) => !o.correct).length ?? 0}',
                label: 'hata',
              ),
            ],
          ),
          if (state != null && state.lesson.vocab.isNotEmpty) ...[
            const SizedBox(height: 14),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final v in state.lesson.vocab)
                  Chip(
                    visualDensity: VisualDensity.compact,
                    label: Text('${v.word} · ${v.meaning}'),
                  ),
              ],
            ),
          ],
        ],
        const SizedBox(height: 16),
        ...switch (kind) {
          CalendarDayKind.studied =>
            state == null
                ? [
                    Text(
                      'Bu gün tamamlandı olarak işaretlendi; kayıtlı bir ders '
                      'yok.',
                      style: theme.textTheme.bodyMedium?.copyWith(color: muted),
                    ),
                  ]
                : [
                    _Action(
                      icon: Icons.replay_rounded,
                      label: 'Bu dersi tekrar çöz',
                      onPressed: () =>
                          _open('/lesson/replay/${routeDate(day.date)}'),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Tekrar çözmek puanını ve serini değiştirmez.',
                      style: theme.textTheme.bodySmall?.copyWith(color: muted),
                    ),
                  ],
          CalendarDayKind.today => [
            _Action(
              icon: Icons.play_arrow_rounded,
              label: 'Derse başla',
              onPressed: () => _open('/lesson'),
            ),
          ],
          CalendarDayKind.upcoming => [
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                minimumSize: const Size.fromHeight(48),
              ),
              onPressed: _busy ? null : () => _changeTopic(plan!),
              icon: _busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.shuffle_rounded),
              label: const Text('Bu konuyu değiştir'),
            ),
          ],
          CalendarDayKind.missed => [
            const Center(child: PaceSticker(PacePose.sleep, size: 100)),
            const SizedBox(height: 12),
            _Action(
              icon: Icons.history_rounded,
              label: 'Telafi et',
              onPressed: () => _open('/lesson/makeup/${routeDate(day.date)}'),
            ),
            const SizedBox(height: 6),
            Text(
              'O günün dersini şimdi yapabilirsin. Gün tamamlanmış sayılır; '
              'seri yalnızca gününde çalışınca uzar.',
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
          CalendarDayKind.beforeStart => [
            Text(
              day.programStart == null
                  ? 'Programın henüz başlamadı.'
                  : 'Programın ${longDate(day.programStart!)} günü başladı.',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ],
          CalendarDayKind.empty => [
            Text(
              'Bu gün için program yoktu.',
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
          ],
        },
      ],
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: theme.textTheme.labelMedium),
                Text(
                  value,
                  style: theme.textTheme.bodyLarge?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
      onPressed: onPressed,
      icon: Icon(icon),
      label: Text(label),
    );
  }
}
