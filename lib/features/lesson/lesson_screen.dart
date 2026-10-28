import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/lesson_models.dart';
import '../../data/providers.dart';
import '../../data/rewards.dart';
import 'lesson_steps.dart';

/// Günün dersi: kelimeler → boşluk doldurma → çeviri → test → sonuç.
///
/// İlerleme her cevapta veritabanına yazıldığı için ders yarıda bırakılıp geri
/// dönüldüğünde kaldığı adımdan devam eder.
class LessonScreen extends ConsumerWidget {
  const LessonScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lesson = ref.watch(lessonProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Bugünün dersi'),
        leading: IconButton(
          tooltip: 'Kapat',
          icon: const Icon(Icons.close),
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
        ),
      ),
      body: switch (lesson) {
        AsyncError(:final error) => _UnavailableView(message: '$error'),
        AsyncData(:final value) => _LessonBody(state: value),
        _ => const _PreparingView(),
      },
    );
  }
}

class _PreparingView extends StatelessWidget {
  const _PreparingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const CircularProgressIndicator(),
            const SizedBox(height: 24),
            Text(
              'Bugünün dersi hazırlanıyor…',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Konuna ve seviyene özel sorular üretiliyor, birkaç saniye sürebilir.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ders üretilemediğinde çıkış yolu bırakan ekran.
///
/// Çevrimdışıyken haftalık plandaki gibi hazır bir yedek ders veremiyoruz;
/// bunun yerine kullanıcı yeniden deneyebilir ya da günü elle işaretleyerek
/// serisini koruyabilir.
class _UnavailableView extends ConsumerStatefulWidget {
  const _UnavailableView({required this.message});

  final String message;

  @override
  ConsumerState<_UnavailableView> createState() => _UnavailableViewState();
}

class _UnavailableViewState extends ConsumerState<_UnavailableView> {
  bool _busy = false;

  Future<void> _markDone() async {
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    try {
      final today = ref.read(weekPlanProvider).value?.today;
      if (today != null) {
        await ref.read(weekPlanProvider.notifier).completeDay(today);
      }
      router.go('/');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 40, color: theme.colorScheme.outline),
            const SizedBox(height: 16),
            Text(
              'Ders hazırlanamadı',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            Text(
              widget.message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () => ref.read(lessonProvider.notifier).retry(),
              child: const Text('Tekrar dene'),
            ),
            const SizedBox(height: 8),
            TextButton(
              onPressed: _busy ? null : _markDone,
              child: const Text('Günü elle tamamlandı işaretle'),
            ),
          ],
        ),
      ),
    );
  }
}

class _LessonBody extends ConsumerWidget {
  const _LessonBody({required this.state});

  final LessonState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final steps = state.lesson.steps;
    final index = state.progress.stepIndex;

    // Son adımdan sonra sonuç ekranı gelir.
    if (index >= steps.length) return _ResultView(state: state);

    final kind = steps[index];
    return Column(
      children: [
        _StepHeader(steps: steps, index: index, state: state),
        Expanded(
          // Adım değişince içerik yandan kayarak gelir.
          child: AnimatedSwitcher(
            duration: Motion.medium,
            switchInCurve: Motion.curve,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0.08, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            ),
            child: ListView(
              key: ValueKey(kind),
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
              children: [_stepContent(ref, kind)],
            ),
          ),
        ),
        _StepFooter(
          state: state,
          kind: kind,
          index: index,
          stepCount: steps.length,
        ),
      ],
    );
  }

  Widget _stepContent(WidgetRef ref, LessonStepKind kind) {
    final notifier = ref.read(lessonProvider.notifier);
    final lesson = state.lesson;
    final progress = state.progress;

    return switch (kind) {
      LessonStepKind.vocab => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in lesson.vocab) VocabCard(item: item),
          ],
        ),
      LessonStepKind.gapFill => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < lesson.gapFill.length; i++)
              ChoiceQuestionCard(
                number: i + 1,
                prompt: lesson.gapFill[i].sentence,
                hint: lesson.gapFill[i].hintTr,
                options: lesson.gapFill[i].options,
                answer: lesson.gapFill[i].answer,
                given: progress.given[gapFillKey(i)],
                onSelected: (option) => notifier.answer(
                  gapFillKey(i),
                  correct: lesson.gapFill[i].isCorrect(option),
                  input: option,
                ),
              ),
          ],
        ),
      LessonStepKind.translate => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < lesson.translate.length; i++)
              TranslateQuestionCard(
                // Cevap verildikten sonra kart yeniden kurulmasın diye anahtar
                // soruya sabitlendi.
                key: ValueKey(translateKey(i)),
                number: i + 1,
                item: lesson.translate[i],
                given: progress.given[translateKey(i)],
                correct: progress.answers[translateKey(i)] ?? false,
                onSubmit: (input) => notifier.answer(
                  translateKey(i),
                  correct: lesson.translate[i].isCorrect(input),
                  input: input,
                ),
              ),
          ],
        ),
      LessonStepKind.quiz => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < lesson.quiz.length; i++)
              ChoiceQuestionCard(
                number: i + 1,
                prompt: lesson.quiz[i].question,
                options: lesson.quiz[i].options,
                answer: lesson.quiz[i].answer,
                given: progress.given[quizKey(i)],
                explanation: lesson.quiz[i].explanationTr,
                onSelected: (option) => notifier.answer(
                  quizKey(i),
                  correct: lesson.quiz[i].isCorrect(option),
                  input: option,
                ),
              ),
          ],
        ),
    };
  }
}

class _StepHeader extends StatelessWidget {
  const _StepHeader({
    required this.steps,
    required this.index,
    required this.state,
  });

  final List<LessonStepKind> steps;
  final int index;
  final LessonState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = state.lesson.questionCount;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                steps[index].title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                'Adım ${index + 1}/${steps.length}'
                '${total == 0 ? '' : ' · ${state.answeredCount}/$total soru'}',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween(end: (index + 1) / (steps.length + 1)),
            duration: Motion.medium,
            curve: Motion.curve,
            builder: (context, value, _) => LinearProgressIndicator(
              value: value,
              minHeight: 6,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
        ],
      ),
    );
  }
}

class _StepFooter extends ConsumerWidget {
  const _StepFooter({
    required this.state,
    required this.kind,
    required this.index,
    required this.stepCount,
  });

  final LessonState state;
  final LessonStepKind kind;
  final int index;
  final int stepCount;

  /// Bu adımdaki tüm sorular cevaplandı mı? Kelime adımında soru yok.
  bool get _canContinue {
    final progress = state.progress;
    return switch (kind) {
      LessonStepKind.vocab => true,
      LessonStepKind.gapFill => List.generate(
          state.lesson.gapFill.length,
          gapFillKey,
        ).every(progress.answers.containsKey),
      LessonStepKind.translate => List.generate(
          state.lesson.translate.length,
          translateKey,
        ).every(progress.answers.containsKey),
      LessonStepKind.quiz => List.generate(
          state.lesson.quiz.length,
          quizKey,
        ).every(progress.answers.containsKey),
    };
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifier = ref.read(lessonProvider.notifier);
    final isLast = index == stepCount - 1;

    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        // Butonlar tema gereği tam genişlik ister (Size.fromHeight), bu yüzden
        // satırda esnek olmayan çocuk olarak bırakılamaz.
        child: Row(
          children: [
            if (index > 0) ...[
              Expanded(
                child: OutlinedButton(
                  onPressed: () => notifier.goToStep(index - 1),
                  child: const Text('Geri'),
                ),
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              flex: 2,
              child: FilledButton(
                onPressed:
                    _canContinue ? () => notifier.goToStep(index + 1) : null,
                child: Text(isLast ? 'Sonucu gör' : 'Devam'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Ders sonu: skor, yanlışların doğru karşılıkları ve günü kapatan buton.
class _ResultView extends ConsumerStatefulWidget {
  const _ResultView({required this.state});

  final LessonState state;

  @override
  ConsumerState<_ResultView> createState() => _ResultViewState();
}

class _ResultViewState extends ConsumerState<_ResultView> {
  bool _busy = false;

  Future<void> _finish() async {
    setState(() => _busy = true);
    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(lessonProvider.notifier).finish();
      router.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() => _busy = false);
      messenger.showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final state = widget.state;
    final score = state.scorePercent.round();
    final wrong = state.outcomes().where((o) => !o.correct).toList();
    // XP ders başına bir kez verilir; zaten bitmiş ders tekrar açıldıysa
    // "+XP" gösterilmez.
    final earnsXp = !(ref.watch(todayLessonProvider).value?.completed ?? false);

    final (color, message) = switch (score) {
      >= 85 => (AppColors.success, 'Harika gidiyorsun!'),
      >= 60 => (theme.colorScheme.primary, 'İyi iş — birkaç eksik kaldı.'),
      _ => (AppColors.warning, 'Bu konuyu tekrar etmekte fayda var.'),
    };

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
            children: [
              Center(
                child: Column(
                  children: [
                    Icon(
                      score >= 85 ? Icons.emoji_events : Icons.star_rounded,
                      size: 56,
                      color: color,
                    )
                        .animate()
                        .scale(duration: Motion.slow, curve: Curves.elasticOut)
                        .then()
                        .shake(hz: 3, rotation: 0.06),
                    const SizedBox(height: 8),
                    CountUpText(
                      value: score,
                      prefix: '%',
                      duration: const Duration(milliseconds: 900),
                      style: theme.textTheme.displaySmall?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${state.correctCount}/${state.lesson.questionCount} doğru',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color:
                            theme.colorScheme.onSurface.withValues(alpha: 0.7),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      message,
                      style: theme.textTheme.titleMedium
                          ?.copyWith(fontWeight: FontWeight.w600),
                    ),
                    if (earnsXp) ...[
                    const SizedBox(height: 14),
                    // Kazanılan XP: dersi bitirince ödül sistemine işlenir.
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.limeSpark.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: AppColors.limeDim),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.bolt_rounded,
                              size: 20, color: AppColors.limeDim),
                          const SizedBox(width: 6),
                          CountUpText(
                            value: lessonXp(state.scorePercent),
                            prefix: '+',
                            suffix: ' XP',
                            duration: const Duration(milliseconds: 1100),
                            style: theme.textTheme.titleSmall
                                ?.copyWith(fontWeight: FontWeight.w800),
                          ),
                        ],
                      ),
                    )
                        .animate(delay: 500.ms)
                        .fadeIn()
                        .scale(curve: Curves.elasticOut, duration: Motion.slow),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 28),
              if (wrong.isEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(20),
                    child: Row(
                      children: [
                        const Icon(Icons.emoji_events,
                            color: AppColors.success),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text('Tüm soruları doğru yaptın.'),
                        ),
                      ],
                    ),
                  ),
                )
              else ...[
                Text(
                  'Tekrar edilecekler',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 4),
                Text(
                  'Bunlar hata defterine eklendi; sonraki derslerde karşına çıkacak.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
                const SizedBox(height: 12),
                for (final (i, outcome) in wrong.indexed)
                  _WrongItemTile(item: outcome.item, context: outcome.context)
                      .entrance(i + 2),
              ],
            ],
          ),
        ),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
            child: SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _busy ? null : _finish,
                child: _busy
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : const Text('Dersi bitir'),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _WrongItemTile extends StatelessWidget {
  const _WrongItemTile({required this.item, required this.context});

  final String item;

  /// Hatanın geçtiği cümle/bağlam (widget ağacındaki BuildContext değil).
  final String context;

  @override
  Widget build(BuildContext buildContext) {
    final theme = Theme.of(buildContext);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item,
            style: theme.textTheme.bodyLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 4),
          Text(
            context,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}
