import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';
import 'calendar_day_sheet.dart';

/// Aylık takvimin verisi: çalışılan günler, programın başladığı gün, plan
/// konuları ve ders kayıtları.
class ProgramCalendar {
  const ProgramCalendar({
    required this.studied,
    required this.start,
    required this.topics,
    this.lessons = const {},
  });

  final Set<DateTime> studied;

  /// Programın başladığı gün; henüz plan yoksa null.
  final DateTime? start;

  /// Plandaki her günün dilbilgisi konusu, tarihe göre.
  final Map<DateTime, String> topics;

  /// Tamamlanmış dersler, tarihe göre (puan ve süre için).
  final Map<DateTime, Lesson> lessons;
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
    lessons: {
      for (final l in await repository.completedLessons())
        dayOf(l.lessonDate): l,
    },
  );
});

/// Bir ayın özeti: takvimin altında gösterilir.
class MonthSummary {
  const MonthSummary({
    required this.days,
    required this.lessons,
    required this.minutes,
    required this.averageScore,
    required this.bestStreak,
  });

  final int days;
  final int lessons;
  final int minutes;
  final double? averageScore;
  final int bestStreak;

  factory MonthSummary.of(ProgramCalendar data, DateTime month) {
    bool inMonth(DateTime d) => d.year == month.year && d.month == month.month;
    final studied = data.studied.where(inMonth).toSet();
    final lessons = data.lessons.entries
        .where((e) => inMonth(e.key))
        .map((e) => e.value)
        .toList();
    final scores = [
      for (final l in lessons)
        if (l.score != null) l.score!,
    ];
    final seconds = lessons.fold<int>(0, (s, l) => s + l.durationSeconds);
    return MonthSummary(
      days: studied.length,
      lessons: lessons.length,
      minutes: (seconds / 60).round(),
      averageScore: scores.isEmpty
          ? null
          : scores.reduce((a, b) => a + b) / scores.length,
      bestStreak: bestStreakOf(studied),
    );
  }
}

/// Ay takvimi: hangi gün çalışıldığı, bugün ve programdan önceki günler.
///
/// Program başlamadan önceki günler soluk durur; "kaçırıldı" sayılmaz.
/// Art arda çalışılan günler tek şerit gibi birleşir; renk tonu o günün
/// puanını gösterir. Güne dokununca ayrıntı sayfası açılır.
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
    final lessons = data?.lessons ?? const <DateTime, Lesson>{};

    final firstDay = DateTime(_month.year, _month.month);
    final leading = firstDay.weekday - DateTime.monday;
    final daysInMonth = DateTime(_month.year, _month.month + 1, 0).day;
    final rows = ((leading + daysInMonth) / 7).ceil();
    final thisMonth = DateTime(today.year, today.month);
    final canGoBack = DateTime(start.year, start.month).isBefore(_month);
    final canGoForward = _month.isBefore(thisMonth);
    final summary = data == null ? null : MonthSummary.of(data, _month);

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
                    '${summary?.days ?? 0} gün çalıştın',
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
                      final prev = DateTime(date.year, date.month, n - 1);
                      final next = DateTime(date.year, date.month, n + 1);
                      final isStudied = studied.contains(date);
                      return _DayCell(
                        date: date,
                        studied: isStudied,
                        // Şerit yalnızca aynı satırdaki komşuyla birleşir.
                        joinLeft: isStudied && d > 0 && studied.contains(prev),
                        joinRight: isStudied && d < 6 && studied.contains(next),
                        score: lessons[date]?.score,
                        isToday: date == today,
                        isStart: date == start && data?.start != null,
                        beforeStart: date.isBefore(start),
                        future: date.isAfter(today),
                        planned: topics.containsKey(date),
                        topic: topics[date],
                        lit: lit,
                        onTap: () => showCalendarDaySheet(context, date),
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
            _Legend(color: lit.withValues(alpha: 0.5), label: 'Düşük puan'),
            _Legend(
              color: theme.colorScheme.surfaceContainerHighest,
              label: 'Çalışılmadı',
            ),
          ],
        ),
        if (summary != null) ...[
          const SizedBox(height: 18),
          _SummaryCard(summary: summary),
        ],
        const SizedBox(height: 10),
        Text(
          'Bir güne dokun: dersi tekrar çöz, kaçırdığını telafi et ya da '
          'gelecek konuyu değiştir.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// Puana göre ton: düşük puanlı günler daha açık görünür.
double scoreAlpha(double? score) {
  if (score == null) return 1;
  if (score < 60) return 0.5;
  if (score < 85) return 0.75;
  return 1;
}

class _DayCell extends StatelessWidget {
  const _DayCell({
    required this.date,
    required this.studied,
    required this.joinLeft,
    required this.joinRight,
    required this.score,
    required this.isToday,
    required this.isStart,
    required this.beforeStart,
    required this.future,
    required this.planned,
    required this.topic,
    required this.lit,
    required this.onTap,
  });

  final DateTime date;
  final bool studied;
  final bool joinLeft;
  final bool joinRight;
  final double? score;
  final bool isToday;
  final bool isStart;
  final bool beforeStart;
  final bool future;
  final bool planned;
  final String? topic;
  final Color lit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final quiet = beforeStart || future;
    const r = Radius.circular(10);
    final radius = BorderRadius.horizontal(
      left: joinLeft ? Radius.zero : r,
      right: joinRight ? Radius.zero : r,
    );
    final onFill = isDark ? AppColors.graphite900 : Colors.white;

    final cell = AspectRatio(
      aspectRatio: 1,
      child: Container(
        margin: EdgeInsets.fromLTRB(joinLeft ? 0 : 3, 3, joinRight ? 0 : 3, 3),
        decoration: BoxDecoration(
          color: studied
              ? lit.withValues(alpha: scoreAlpha(score))
              : quiet
              ? Colors.transparent
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: radius,
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
                    ? onFill
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
                  color: studied ? onFill : lit,
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
      if (score != null) 'puan ${score!.round()}',
      if (isToday) 'bugün',
      ?topic,
    ].join(', ');

    return Semantics(
      label: label,
      button: true,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: cell,
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({required this.summary});

  final MonthSummary summary;

  @override
  Widget build(BuildContext context) {
    final avg = summary.averageScore;
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
        child: Row(
          children: [
            _SummaryStat(value: '${summary.lessons}', label: 'ders'),
            _SummaryStat(value: '${summary.minutes} dk', label: 'süre'),
            _SummaryStat(
              value: avg == null ? '–' : '%${avg.round()}',
              label: 'ort. puan',
            ),
            _SummaryStat(
              value: '${summary.bestStreak} gün',
              label: 'en uzun seri',
            ),
          ],
        ),
      ),
    );
  }
}

class _SummaryStat extends StatelessWidget {
  const _SummaryStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              maxLines: 1,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall,
          ),
        ],
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
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
          ),
        ),
        const SizedBox(width: 6),
        Text(label, style: theme.textTheme.labelSmall),
      ],
    );
  }
}
