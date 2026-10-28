import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../data/story_models.dart';
import '../lesson/lesson_steps.dart';

/// Günün hikayesi: okuma parçası, sözlükçe ve okuduğunu anlama testi.
class StoryScreen extends ConsumerWidget {
  const StoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final story = ref.watch(storyProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Günün hikayesi')),
      body: switch (story) {
        AsyncError(:final error) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Text('$error', textAlign: TextAlign.center),
          ),
        ),
        AsyncData(:final value) => _StoryBody(state: value),
        _ => const _LoadingView(),
      },
    );
  }
}

class _LoadingView extends StatelessWidget {
  const _LoadingView();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_stories, size: 48, color: theme.colorScheme.primary)
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(
                begin: -4,
                end: 4,
                duration: 700.ms,
                curve: Curves.easeInOut,
              ),
          const SizedBox(height: 20),
          Text(
            'Hikayen yazılıyor…',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _StoryBody extends ConsumerWidget {
  const _StoryBody({required this.state});

  final StoryState state;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final story = state.story;
    final notifier = ref.read(storyProvider.notifier);
    final minutes = (story.wordCount / 130).ceil();

    var index = 0;
    Widget item(Widget child) => child.entrance(index++);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        if (state.offline) item(_OfflineNote(onRetry: notifier.regenerate)),
        item(
          Text(
            story.title,
            style: theme.textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
        ),
        const SizedBox(height: 6),
        item(
          Text(
            '${story.wordCount} kelime · ~$minutes dk okuma',
            style: theme.textTheme.labelMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
            ),
          ),
        ),
        const SizedBox(height: 18),
        for (final paragraph in story.paragraphs)
          item(
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Text(
                paragraph,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
            ),
          ),
        if (story.glossary.isNotEmpty) ...[
          const SizedBox(height: 8),
          item(_Glossary(items: story.glossary)),
        ],
        const SizedBox(height: 28),
        item(
          Row(
            children: [
              Text(
                'OKUDUĞUNU ANLAMA',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.2,
                  color: theme.colorScheme.primary,
                ),
              ),
              const Spacer(),
              Text(
                '${state.answers.length}/${story.questions.length}',
                style: theme.textTheme.labelMedium,
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        for (var i = 0; i < story.questions.length; i++)
          item(
            ChoiceQuestionCard(
              number: i + 1,
              prompt: story.questions[i].question,
              options: story.questions[i].options,
              answer: story.questions[i].answer,
              given: state.answers[i],
              explanation: story.questions[i].explanationTr,
              onSelected: (option) => notifier.answer(i, option),
            ),
          ),
        AnimatedSwitcher(
          duration: Motion.medium,
          child: state.isFinished
              ? _ScoreCard(state: state)
              : const SizedBox.shrink(),
        ),
      ],
    );
  }
}

class _OfflineNote extends StatelessWidget {
  const _OfflineNote({required this.onRetry});

  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Gemini\'ye ulaşılamadı, hazır hikaye gösteriliyor.',
              style: theme.textTheme.bodySmall,
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Yeniden dene')),
        ],
      ),
    );
  }
}

class _Glossary extends StatelessWidget {
  const _Glossary({required this.items});

  final List<GlossaryItem> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.translate,
                  size: 18,
                  color: theme.colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Sözlükçe',
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final g in items)
                  Chip(
                    label: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: g.word,
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          TextSpan(text: '  ${g.meaning}'),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ScoreCard extends StatelessWidget {
  const _ScoreCard({required this.state});

  final StoryState state;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final score = state.scorePercent.round();
    final color = score >= 75
        ? AppColors.success
        : score >= 50
        ? theme.colorScheme.primary
        : AppColors.warning;

    return Card(
      key: const ValueKey('score'),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            CountUpText(
              value: score,
              prefix: '%',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w800,
                color: color,
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                '${state.correctCount}/${state.story.questions.length} soruyu '
                'doğru cevapladın. ${score >= 75 ? 'Metni çok iyi anladın!' : 'Yanlışların açıklamalarına göz at.'}',
                style: theme.textTheme.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    ).animate().scale(
      begin: const Offset(0.9, 0.9),
      curve: Curves.elasticOut,
      duration: Motion.slow,
    );
  }
}
