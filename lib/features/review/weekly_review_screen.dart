import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/constants.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../data/repository.dart';
import '../../data/review_models.dart';

/// Haftalık değerlendirme raporu ve adaptif seviye önerisi.
class WeeklyReviewScreen extends ConsumerStatefulWidget {
  const WeeklyReviewScreen({super.key});

  @override
  ConsumerState<WeeklyReviewScreen> createState() => _WeeklyReviewScreenState();
}

class _WeeklyReviewScreenState extends ConsumerState<WeeklyReviewScreen> {
  bool _generating = false;

  Future<void> _generate() async {
    setState(() => _generating = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final report = await ref.read(weeklyReportsProvider.notifier).generate();
      if (report.offline) {
        messenger.showSnackBar(const SnackBar(
          content: Text('Gemini\'ye ulaşılamadı; rapor verilerinden hazırlandı.'),
        ));
      }
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Rapor hazırlanamadı: $e')));
    } finally {
      if (mounted) setState(() => _generating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final reports = ref.watch(weeklyReportsProvider);
    final thisWeek = mondayOf(DateTime.now());

    return Scaffold(
      appBar: AppBar(title: const Text('Haftalık rapor')),
      body: switch (reports) {
        AsyncError(:final error) => Center(child: Text('$error')),
        AsyncData(:final value) => ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              _GenerateCard(
                busy: _generating,
                hasCurrent: value.any((r) => r.stats.weekStart == thisWeek),
                onGenerate: _generate,
              ).entrance(0),
              const SizedBox(height: 20),
              if (value.isEmpty)
                const _EmptyHint().entrance(1)
              else
                for (final (i, report) in value.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: _ReportCard(
                      report: report,
                      isCurrent: report.stats.weekStart == thisWeek,
                    ).entrance(i + 1),
                  ),
            ],
          ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _GenerateCard extends StatelessWidget {
  const _GenerateCard({
    required this.busy,
    required this.hasCurrent,
    required this.onGenerate,
  });

  final bool busy;
  final bool hasCurrent;
  final VoidCallback onGenerate;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.insights, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  'Bu haftanın değerlendirmesi',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              'Ders skorların, okuma testlerin, flash kart tekrarların ve hata '
              'defterin incelenir; sonuçlara göre seviye önerisi yapılır.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: busy ? null : onGenerate,
              icon: busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2.5),
                    )
                  : Icon(hasCurrent ? Icons.refresh : Icons.auto_awesome),
              label: Text(hasCurrent ? 'Raporu güncelle' : 'Raporu oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyHint extends StatelessWidget {
  const _EmptyHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 24),
      child: Column(
        children: [
          Icon(Icons.bar_chart, size: 48, color: theme.colorScheme.outline),
          const SizedBox(height: 12),
          Text(
            'Henüz rapor yok. Hafta boyunca çalıştıkça rapor daha anlamlı olur.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _ReportCard extends ConsumerWidget {
  const _ReportCard({required this.report, required this.isCurrent});

  final WeeklyReport report;
  final bool isCurrent;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final stats = report.stats;
    final start = stats.weekStart;
    final end = DateTime(start.year, start.month, start.day + 6);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  isCurrent ? 'BU HAFTA' : 'GEÇMİŞ HAFTA',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '${start.day}.${start.month} – ${end.day}.${end.month}',
                  style: theme.textTheme.labelMedium,
                ),
              ],
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                _Metric(label: 'Gün', value: stats.daysCompleted, suffix: '/7'),
                _Metric(label: 'Ders', value: stats.lessonsCompleted),
                _Metric(
                  label: 'Ort. skor',
                  value: stats.averageLessonScore?.round(),
                  prefix: '%',
                ),
                _Metric(label: 'Kart', value: stats.cardsReviewed),
              ],
            ),
            const SizedBox(height: 18),
            Text(report.summary, style: theme.textTheme.bodyMedium?.copyWith(height: 1.5)),
            if (report.strengths.isNotEmpty) ...[
              const SizedBox(height: 16),
              _Bullets(
                title: 'Güçlü yönlerin',
                icon: Icons.thumb_up_alt_outlined,
                color: AppColors.success,
                items: report.strengths,
              ),
            ],
            if (report.focus.isNotEmpty) ...[
              const SizedBox(height: 14),
              _Bullets(
                title: 'Gelecek hafta odak',
                icon: Icons.track_changes,
                color: AppColors.warning,
                items: report.focus,
              ),
            ],
            if (report.tip.isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: theme.colorScheme.primary.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.lightbulb_outline,
                        size: 20, color: theme.colorScheme.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(report.tip)),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            _LevelSuggestion(report: report),
          ],
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({
    required this.label,
    required this.value,
    this.prefix = '',
    this.suffix = '',
  });

  final String label;
  final int? value;
  final String prefix;
  final String suffix;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final style =
        theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800);
    return Expanded(
      child: Column(
        children: [
          value == null
              ? Text('–', style: style)
              : CountUpText(
                  value: value!,
                  prefix: prefix,
                  suffix: suffix,
                  style: style,
                ),
          const SizedBox(height: 2),
          Text(label, style: theme.textTheme.labelSmall),
        ],
      ),
    );
  }
}

class _Bullets extends StatelessWidget {
  const _Bullets({
    required this.title,
    required this.icon,
    required this.color,
    required this.items,
  });

  final String title;
  final IconData icon;
  final Color color;
  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, size: 18, color: color),
            const SizedBox(width: 8),
            Text(
              title,
              style: theme.textTheme.titleSmall
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
          ],
        ),
        const SizedBox(height: 6),
        for (final item in items)
          Padding(
            padding: const EdgeInsets.only(left: 26, bottom: 4),
            child: Text('• $item', style: theme.textTheme.bodyMedium),
          ),
      ],
    );
  }
}

/// Adaptif seviye: öneri varsa kademe değişimi animasyonlu gösterilir.
class _LevelSuggestion extends ConsumerWidget {
  const _LevelSuggestion({required this.report});

  final WeeklyReport report;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final from = DifficultyLevel.fromCode(report.fromLevel);
    final to = DifficultyLevel.fromCode(report.suggestedLevel);

    if (!report.suggestsChange) {
      return Row(
        children: [
          Icon(Icons.check_circle_outline, color: theme.colorScheme.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Seviyen (${from.code}) sana uygun görünüyor.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      );
    }

    final up = to.index > from.index;
    final color = up ? AppColors.success : AppColors.warning;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color, width: 1.5),
        color: color.withValues(alpha: 0.08),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LevelChip(code: from.code, muted: true),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: Icon(
                  up ? Icons.trending_up : Icons.trending_down,
                  color: color,
                  size: 28,
                )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .moveX(begin: -3, end: 3, duration: 700.ms),
              ),
              _LevelChip(code: to.code, muted: false),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            up
                ? 'Bu hafta seviyenin üstünde performans gösterdin.'
                : 'Bu hafta zorlandın; bir kademe kolaylaştırmak öğrenmeyi hızlandırır.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          if (report.applied)
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.check, color: AppColors.success, size: 18),
                const SizedBox(width: 6),
                Text('Seviyen ${to.code} olarak güncellendi',
                    style: theme.textTheme.labelLarge),
              ],
            )
          else
            FilledButton(
              onPressed: () async {
                await ref.read(weeklyReportsProvider.notifier).applyLevel(report);
                // Yeni seviye sonraki derslerde ve programda kullanılır.
                ref.invalidate(weekPlanProvider);
              },
              child: Text('Seviyemi ${to.code} yap'),
            ),
        ],
      ),
    );
  }
}

class _LevelChip extends StatelessWidget {
  const _LevelChip({required this.code, required this.muted});

  final String code;
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: muted
            ? theme.colorScheme.surfaceContainerHighest
            : theme.colorScheme.primary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        code,
        style: theme.textTheme.titleMedium?.copyWith(
          fontWeight: FontWeight.w800,
          color: muted ? null : theme.colorScheme.onPrimary,
        ),
      ),
    );
  }
}
