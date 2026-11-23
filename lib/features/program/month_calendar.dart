import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';

/// Aylık takvimin verisi: çalışılan günler, programın başladığı gün ve
/// plandaki günlerin konuları.
class ProgramCalendar {
  const ProgramCalendar({
    required this.studied,
    required this.start,
    required this.topics,
  });

  final Set<DateTime> studied;

  /// Programın başladığı gün; henüz plan yoksa null.
  final DateTime? start;

  /// Plandaki her günün dilbilgisi konusu, tarihe göre.
  final Map<DateTime, String> topics;
}

final programCalendarProvider = FutureProvider<ProgramCalendar>((ref) async {
  // Gün tamamlanınca ya da plan yenilenince takvim de tazelenir.
  ref.watch(weekPlanProvider);
  final repository = ref.read(repositoryProvider);
  final plan = await repository.allPlanDays();
  return ProgramCalendar(
    studied: await repository.studiedDays(),
    start: await repository.programStart(),
    topics: {for (final day in plan) planDateOf(day): day.grammarTopic},
  );
});

/// Ay takvimi: hangi gün çalışıldığı, bugün ve programdan önceki günler.
///
/// Program başlamadan önceki günler soluk durur; "kaçırıldı" sayılmaz.
class MonthCalendar extends ConsumerStatefulWidget {
  const MonthCalendar({super.key});

  @override
  ConsumerState<MonthCalendar> createState() => _MonthCalendarState();
}

class _MonthCalendarState extends ConsumerState<MonthCalendar> {
  late DateTime _month = DateTime(clock.now().year, clock.now().month);

  static const _labels = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];
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

  void _shift(int months) {
    Haptics.tap();
    setState(() => _month = DateTime(_month.year, _month.month + months));
  }

  @override
  Widget build(BuildContext context) {
    final data = ref.watch(programCalendarProvider).value;
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final lit = isDark ? context.pace.accent : context.pace.accentDark;
    final today = dayOf(clock.now());
    final start = data?.start == null ? today : dayOf(data!.start!);
    final studied = data?.studied ?? const <DateTime>{};
    final topics = data?.topics ?? const <DateTime, String>{};

    final firstDay = DateTime(_month.year, _month.month);
    final leading = firstDay.weekday - DateTime.monday;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final rows = ((leading + daysInMonth) / 7).ceil();
    final thisMonth = DateTime(today.year, today.month);
    final canGoBack = DateTime(start.year, start.month).isBefore(_month);
    final canGoForward = _month.isBefore(thisMonth);

    final inMonth = studied
        .where((d) => d.year == _month.year && d.month == _month.month)
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            IconButton(
              tooltip: 'Önceki ay',
              onPressed: canGoBack ? () => _shift(-1) : null,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            Expanded(
              child: Column(
                children: [
                  Text(
                    '${_months[_month.month - 1]} ${_month.year}',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '$inMonth gün çalıştın',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Sonraki ay',
              onPressed: canGoForward ? () => _shift(1) : null,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
        const SizedBox(height: 12),
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
        const SizedBox(height: 6),
        for (var w = 0; w < rows; w++)
          Row(
            children: [
              for (var d = 0; d < 7; d++)
                Expanded(
                  child: Builder(
                    builder: (context) {
                      final n = w * 7 + d - leading + 1;
                      if (n < 1 || n > daysInMonth) {
                        return const AspectRatio(aspectRatio: 1);
                      }
                      final date = DateTime(_month.year, _month.month, n);
                      return _DayCell(
                        date: date,
                        studied: studied.contains(date),
                        isToday: date == today,
                        isStart: date == start && data?.start != null,
                        beforeStart: date.isBefore(start),
                        future: date.isAfter(today),
                        planned: topics.containsKey(date),
                        topic: topics[date],
                        lit: lit,
                      );
                    },
                  ),
                ),
            ],
          ),
        const SizedBox(height: 14),
        Wrap(
          alignment: WrapAlignment.center,
          spacing: 16,
          runSpacing: 6,
          children: [
            _Legend(color: lit, label: 'Çalıştın'),
            _Legend(
              color: theme.colorScheme.surfaceContainerHighest,
              label: 'Çalışılmadı',
            ),
            _Legend(
              color: Colors.transparent,
              border: theme.colorScheme.outlineVariant,
              label: 'Programdan önce',
            ),
          ],
        ),
      ],
    );
  }
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.studied,
    required this.isToday,
    required this.isStart,
    required this.beforeStart,
    required this.future,
    required this.planned,
    required this.topic,
    required this.lit,
  });

  final DateTime date;
  final bool studied;
  final bool isToday;
  final bool isStart;
  final bool beforeStart;
  final bool future;
  final bool planned;
  final String? topic;
  final Color lit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quiet = beforeStart || future;

    final cell = AspectRatio(
      aspectRatio: 1,
      child: Container(
        margin: const EdgeInsets.all(3),
        decoration: BoxDecoration(
          color: studied
              ? lit
              : quiet
              ? Colors.transparent
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(10),
          border: isToday
              ? Border.all(color: theme.colorScheme.onSurface, width: 2)
              : null,
        ),
        child: Stack(
          alignment: Alignment.center,
          children: [
            Text(
              '${date.day}',
              style: theme.textTheme.labelMedium?.copyWith(
                fontWeight: studied ? FontWeight.w800 : FontWeight.w500,
                color: studied
                    ? (isDark ? AppColors.graphite900 : Colors.white)
                    : theme.colorScheme.onSurface.withValues(
                        alpha: beforeStart ? 0.25 : (future ? 0.45 : 0.75),
                      ),
              ),
            ),
            // Gelecekteki planlı günlerde küçük bir nokta.
            if (planned && future)
              Positioned(
                bottom: 5,
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: BoxDecoration(color: lit, shape: BoxShape.circle),
                ),
              ),
            if (isStart)
              Positioned(
                top: 2,
                right: 3,
                child: Icon(
                  Icons.flag_rounded,
                  size: 11,
                  color: studied
                      ? (isDark ? AppColors.graphite900 : Colors.white)
                      : lit,
                ),
              ),
          ],
        ),
      ),
    );

    final label = [
      '${date.day}',
      if (isStart) 'programın ilk günü',
      if (studied) 'çalışıldı',
      if (isToday) 'bugün',
      ?topic,
    ].join(', ');

    return Semantics(
      label: label,
      excludeSemantics: true,
      child: topic == null ? cell : Tooltip(message: topic!, child: cell),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label, this.border});

  final Color color;
  final Color? border;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(4),
            border: border == null ? null : Border.all(color: border!),
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
