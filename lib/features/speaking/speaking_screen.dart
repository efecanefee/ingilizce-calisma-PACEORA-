import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/error_view.dart';
import '../../app/motion.dart';
import '../../app/speak_button.dart';
import '../../app/theme.dart';
import '../../data/pronunciation.dart';
import '../../data/providers.dart';
import '../../data/speech_service.dart';

/// Pratik türü.
enum PracticeMode {
  /// Cümleyi gör, sesli söyle; konuşma tanıma puanlar.
  speak('Konuşma pratiği', 'Cümleyi sesli söyle'),

  /// Cümleyi dinle, yaz.
  dictation('Dinle ve yaz', 'Duyduğun cümleyi yaz');

  const PracticeMode(this.title, this.instruction);

  final String title;
  final String instruction;
}

class SpeakingScreen extends ConsumerWidget {
  const SpeakingScreen({super.key, required this.mode});

  final PracticeMode mode;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sentences = ref.watch(practiceSentencesProvider);
    return Scaffold(
      appBar: AppBar(title: Text(mode.title)),
      body: switch (sentences) {
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(practiceSentencesProvider),
        ),
        AsyncData(:final value) => _Session(mode: mode, sentences: value),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

/// Bir cümle için durum.
enum _Stage { ready, listening, scored }

class _Session extends ConsumerStatefulWidget {
  const _Session({required this.mode, required this.sentences});

  final PracticeMode mode;
  final List<String> sentences;

  @override
  ConsumerState<_Session> createState() => _SessionState();
}

class _SessionState extends ConsumerState<_Session> {
  var _index = 0;
  var _stage = _Stage.ready;
  var _heard = '';
  SentenceScore? _score;
  String? _error;

  /// XP verilmiş cümleler: aynı cümle tekrar denenince ikinci kez verilmez.
  final _passed = <int>{};
  final _input = TextEditingController();

  /// initState'te alınır: dispose sırasında ref kullanılamaz.
  late final SpeechService _speech;
  String get _sentence => widget.sentences[_index];
  bool get _done => _index >= widget.sentences.length;

  @override
  void initState() {
    super.initState();
    _speech = ref.read(speechServiceProvider);
    // Dinle-yaz cümleyi baştan okur.
    if (widget.mode == PracticeMode.dictation) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _play());
    }
  }

  @override
  void dispose() {
    _input.dispose();
    // Ekrandan çıkınca okuma ve dinleme dursun.
    _speech.stopSpeaking();
    _speech.stopListening();
    super.dispose();
  }

  Future<void> _play({bool slow = false}) =>
      speakWithNotice(context, _speech, _sentence, slow: slow);

  /// Tek bir kelimeyi yavaşça okur (kırmızı kelimeye dokununca).
  Future<void> _sayWord(String word) {
    Haptics.tap();
    return speakWithNotice(context, _speech, word, slow: true);
  }

  Future<void> _listen() async {
    if (_stage == _Stage.listening) {
      await _speech.stopListening();
      // Tanıma durunca genelde son sonucu gönderir; göndermezse o ana kadar
      // duyulanla puanlanır, ekran "dinliyor"da takılı kalmaz.
      await Future<void>.delayed(const Duration(milliseconds: 1200));
      if (mounted && _stage == _Stage.listening) await _check(_heard);
      return;
    }
    setState(() {
      _error = null;
      _heard = '';
    });
    final ok = await _speech.initRecognition();
    if (!mounted) return;
    if (!ok) {
      setState(
        () => _error =
            'Konuşma tanıma kullanılamıyor. Mikrofon iznini ve cihazın '
            'konuşma tanıma servisini kontrol et.',
      );
      return;
    }
    Haptics.tap();
    setState(() => _stage = _Stage.listening);
    await _speech.listen(
      (words, isFinal) {
        if (!mounted || _stage != _Stage.listening) return;
        setState(() => _heard = words);
        if (isFinal) _check(words);
      },
      onDone: () async {
        // Son sonuç bitiş bildiriminden hemen sonra da gelebilir; biraz
        // beklenir. Hiç ses duyulmadıysa puanlamak yerine hazıra dönülür.
        await Future<void>.delayed(const Duration(milliseconds: 800));
        if (!mounted || _stage != _Stage.listening) return;
        if (_heard.trim().isEmpty) {
          setState(() {
            _stage = _Stage.ready;
            _error = 'Ses duyulmadı; mikrofona dokunup yeniden dene.';
          });
        } else {
          await _check(_heard);
        }
      },
    );
  }

  Future<void> _check(String answer) async {
    final score = scoreSentence(_sentence, answer);
    setState(() {
      _stage = _Stage.scored;
      _score = score;
    });
    if (widget.mode == PracticeMode.speak) {
      await HardWords.record(ref.read(sharedPreferencesProvider), score);
    }
    if (score.passed) {
      Haptics.success();
      if (_passed.add(_index)) {
        await recordGoodSentence(
          ref,
          spoken: widget.mode == PracticeMode.speak,
        );
      }
    }
  }

  void _retry() => setState(() {
    _stage = _Stage.ready;
    _score = null;
    _heard = '';
    _input.clear();
  });

  void _next() {
    setState(() {
      _index++;
      _stage = _Stage.ready;
      _score = null;
      _heard = '';
      _error = null;
      _input.clear();
    });
    if (!_done && widget.mode == PracticeMode.dictation) _play();
  }

  void _restart() {
    setState(() {
      _index = 0;
      _passed.clear();
      _stage = _Stage.ready;
      _score = null;
    });
    ref.invalidate(practiceSentencesProvider);
  }

  @override
  Widget build(BuildContext context) {
    if (_done) {
      return _Summary(
        passed: _passed.length,
        total: widget.sentences.length,
        hardWords: widget.mode == PracticeMode.speak
            ? HardWords.read(ref.read(sharedPreferencesProvider)).top()
            : const [],
        onWord: _sayWord,
        onAgain: _restart,
        onDone: () => context.pop(),
      );
    }

    final theme = Theme.of(context);
    final total = widget.sentences.length;
    final dictation = widget.mode == PracticeMode.dictation;
    final score = _score;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            Text(
              '${_index + 1}/$total',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
                color: theme.colorScheme.primary,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: (_index + (score != null ? 1 : 0)) / total,
                  minHeight: 6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          widget.mode.instruction,
          style: theme.textTheme.titleMedium?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (score != null)
                  _ScoredSentence(score: score, onWord: _sayWord)
                else if (dictation)
                  Text(
                    'Cümle gizli — dinleyip yaz.',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      fontStyle: FontStyle.italic,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    ),
                  )
                else
                  Text(
                    _sentence,
                    key: const ValueKey('practice-sentence'),
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      height: 1.35,
                    ),
                  ),
                const SizedBox(height: 16),
                // Temadaki düğmeler tam genişlik; Wrap'ta alt alta diziliyordu.
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _play,
                        icon: const Icon(Icons.volume_up_rounded),
                        label: const Text('Dinle'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => _play(slow: true),
                        icon: const Icon(Icons.slow_motion_video_rounded),
                        label: const Text('Yavaş'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        if (score == null) ...[
          if (dictation)
            _DictationInput(controller: _input, onSubmit: _check)
          else
            _MicButton(
              listening: _stage == _Stage.listening,
              heard: _heard,
              onTap: _listen,
            ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: AppColors.error,
              ),
            ),
            if (!dictation) ...[
              const SizedBox(height: 8),
              Center(
                child: TextButton(
                  onPressed: _next,
                  child: const Text('Bu cümleyi atla'),
                ),
              ),
            ],
          ],
        ] else
          _Result(
            score: score,
            heard: dictation ? _input.text : _heard,
            dictation: dictation,
            onRetry: _retry,
            onNext: _next,
            isLast: _index == total - 1,
          ),
      ],
    );
  }
}

class _MicButton extends StatelessWidget {
  const _MicButton({
    required this.listening,
    required this.heard,
    required this.onTap,
  });

  final bool listening;
  final String heard;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = listening ? AppColors.error : theme.colorScheme.primary;
    Widget button = Material(
      color: color,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: SizedBox(
          width: 88,
          height: 88,
          child: Icon(
            listening ? Icons.stop_rounded : Icons.mic_rounded,
            size: 40,
            color: listening ? Colors.white : theme.colorScheme.onPrimary,
          ),
        ),
      ),
    );
    if (listening) {
      button = button
          .animate(onPlay: Motion.loop(reverse: true))
          .scale(
            begin: const Offset(1, 1),
            end: const Offset(1.08, 1.08),
            duration: 600.ms,
          );
    }

    return Column(
      children: [
        Semantics(
          button: true,
          label: listening ? 'Dinlemeyi durdur' : 'Konuşmaya başla',
          child: button,
        ),
        const SizedBox(height: 12),
        Text(
          listening
              ? (heard.isEmpty ? 'Dinliyorum…' : heard)
              : 'Mikrofona dokun ve cümleyi söyle',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            fontStyle: heard.isEmpty ? null : FontStyle.italic,
          ),
        ),
      ],
    );
  }
}

class _DictationInput extends StatelessWidget {
  const _DictationInput({required this.controller, required this.onSubmit});

  final TextEditingController controller;
  final void Function(String) onSubmit;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: controller,
          autocorrect: false,
          enableSuggestions: false,
          minLines: 2,
          maxLines: 4,
          textInputAction: TextInputAction.done,
          decoration: const InputDecoration(
            hintText: 'Duyduğunu buraya yaz…',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (v) {
            if (v.trim().isNotEmpty) onSubmit(v);
          },
        ),
        const SizedBox(height: 12),
        ListenableBuilder(
          listenable: controller,
          builder: (context, _) => FilledButton.icon(
            onPressed: controller.text.trim().isEmpty
                ? null
                : () => onSubmit(controller.text),
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            icon: const Icon(Icons.check_rounded),
            label: const Text('Kontrol et'),
          ),
        ),
      ],
    );
  }
}

/// Hedef cümle; doğru kelimeler yeşil, eksik/yanlışlar kırmızı ve altı çizili.
/// Puanlanmış cümle: doğru kelimeler yeşil, yanlışlar kırmızı. Kırmızı
/// kelimeye dokununca kelime yavaşça okunur.
class _ScoredSentence extends StatelessWidget {
  const _ScoredSentence({required this.score, required this.onWord});

  final SentenceScore score;
  final ValueChanged<String> onWord;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.headlineSmall?.copyWith(
      fontWeight: FontWeight.w700,
      height: 1.35,
    );
    final missed = score.words.where((w) => !w.ok).length;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 6,
          runSpacing: 2,
          children: [
            for (final w in score.words)
              w.ok
                  ? Text(
                      w.word,
                      style: base?.copyWith(color: AppColors.success),
                    )
                  : Semantics(
                      button: true,
                      label: '${w.word}, dinle',
                      excludeSemantics: true,
                      child: InkWell(
                        borderRadius: BorderRadius.circular(6),
                        onTap: () => onWord(w.word),
                        child: Text(
                          w.word,
                          style: base?.copyWith(
                            color: AppColors.error,
                            decoration: TextDecoration.underline,
                            decorationColor: AppColors.error,
                          ),
                        ),
                      ),
                    ),
          ],
        ),
        if (missed > 0) ...[
          const SizedBox(height: 8),
          Text(
            'Kırmızı kelimeye dokun, nasıl okunduğunu dinle.',
            style: theme.textTheme.bodySmall,
          ),
        ],
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    required this.score,
    required this.heard,
    required this.dictation,
    required this.onRetry,
    required this.onNext,
    required this.isLast,
  });

  final SentenceScore score;
  final String heard;
  final bool dictation;
  final VoidCallback onRetry;
  final VoidCallback onNext;
  final bool isLast;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = score.passed ? AppColors.success : AppColors.warning;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Text(
              '%${score.percent}',
              style: theme.textTheme.headlineMedium?.copyWith(
                fontWeight: FontWeight.w900,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                score.passed
                    ? (score.percent == 100 ? 'Kusursuz!' : 'Çok iyi!')
                    : 'Kırmızı kelimelere dikkat edip bir daha dene.',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ).animate().fadeIn(duration: Motion.medium).slideY(begin: 0.2),
        const SizedBox(height: 8),
        Text(
          '${dictation ? 'Yazdığın' : 'Duyulan'}: '
          '${heard.trim().isEmpty ? '—' : heard.trim()}',
          style: theme.textTheme.bodySmall?.copyWith(
            fontStyle: FontStyle.italic,
          ),
        ),
        const SizedBox(height: 20),
        FilledButton(
          onPressed: onNext,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          child: Text(isLast ? 'Bitir' : 'Sonraki cümle'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
      ],
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.passed,
    required this.total,
    required this.onAgain,
    required this.onDone,
    this.hardWords = const [],
    this.onWord,
  });

  final int passed;
  final int total;

  /// Hâlâ zorlanılan kelimeler; dokununca okunur.
  final List<String> hardWords;
  final ValueChanged<String>? onWord;
  final VoidCallback onAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 32),
      children: [
        Icon(
          passed == total
              ? Icons.emoji_events_rounded
              : Icons.record_voice_over_rounded,
          size: 64,
          color: passed == total
              ? AppColors.warning
              : theme.colorScheme.primary,
        ).animate().scale(curve: Curves.elasticOut, duration: Motion.slow),
        const SizedBox(height: 16),
        Text(
          '$passed/$total cümle başarılı',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '+${passed * xpPerGoodSentence} XP',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
        if (hardWords.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(
            'Zorlandığın kelimeler',
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Dokun ve dinle. Doğru söyledikçe listeden düşerler.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final word in hardWords)
                ActionChip(
                  avatar: const Icon(Icons.volume_up_rounded, size: 18),
                  label: Text(word),
                  onPressed: onWord == null ? null : () => onWord!(word),
                ),
            ],
          ),
        ],
        const SizedBox(height: 28),
        FilledButton.icon(
          onPressed: onAgain,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Yeni cümlelerle devam'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onDone, child: const Text('Bitir')),
      ],
    );
  }
}
