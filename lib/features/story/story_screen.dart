import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/error_view.dart';
import '../../app/mascot.dart';
import '../../app/motion.dart';
import '../../app/sounds.dart';
import '../../app/speak_button.dart';
import '../../app/theme.dart';
import '../../app/translate_help.dart';
import '../../data/providers.dart';
import '../../data/speech_service.dart';
import '../../data/story_models.dart';
import '../../data/word_lookup.dart';
import '../lesson/lesson_steps.dart';

/// Günün hikayesi: okuma parçası, sözlükçe ve okuduğunu anlama testi.
class StoryScreen extends ConsumerWidget {
  const StoryScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final story = ref.watch(storyProvider);
    // Son soru cevaplanınca bitiş sesi (önceden bitmiş hikaye açılınca değil).
    ref.listen(storyProvider, (previous, next) {
      final before = previous?.value;
      if (before == null || before.isFinished) return;
      if (next.value?.isFinished ?? false) Sounds.finished();
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Günün hikayesi')),
      body: switch (story) {
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(storyProvider),
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
          const PaceSticker(PacePose.peek, size: 150),
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
          Row(
            children: [
              Expanded(
                child: Text(
                  '${story.wordCount} kelime · ~$minutes dk okuma',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              _ListenStoryButton(
                text: [story.title, ...story.paragraphs].join('\n'),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        item(const _TapHint()),
        const SizedBox(height: 14),
        for (final paragraph in story.paragraphs)
          item(
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: TappableParagraph(
                text: paragraph,
                glossary: story.glossary,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.6),
              ),
            ),
          ),
        // Hikayenin tamamının Türkçesi: zorlanan okur için alt kısımda.
        item(
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
              child: TranslateHelp(
                english: [story.title, ...story.paragraphs].join('\n\n'),
                label: 'Hikayenin Türkçesini göster',
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
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
              hint: story.questions[i].questionTr,
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

/// Hikayenin tamamını sesli okur; okurken durdurma düğmesine döner.
class _ListenStoryButton extends ConsumerStatefulWidget {
  const _ListenStoryButton({required this.text});

  final String text;

  @override
  ConsumerState<_ListenStoryButton> createState() => _ListenStoryButtonState();
}

class _ListenStoryButtonState extends ConsumerState<_ListenStoryButton> {
  late final SpeechService _speech = ref.read(speechServiceProvider);
  var _playing = false;

  @override
  void dispose() {
    if (_playing) _speech.stopSpeaking();
    super.dispose();
  }

  Future<void> _toggle() async {
    Haptics.tap();
    if (_playing) {
      setState(() => _playing = false);
      await _speech.stopSpeaking();
      return;
    }
    setState(() => _playing = true);
    await speakWithNotice(context, _speech, widget.text);
    if (mounted) setState(() => _playing = false);
  }

  @override
  Widget build(BuildContext context) {
    return TextButton.icon(
      onPressed: _toggle,
      icon: Icon(
        _playing ? Icons.stop_circle_outlined : Icons.headphones_rounded,
      ),
      label: Text(_playing ? 'Durdur' : 'Dinle'),
    );
  }
}

class _TapHint extends StatelessWidget {
  const _TapHint();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    return Row(
      children: [
        Icon(Icons.touch_app_outlined, size: 16, color: muted),
        const SizedBox(width: 6),
        Expanded(
          child: Text(
            'Bilmediğin kelimeye dokun; anlamını gör, havuzuna ekle.',
            style: theme.textTheme.bodySmall?.copyWith(color: muted),
          ),
        ),
      ],
    );
  }
}

/// Kelimeleri dokunulabilir paragraf.
///
/// Sözlükçedeki kelimelerin altı noktalıdır; dokunulan kelime vurgulanır ve
/// alttan anlam kartı açılır.
class TappableParagraph extends StatefulWidget {
  const TappableParagraph({
    super.key,
    required this.text,
    required this.glossary,
    this.style,
  });

  final String text;
  final List<GlossaryItem> glossary;
  final TextStyle? style;

  @override
  State<TappableParagraph> createState() => _TappableParagraphState();
}

class _TappableParagraphState extends State<TappableParagraph> {
  final _recognizers = <TapGestureRecognizer>[];

  /// Vurgulanan kelimenin paragraftaki konumu.
  int? _selected;

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  /// Her derlemede yeniden kurulur; eskileri [_disposeRecognizers] atar.
  TapGestureRecognizer _recognizer(VoidCallback onTap) {
    final recognizer = TapGestureRecognizer()..onTap = onTap;
    _recognizers.add(recognizer);
    return recognizer;
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  Future<void> _open(StoryToken token) async {
    setState(() => _selected = token.start);
    await showWordSheet(
      context,
      word: token.text,
      sentence: sentenceAt(widget.text, token.start),
    );
    if (mounted) setState(() => _selected = null);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primary = theme.colorScheme.primary;
    _disposeRecognizers();

    return Text.rich(
      TextSpan(
        style: widget.style,
        children: [
          for (final token in tokenizeParagraph(widget.text))
            if (!token.isWord)
              TextSpan(text: token.text)
            else
              TextSpan(
                text: token.text,
                recognizer: _recognizer(() => _open(token)),
                style: TextStyle(
                  backgroundColor: token.start == _selected
                      ? primary.withValues(alpha: 0.2)
                      : null,
                  decoration: glossaryMatch(widget.glossary, token.text) != null
                      ? TextDecoration.underline
                      : null,
                  decorationStyle: TextDecorationStyle.dotted,
                  decorationColor: primary,
                  decorationThickness: 2,
                ),
              ),
        ],
      ),
    );
  }
}

/// Kelimenin anlam kartını alttan açar.
Future<void> showWordSheet(
  BuildContext context, {
  required String word,
  required String sentence,
}) => showModalBottomSheet<void>(
  context: context,
  showDragHandle: true,
  isScrollControlled: true,
  builder: (_) => WordSheet(word: word, sentence: sentence),
);

/// Dokunulan kelimenin anlamı ve "havuza ekle" düğmesi.
class WordSheet extends ConsumerStatefulWidget {
  const WordSheet({super.key, required this.word, required this.sentence});

  final String word;
  final String sentence;

  @override
  ConsumerState<WordSheet> createState() => _WordSheetState();
}

class _WordSheetState extends ConsumerState<WordSheet> {
  WordMeaning? _meaning;
  String? _error;
  bool _loading = true;

  /// null: bilinmiyor, true: destede var.
  bool? _inPool;
  bool _adding = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final result = await ref
        .read(storyProvider.notifier)
        .lookup(widget.word, widget.sentence);
    final meaning = result.meaning;
    final inPool = meaning == null
        ? null
        : await ref.read(repositoryProvider).hasFlashcard(meaning.word);
    if (!mounted) return;
    setState(() {
      _loading = false;
      _meaning = meaning;
      _error = meaning == null ? (result.error ?? 'Çeviri bulunamadı') : null;
      _inPool = inPool;
    });
  }

  Future<void> _add() async {
    final meaning = _meaning;
    if (meaning == null || _adding) return;
    setState(() => _adding = true);
    await ref.read(storyProvider.notifier).addToPool(meaning, widget.sentence);
    if (!mounted) return;
    setState(() {
      _adding = false;
      _inPool = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.6);
    final meaning = _meaning;
    final showBase =
        meaning != null &&
        normalizeWord(meaning.word) != normalizeWord(widget.word);

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              crossAxisAlignment: WrapCrossAlignment.center,
              spacing: 10,
              runSpacing: 6,
              children: [
                Text(
                  widget.word,
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                SpeakButton(text: widget.word),
                if (meaning != null && meaning.partOfSpeech.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      meaning.partOfSpeech,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.primary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
            if (showBase) ...[
              const SizedBox(height: 2),
              Text(
                'Sözlük biçimi: ${meaning.word}',
                style: theme.textTheme.bodySmall?.copyWith(color: muted),
              ),
            ],
            const SizedBox(height: 14),
            AnimatedSwitcher(
              duration: Motion.medium,
              child: _loading
                  ? Row(
                      key: const ValueKey('loading'),
                      children: [
                        const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                        const SizedBox(width: 12),
                        Text('Çevriliyor…', style: theme.textTheme.bodyMedium),
                      ],
                    )
                  : meaning == null
                  ? Row(
                      key: const ValueKey('error'),
                      children: [
                        Icon(Icons.cloud_off, size: 18, color: muted),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            _error ?? '',
                            style: theme.textTheme.bodyMedium,
                          ),
                        ),
                        TextButton(
                          onPressed: _load,
                          child: const Text('Tekrar dene'),
                        ),
                      ],
                    )
                  : Text(
                      meaning.meaning,
                      key: const ValueKey('meaning'),
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: theme.colorScheme.primary,
                      ),
                    ),
            ),
            const SizedBox(height: 14),
            Text(
              '“${widget.sentence}”',
              style: theme.textTheme.bodyMedium?.copyWith(
                fontStyle: FontStyle.italic,
                color: muted,
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: _inPool == true
                  ? FilledButton.tonalIcon(
                      onPressed: null,
                      icon: const Icon(Icons.check_circle),
                      label: const Text('Kelime havuzunda'),
                    )
                  : FilledButton.icon(
                      onPressed: meaning == null || _adding ? null : _add,
                      icon: const Icon(Icons.add),
                      label: const Text('Kelime havuzuna ekle'),
                    ),
            ),
            if (_inPool == true) ...[
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Flash kartlarda tekrar karşına çıkacak.',
                  style: theme.textTheme.bodySmall?.copyWith(color: muted),
                ),
              ),
            ],
          ],
        ),
      ),
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
