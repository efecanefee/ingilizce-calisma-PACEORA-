import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/srs.dart';

/// SM-2 aralıklı tekrar oturumu: kart çevrilir, kullanıcı ne kadar iyi
/// hatırladığını not eder, kart bir sonraki tekrarına planlanır.
class FlashcardsScreen extends ConsumerWidget {
  const FlashcardsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(flashcardSessionProvider);
    final summary = ref.watch(flashcardSummaryProvider).value;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Flash kartlar'),
        actions: [
          if (summary != null)
            Padding(
              padding: const EdgeInsets.only(right: 16),
              child: Center(
                child: Text(
                  '${summary.total} kart · ${summary.mature} öğrenildi',
                  style: Theme.of(context).textTheme.labelMedium,
                ),
              ),
            ),
        ],
      ),
      body: switch (session) {
        AsyncError(:final error) => Center(child: Text('$error')),
        AsyncData(:final value) when value.isDone => _DoneView(
          reviewed: value.reviewed,
          total: summary?.total ?? 0,
        ),
        AsyncData(:final value) => _SessionView(session: value),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _SessionView extends ConsumerStatefulWidget {
  const _SessionView({required this.session});

  final FlashcardSession session;

  @override
  ConsumerState<_SessionView> createState() => _SessionViewState();
}

class _SessionViewState extends ConsumerState<_SessionView> {
  bool _flipped = false;
  bool _busy = false;

  Future<void> _grade(ReviewGrade grade) async {
    if (_busy) return;
    setState(() => _busy = true);
    await ref.read(flashcardSessionProvider.notifier).grade(grade);
    if (mounted) {
      setState(() {
        _busy = false;
        _flipped = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final card = widget.session.current!;
    final remaining = widget.session.queue.length;
    final done = widget.session.reviewed;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text(
                  'KALAN $remaining',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text('$done tekrar', style: theme.textTheme.labelMedium),
              ],
            ),
            const SizedBox(height: 10),
            TweenAnimationBuilder<double>(
              tween: Tween(end: done / (done + remaining)),
              duration: Motion.medium,
              curve: Motion.curve,
              builder: (context, value, _) => LinearProgressIndicator(
                value: value,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 20),
            Expanded(
              child: AnimatedSwitcher(
                duration: Motion.medium,
                transitionBuilder: (child, animation) => FadeTransition(
                  opacity: animation,
                  child: ScaleTransition(
                    scale: Tween(begin: 0.92, end: 1.0).animate(animation),
                    child: child,
                  ),
                ),
                child: GestureDetector(
                  key: ValueKey('${card.id}-$done'),
                  onTap: () => setState(() => _flipped = !_flipped),
                  child: _FlipCard(card: card, flipped: _flipped),
                ),
              ),
            ),
            const SizedBox(height: 20),
            AnimatedSwitcher(
              duration: Motion.fast,
              child: _flipped
                  ? _GradeButtons(
                      key: const ValueKey('grades'),
                      card: card,
                      enabled: !_busy,
                      onGrade: _grade,
                    )
                  : FilledButton.icon(
                      key: const ValueKey('flip'),
                      onPressed: () => setState(() => _flipped = true),
                      icon: const Icon(Icons.flip),
                      label: const Text('Cevabı göster'),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Y ekseninde dönen iki yüzlü kart.
class _FlipCard extends StatelessWidget {
  const _FlipCard({required this.card, required this.flipped});

  final Flashcard card;
  final bool flipped;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(end: flipped ? pi : 0),
      duration: Motion.slow,
      curve: Curves.easeInOutBack,
      builder: (context, angle, _) {
        final showBack = angle > pi / 2;
        return Transform(
          alignment: Alignment.center,
          transform: Matrix4.identity()
            ..setEntry(3, 2, 0.0012)
            ..rotateY(angle),
          child: showBack
              // Arka yüz ters görünmesin diye kendi içinde yeniden çevrilir.
              ? Transform(
                  alignment: Alignment.center,
                  transform: Matrix4.identity()..rotateY(pi),
                  child: _CardFace(card: card, back: true),
                )
              : _CardFace(card: card, back: false),
        );
      },
    );
  }
}

class _CardFace extends StatelessWidget {
  const _CardFace({required this.card, required this.back});

  final Flashcard card;
  final bool back;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final fromMistake = card.source == 'mistake';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(28),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: back
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [AppColors.graphite700, AppColors.graphite600]
                    : [Colors.white, AppColors.graphite100],
              )
            : LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [AppColors.limeDark, AppColors.graphite800]
                    : [AppColors.limeSpark, AppColors.limeDim],
              ),
        border: Border.all(color: theme.colorScheme.outlineVariant),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.35 : 0.08),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Chip(
            avatar: Icon(
              fromMistake ? Icons.replay : Icons.auto_awesome,
              size: 16,
            ),
            label: Text(fromMistake ? 'Hata defterinden' : 'Yeni kelime'),
            visualDensity: VisualDensity.compact,
          ),
          const Spacer(),
          Text(
            back ? card.meaning : card.word,
            textAlign: TextAlign.center,
            style: theme.textTheme.headlineMedium?.copyWith(
              fontWeight: FontWeight.w800,
              color: !back && !isDark ? AppColors.graphite900 : null,
            ),
          ),
          if (back && card.exampleSentence.isNotEmpty) ...[
            const SizedBox(height: 18),
            Text(
              card.exampleSentence,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
          ],
          const Spacer(),
          Text(
            back ? 'Ne kadar iyi hatırladın?' : 'Çevirmek için dokun',
            style: theme.textTheme.labelMedium?.copyWith(
              color:
                  (!back && !isDark
                          ? AppColors.graphite900
                          : theme.colorScheme.onSurface)
                      .withValues(alpha: 0.6),
            ),
          ),
        ],
      ),
    );
  }
}

class _GradeButtons extends StatelessWidget {
  const _GradeButtons({
    super.key,
    required this.card,
    required this.enabled,
    required this.onGrade,
  });

  final Flashcard card;
  final bool enabled;
  final ValueChanged<ReviewGrade> onGrade;

  /// Butonun altında kartın ne zaman tekrar geleceği gösterilir.
  String _nextLabel(ReviewGrade grade) {
    final next = nextSchedule(
      ease: card.ease,
      intervalDays: card.intervalDays,
      reps: card.reps,
      grade: grade,
      today: DateTime.now(),
    );
    return switch (next.intervalDays) {
      1 => 'yarın',
      final d when d < 30 => '$d gün',
      final d => '${(d / 30).round()} ay',
    };
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = {
      ReviewGrade.again: AppColors.error,
      ReviewGrade.hard: AppColors.warning,
      ReviewGrade.good: theme.colorScheme.primary,
      ReviewGrade.easy: AppColors.success,
    };

    return Row(
      children: [
        for (final (i, grade) in ReviewGrade.values.indexed) ...[
          if (i > 0) const SizedBox(width: 8),
          Expanded(
            child: PressableScale(
              onTap: enabled ? () => onGrade(grade) : null,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 12),
                decoration: BoxDecoration(
                  color: colors[grade]!.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: colors[grade]!, width: 1.5),
                ),
                child: Column(
                  children: [
                    Text(
                      grade.label,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(_nextLabel(grade), style: theme.textTheme.labelSmall),
                  ],
                ),
              ),
            ).entrance(i),
          ),
        ],
      ],
    );
  }
}

class _DoneView extends StatelessWidget {
  const _DoneView({required this.reviewed, required this.total});

  final int reviewed;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final empty = total == 0;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
                  empty ? Icons.style_outlined : Icons.celebration,
                  size: 64,
                  color: theme.colorScheme.primary,
                )
                .animate()
                .scale(duration: Motion.slow, curve: Curves.elasticOut)
                .then()
                .shake(hz: 2, rotation: 0.05),
            const SizedBox(height: 20),
            Text(
              empty
                  ? 'Desten henüz boş'
                  : reviewed == 0
                  ? 'Bugün tekrar edilecek kart yok'
                  : 'Bugünlük bu kadar!',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
              textAlign: TextAlign.center,
            ).entrance(1),
            const SizedBox(height: 8),
            Text(
              empty
                  ? 'Ders bitirdikçe o günün kelimeleri ve yanlış yaptığın '
                        'ifadeler buraya kart olarak eklenir.'
                  : reviewed == 0
                  ? 'Kartlar SM-2 aralıklı tekrar ile planlanır; '
                        'zamanı gelince burada olacaklar.'
                  : '$reviewed kart tekrar ettin. Kartlar hatırlama '
                        'durumuna göre yeniden planlandı.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ).entrance(2),
          ],
        ),
      ),
    );
  }
}
