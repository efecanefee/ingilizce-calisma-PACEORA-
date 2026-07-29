import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants.dart';
import '../../app/logo.dart';
import '../../data/database.dart';
import '../../data/providers.dart';

/// Ana ekran: selamlama + streak, bugünün planı ve haftanın tamamı.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final result = await ref.read(weekPlanProvider.notifier).regenerate();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            result.offline
                ? 'Gemini\'ye ulaşılamadı (${result.error}). Hazır program yüklendi.'
                : 'Haftalık programın Gemini ile yenilendi.',
          ),
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Plan yenilenemedi: $e')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final plan = ref.watch(weekPlanProvider);

    return Scaffold(
      appBar: AppBar(
        title: const PaceoraWordmark(markSize: 28),
        actions: [
          IconButton(
            tooltip: 'Planı yenile',
            onPressed: plan.isLoading ? null : () => _regenerate(context, ref),
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'Ayarlar',
            onPressed: () => context.push('/settings'),
            icon: const Icon(Icons.settings_outlined),
          ),
        ],
      ),
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

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        _Greeting(user: user),
        const SizedBox(height: 20),
        if (week.offline) ...[
          const _OfflineBadge(),
          const SizedBox(height: 12),
        ],
        if (today == null)
          const _EmptyPlanCard()
        else
          _TodayCard(
            day: today,
            dailyMinutes: user.dailyMinutes,
            lesson: lesson,
            onStudy: () => context.push('/lesson'),
            onComplete: () =>
                ref.read(weekPlanProvider.notifier).completeDay(today),
          ),
        const SizedBox(height: 28),
        Text(
          'Bu hafta',
          style: Theme.of(context)
              .textTheme
              .titleMedium
              ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 12),
        for (final day in week.days)
          _WeekDayTile(day: day, isToday: day.dayIndex == today?.dayIndex),
      ],
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Merhaba, ${user.name}',
                style: theme.textTheme.headlineSmall
                    ?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 6),
              Text(
                'Seviye ${DifficultyLevel.fromCode(user.level).label} · '
                'günde ${user.dailyMinutes} dk',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text('🔥', style: TextStyle(fontSize: 18)),
              const SizedBox(width: 6),
              Text(
                '${user.streak} gün',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
            ],
          ),
        ),
      ],
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
                  const Icon(Icons.check_circle, color: Color(0xFF4ADE80)),
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

class _WeekDayTile extends StatelessWidget {
  const _WeekDayTile({required this.day, required this.isToday});

  final WeeklyPlanDay day;
  final bool isToday;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (icon, color) = switch (day.status) {
      'completed' => (Icons.check_circle, const Color(0xFF4ADE80)),
      'skipped' => (Icons.cancel_outlined, theme.colorScheme.error),
      _ => (Icons.circle_outlined, theme.colorScheme.outline),
    };

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isToday
              ? theme.colorScheme.primary
              : theme.colorScheme.outlineVariant,
          width: isToday ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppConstants.weekdayNames[day.dayIndex],
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  day.grammarTopic,
                  style: theme.textTheme.bodyLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 2),
                Text(
                  day.vocabTheme,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
