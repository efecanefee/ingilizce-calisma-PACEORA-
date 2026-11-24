import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/mascot.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';
import '../program/calendar_day_sheet.dart';

/// Biten dersler ve konuları, yeniden eskiye.
final lessonHistoryProvider =
    FutureProvider.autoDispose<List<({Lesson lesson, String? topic})>>((
      ref,
    ) async {
      ref.watch(weekPlanProvider);
      final repository = ref.read(repositoryProvider);
      final topics = {
        for (final d in await repository.allPlanDays())
          planDateOf(d): d.grammarTopic,
      };
      return [
        for (final l in (await repository.completedLessons()).reversed)
          (lesson: l, topic: topics[dayOf(l.lessonDate)]),
      ];
    });

/// "16 – 22 Kasım haftası" yerine kısa: "16.11 – 22.11 haftası".
String weekTitle(DateTime start) {
  final end = DateTime(start.year, start.month, start.day + 6);
  return '${start.day}.${start.month} – ${end.day}.${end.month} haftası';
}

/// İlerleme kutularının ayrıntı sayfası.
void showProgressSheet(
  BuildContext context, {
  required String title,
  required Widget child,
}) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => ConstrainedBox(
      constraints: BoxConstraints(
        maxHeight: MediaQuery.sizeOf(context).height * 0.85,
      ),
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 32),
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    ),
  );
}

/// Biten derslerin listesi; [weekStart] verilirse yalnızca o hafta. Derse
/// dokununca günün sayfası açılır (kelimeler, tekrar çözme).
class LessonHistory extends ConsumerWidget {
  const LessonHistory({super.key, this.weekStart});

  final DateTime? weekStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final all = ref.watch(lessonHistoryProvider).value;
    if (all == null) return const Center(child: CircularProgressIndicator());
    final start = weekStart;
    final items = start == null
        ? all
        : [
            for (final e in all)
              if (!e.lesson.lessonDate.isBefore(start) &&
                  e.lesson.lessonDate.isBefore(
                    DateTime(start.year, start.month, start.day + 7),
                  ))
                e,
          ];
    if (items.isEmpty) {
      return Column(
        children: [
          const PaceSticker(PacePose.sleep, size: 110),
          const SizedBox(height: 12),
          Text(
            start == null ? 'Henüz biten ders yok.' : 'Bu hafta ders yok.',
            style: theme.textTheme.bodyLarge,
          ),
        ],
      );
    }
    return Column(
      children: [
        for (final e in items)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: CircleAvatar(
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
              child: Text(
                e.lesson.score == null ? '–' : '${e.lesson.score!.round()}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: (e.lesson.score ?? 0) >= 60
                      ? theme.colorScheme.primary
                      : theme.colorScheme.onSurface,
                ),
              ),
            ),
            title: Text(e.topic ?? 'Ders'),
            subtitle: Text(
              '${longDate(e.lesson.lessonDate)} · '
              '${(e.lesson.durationSeconds / 60).ceil()} dk',
            ),
            trailing: Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.outline,
            ),
            onTap: () => showCalendarDaySheet(context, e.lesson.lessonDate),
          ),
      ],
    );
  }
}
