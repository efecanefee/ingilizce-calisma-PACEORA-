import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/feature_colors.dart';
import '../../app/mascot.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/lesson_models.dart';
import '../../data/providers.dart';
import '../../data/writing.dart';

/// Yazma pratiği: kısa bir paragraf yaz, yapay zeka hataları işaretlesin.
class WritingScreen extends ConsumerStatefulWidget {
  const WritingScreen({super.key});

  @override
  ConsumerState<WritingScreen> createState() => _WritingScreenState();
}

class _WritingScreenState extends ConsumerState<WritingScreen> {
  final _controller = TextEditingController();
  late int _taskIndex = clock.now().difference(DateTime(2026)).inDays;
  bool _themeTask = false;
  bool _busy = false;
  String? _error;
  WritingFeedback? _feedback;
  String _submitted = '';
  int _xp = 0;

  @override
  void initState() {
    super.initState();
    _controller.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  String _task(String? theme) => _themeTask && theme != null
      ? '"$theme" temasıyla ilgili 4-6 cümle yaz.'
      : writingPrompts[_taskIndex % writingPrompts.length];

  void _shuffle(String? theme) {
    Haptics.tap();
    setState(() {
      if (theme != null && !_themeTask) {
        _themeTask = true;
      } else {
        _themeTask = false;
        _taskIndex++;
      }
    });
  }

  Future<void> _submit(String task) async {
    final text = _controller.text.trim();
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    final level = ref.read(profileProvider).value?.level ?? 'B1';
    final result = await ref
        .read(geminiServiceProvider)
        .correctWriting(text: text, level: level, task: task);
    if (!mounted) return;
    final feedback = result.feedback;
    if (feedback == null) {
      setState(() {
        _busy = false;
        _error = result.error ?? 'Değerlendirilemedi.';
      });
      return;
    }

    // Hatalar deftere işlenir; sonraki derslerde karşısına çıkar.
    await ref.read(repositoryProvider).recordOutcomes([
      for (final i in feedback.issues)
        AnswerOutcome(
          item: i.fix,
          context: '${i.original} → ${i.fix}',
          type: 'writing',
          correct: false,
        ),
    ]);
    final xp = await WritingRecords.save(
      ref.read(sharedPreferencesProvider),
      feedback.score,
    );
    ref.invalidate(gameProvider);
    if (!mounted) return;
    Haptics.success();
    setState(() {
      _busy = false;
      _feedback = feedback;
      _submitted = text;
      _xp = xp;
    });
  }

  void _reset() {
    setState(() {
      _feedback = null;
      _controller.clear();
      _taskIndex++;
      _themeTask = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(weekPlanProvider).value?.today?.vocabTheme;
    final task = _task(theme);
    final feedback = _feedback;
    return Scaffold(
      appBar: AppBar(title: const Text('Yazma pratiği')),
      body: feedback == null
          ? _Editor(
              controller: _controller,
              task: task,
              busy: _busy,
              error: _error,
              onShuffle: () => _shuffle(theme),
              onSubmit: () => _submit(task),
            )
          : _Result(
              text: _submitted,
              feedback: feedback,
              xp: _xp,
              onAgain: _reset,
            ),
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({
    required this.controller,
    required this.task,
    required this.busy,
    required this.error,
    required this.onShuffle,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final String task;
  final bool busy;
  final String? error;
  final VoidCallback onShuffle;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const feature = Feature.writing;
    final length = controller.text.trim().length;
    final ready = length >= writingMinChars && !busy;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Card(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
            side: BorderSide(color: feature.border(context)),
          ),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
            child: Row(
              children: [
                Icon(feature.icon, color: feature.color(context)),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('GÖREV', style: theme.textTheme.labelSmall),
                      const SizedBox(height: 2),
                      Text(
                        task,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Başka bir görev',
                  onPressed: busy ? null : onShuffle,
                  icon: const Icon(Icons.shuffle_rounded),
                ),
              ],
            ),
          ),
        ).entrance(0),
        const SizedBox(height: 16),
        TextField(
          controller: controller,
          enabled: !busy,
          minLines: 7,
          maxLines: 14,
          maxLength: writingMaxChars,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(
            hintText: 'İngilizce yaz…',
            border: OutlineInputBorder(),
            alignLabelWithHint: true,
          ),
        ).entrance(1),
        if (length > 0 && length < writingMinChars)
          Text(
            'Biraz daha yaz: en az $writingMinChars karakter '
            '(${writingMinChars - length} kaldı).',
            style: theme.textTheme.bodySmall,
          ),
        if (error != null) ...[
          const SizedBox(height: 8),
          Text(
            error!,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        ],
        const SizedBox(height: 16),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: ready ? onSubmit : null,
          icon: busy
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2.5),
                )
              : const Icon(Icons.spellcheck_rounded),
          label: Text(busy ? 'Pace okuyor…' : 'Düzelt'),
        ),
        const SizedBox(height: 12),
        Text(
          'Yazın yalnızca değerlendirme için yapay zekaya gönderilir; adın '
          'gönderilmez. Hataların hata defterine eklenir.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.text,
    required this.feedback,
    required this.xp,
    required this.onAgain,
  });

  final String text;
  final WritingFeedback feedback;
  final int xp;
  final VoidCallback onAgain;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final score = feedback.score;
    final color = score >= 85
        ? AppColors.success
        : score >= 60
        ? theme.colorScheme.primary
        : AppColors.warning;
    final spans = markIssues(text, feedback.issues);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            EquippedPace(
              mood: score >= 85 ? PaceMood.cheer : PaceMood.study,
              size: 88,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  CountUpText(
                    value: score,
                    prefix: '%',
                    style: theme.textTheme.displaySmall?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    feedback.issues.isEmpty
                        ? 'Hata bulunamadı'
                        : '${feedback.issues.length} düzeltme · +$xp XP',
                    style: theme.textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ).entrance(0),
        if (feedback.feedbackTr.isNotEmpty) ...[
          const SizedBox(height: 12),
          Text(feedback.feedbackTr, style: theme.textTheme.bodyLarge),
        ],
        const SizedBox(height: 20),
        Text(
          'Yazdığın',
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text.rich(
              TextSpan(
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
                children: [
                  for (final s in spans)
                    s.issue == null
                        ? TextSpan(text: s.text)
                        : TextSpan(
                            text: s.text,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              decoration: TextDecoration.underline,
                              decorationStyle: TextDecorationStyle.wavy,
                              decorationColor: theme.colorScheme.error,
                            ),
                          ),
                ],
              ),
            ),
          ),
        ),
        if (feedback.issues.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'Düzeltmeler',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          for (final (i, issue) in feedback.issues.indexed)
            Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(issue.typeLabel, style: theme.textTheme.labelSmall),
                    const SizedBox(height: 4),
                    Text.rich(
                      TextSpan(
                        style: theme.textTheme.bodyLarge,
                        children: [
                          TextSpan(
                            text: issue.original,
                            style: TextStyle(
                              color: theme.colorScheme.error,
                              decoration: TextDecoration.lineThrough,
                            ),
                          ),
                          const TextSpan(text: '  →  '),
                          TextSpan(
                            text: issue.fix,
                            style: TextStyle(
                              color: isDark
                                  ? AppColors.success
                                  : AppColors.successDark,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (issue.explanationTr.isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Text(
                        issue.explanationTr,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ).entrance(i + 1),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
              child: Text(
                'Düzeltilmiş hali',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            IconButton(
              tooltip: 'Kopyala',
              onPressed: () {
                Clipboard.setData(ClipboardData(text: feedback.corrected));
                ScaffoldMessenger.of(
                  context,
                ).showSnackBar(const SnackBar(content: Text('Kopyalandı.')));
              },
              icon: const Icon(Icons.copy_rounded),
            ),
          ],
        ),
        Card(
          margin: EdgeInsets.zero,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: SelectableText(
              feedback.corrected,
              style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: onAgain,
          icon: const Icon(Icons.edit_rounded),
          label: const Text('Yeni bir yazı'),
        ),
      ],
    );
  }
}
