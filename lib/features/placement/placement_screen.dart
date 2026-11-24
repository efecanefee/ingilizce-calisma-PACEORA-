import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/answer_option.dart';
import '../../app/constants.dart';
import '../../app/mascot.dart';
import '../../app/motion.dart';
import '../../app/sounds.dart';
import '../../app/theme.dart';
import '../../data/placement.dart';
import '../../data/providers.dart';
import '../../data/speech_service.dart';

/// Seviye testini açar; bitirilirse bulunan seviyeyi döndürür.
/// Kök gezgin kullanılır: test alt menünün üstünde tam ekran açılır, test
/// ortasında sekme değiştirilemez.
Future<DifficultyLevel?> openPlacementTest(BuildContext context) {
  return Navigator.of(context, rootNavigator: true).push<DifficultyLevel>(
    MaterialPageRoute(builder: (_) => const PlacementTestScreen()),
  );
}

/// Seviye testi: 20 soru, 4 bölüm. Dilbilgisi, kelime, okuma ve dinleme
/// soruları karışık gelir; ilk bölüm kolay-orta, sonrakiler cevaplara göre. Sonda seviye ve beceri dökümü gösterilir.
class PlacementTestScreen extends ConsumerWidget {
  const PlacementTestScreen({super.key, this.random});

  /// Soru seçimi ve karıştırma için; testlerde sabit tohum verilir.
  final Random? random;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bank = ref.watch(placementBankProvider);
    return switch (bank) {
      AsyncData(:final value) => _PlacementSession(bank: value, random: random),
      AsyncError() => Scaffold(
        appBar: AppBar(title: const Text('Seviye testi')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Sorular yüklenemedi.', textAlign: TextAlign.center),
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: () => ref.invalidate(placementBankProvider),
                  child: const Text('Tekrar dene'),
                ),
              ],
            ),
          ),
        ),
      ),
      _ => Scaffold(
        appBar: AppBar(title: const Text('Seviye testi')),
        body: const Center(child: CircularProgressIndicator()),
      ),
    };
  }
}

class _PlacementSession extends ConsumerStatefulWidget {
  const _PlacementSession({required this.bank, this.random});

  final PlacementBank bank;
  final Random? random;

  @override
  ConsumerState<_PlacementSession> createState() => _PlacementSessionState();
}

class _PlacementSessionState extends ConsumerState<_PlacementSession> {
  final _answers = <int>[];

  /// Seçildi, renkli geri bildirim gösteriliyor; kısa süre sonra sıradaki
  /// soruya geçilir.
  int? _picked;

  /// Doğru/yanlış renklerinin ekranda kalma süresi.
  static const feedbackDelay = Duration(milliseconds: 900);

  late final _draw = PlacementDraw(widget.bank, widget.random);

  /// Sorular bölüm bölüm eklenir; her bölüm önceki cevaplara göre seçilir.
  late final _questions = [..._draw.nextBlock(const [], const [])];

  int get _index => _answers.length;
  bool get _done => _index >= placementQuestionCount;

  /// 1-4 arası bölüm numarası.
  int get _section {
    var end = 0;
    for (var b = 0; b < placementBlockSizes.length; b++) {
      end += placementBlockSizes[b];
      if (_index < end) return b + 1;
    }
    return placementBlockSizes.length;
  }

  /// Test yarıdayken çıkılırsa ilerleme kaybolur; önce sorulur.
  Future<void> _confirmExit() async {
    final leave = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Testten çıkılsın mı?'),
        content: const Text('Cevapların kaydedilmez, test baştan başlar.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Devam et'),
          ),
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Çık'),
          ),
        ],
      ),
    );
    if (leave == true && mounted) Navigator.of(context).pop();
  }

  Future<void> _choose(int option) async {
    if (_picked != null) return;
    Haptics.tap();
    Sounds.answer(correct: _questions[_index].isCorrect(option));
    setState(() => _picked = option);
    await Future<void>.delayed(feedbackDelay);
    if (!mounted) return;
    await ref.read(speechServiceProvider).stopSpeaking();
    if (!mounted) return;
    setState(() {
      _answers.add(option);
      _picked = null;
      // Bölüm bitti: sıradaki, şimdiye kadarki cevaplara göre.
      if (!_done && _answers.length == _questions.length) {
        _questions.addAll(_draw.nextBlock([..._questions], _answers));
      }
    });
    if (_done) {
      await PlacementRecord.save(
        ref.read(sharedPreferencesProvider),
        scorePlacement(_questions, _answers).level,
      );
    }
  }

  void _undo() {
    if (_answers.isEmpty || _picked != null) return;
    setState(() {
      _answers.removeLast();
      // Önceki bölüme dönüldü: sonraki bölüm yeni cevaplarla yeniden seçilir.
      var end = 0;
      for (final size in placementBlockSizes) {
        end += size;
        if (end > _answers.length) break;
      }
      if (_questions.length > end) {
        _draw.dropLastBlock();
        _questions.removeRange(end, _questions.length);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final inProgress = _answers.isNotEmpty && !_done;
    return PopScope(
      canPop: !inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Seviye testi'),
          actions: [
            if (!_done && _answers.isNotEmpty)
              TextButton(onPressed: _undo, child: const Text('Önceki')),
          ],
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: Motion.medium,
            child: _done
                ? _Result(
                    key: const ValueKey('result'),
                    questions: _questions,
                    answers: _answers,
                    result: scorePlacement(_questions, _answers),
                  )
                : _QuestionView(
                    key: ValueKey(_index),
                    index: _index,
                    section: _section,
                    question: _questions[_index],
                    picked: _picked,
                    onChoose: _choose,
                  ),
          ),
        ),
      ),
    );
  }
}

class _QuestionView extends StatelessWidget {
  const _QuestionView({
    super.key,
    required this.index,
    required this.section,
    required this.question,
    required this.picked,
    required this.onChoose,
  });

  final int index;
  final int section;
  final PlacementQuestion question;

  /// Seçilen cevap; null ise henüz seçilmedi.
  final int? picked;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.72);
    final hasPassage = question.passage != null;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        LinearProgressIndicator(
          value: index / placementQuestionCount,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 8),
        Text(
          'Bölüm $section/4 · Soru ${index + 1}/$placementQuestionCount',
          style: theme.textTheme.labelMedium?.copyWith(color: muted),
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Icon(_iconFor(question.skill), size: 20, color: muted),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                question.skill.instruction,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (!hasPassage) ...[
          const Center(
            child: PaceMascot(mood: PaceMood.study, size: 96, animate: false),
          ),
          const SizedBox(height: 16),
        ],
        if (question.skill == PlacementSkill.reading)
          _PassageCard(text: question.passage!),
        if (question.skill == PlacementSkill.listening)
          _ListenCard(script: question.passage!),
        if (hasPassage) const SizedBox(height: 16),
        Text(
          question.prompt,
          style:
              (hasPassage
                      ? theme.textTheme.titleMedium
                      : theme.textTheme.titleLarge)
                  ?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < question.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AnswerOption(
              label: question.options[i],
              state: answerStateFor(
                option: i,
                correct: question.answer,
                picked: picked,
              ),
              onPressed: picked == null ? () => onChoose(i) : null,
            ),
          ),
      ],
    );
  }
}

IconData _iconFor(PlacementSkill skill) => switch (skill) {
  PlacementSkill.grammar => Icons.rule_rounded,
  PlacementSkill.vocabulary => Icons.translate_rounded,
  PlacementSkill.reading => Icons.menu_book_rounded,
  PlacementSkill.listening => Icons.headphones_rounded,
};

class _PassageCard extends StatelessWidget {
  const _PassageCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(height: 1.5),
        ),
      ),
    );
  }
}

/// Dinleme sorusu: metin gizli, cihazın sesli okumasıyla dinlenir. Ses
/// yoksa ya da duyulmuyorsa metin açılabilir; soru yine çözülür.
class _ListenCard extends ConsumerStatefulWidget {
  const _ListenCard({required this.script});

  final String script;

  @override
  ConsumerState<_ListenCard> createState() => _ListenCardState();
}

class _ListenCardState extends ConsumerState<_ListenCard> {
  bool _showText = false;
  bool _noVoice = false;
  bool _playing = false;

  Future<void> _play({bool slow = false}) async {
    setState(() => _playing = true);
    final speech = ref.read(speechServiceProvider);
    // Bazı ses motorları okumanın bittiğini hiç bildirmez; düğmeler metnin
    // uzunluğuna göre bir süre sonra yeniden açılır.
    final words = widget.script.split(RegExp(r'\s+')).length;
    final limit = Duration(milliseconds: (words * (slow ? 1500 : 500)) + 3000);
    final ok = await speech
        .speak(widget.script, slow: slow)
        .timeout(limit, onTimeout: () => true);
    if (!mounted) return;
    setState(() {
      _playing = false;
      if (!ok) {
        _noVoice = true;
        _showText = true;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _playing ? null : _play,
                    icon: const Icon(Icons.volume_up_rounded),
                    label: const Text('Dinle'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _playing ? null : () => _play(slow: true),
                    icon: const Icon(Icons.slow_motion_video_rounded),
                    label: const Text('Yavaş'),
                  ),
                ),
              ],
            ),
            if (_noVoice) ...[
              const SizedBox(height: 12),
              Text(
                'Cihazda İngilizce ses bulunamadı; metni okuyarak cevapla.',
                style: theme.textTheme.bodySmall,
              ),
            ],
            if (_showText) ...[
              const SizedBox(height: 12),
              Text(
                widget.script,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.5),
              ),
            ] else
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: () => setState(() => _showText = true),
                  child: const Text('Ses gelmiyor mu? Metni göster'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    super.key,
    required this.questions,
    required this.answers,
    required this.result,
  });

  final List<PlacementQuestion> questions;
  final List<int> answers;
  final PlacementResult result;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final wrong = result.total - result.correct;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        const Center(child: PaceMascot(mood: PaceMood.cheer, size: 170)),
        const SizedBox(height: 20),
        Text(
          'Seviyen: ${result.level.label}',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '${result.total} sorudan ${result.correct} doğru. Zor sorular daha '
          'çok puan kazandırdı. Program bu seviyeye göre hazırlanacak; '
          'ilerledikçe zorluk kendiliğinden ayarlanır.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
            child: Column(
              children: [
                for (final MapEntry(key: skill, value: (right, total))
                    in result.bySkill.entries)
                  _SkillRow(skill: skill, right: right, total: total),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(result.level),
          child: const Text('Bu seviyeyle devam et'),
        ),
        if (wrong > 0) ...[
          const SizedBox(height: 20),
          // Yanlışlar ve doğru cevaplar: testten bir şey öğrenilsin.
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: const Icon(Icons.fact_check_rounded),
              title: Text('Yanlışlarını gör ($wrong)'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                for (var i = 0; i < answers.length; i++)
                  if (!questions[i].isCorrect(answers[i]))
                    _ReviewRow(
                      question: questions[i],
                      chosen: questions[i].options[answers[i]],
                    ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _SkillRow extends StatelessWidget {
  const _SkillRow({
    required this.skill,
    required this.right,
    required this.total,
  });

  final PlacementSkill skill;
  final int right;
  final int total;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Semantics(
      label: '${skill.label}: $total sorudan $right doğru',
      excludeSemantics: true,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Icon(_iconFor(skill), size: 20),
            const SizedBox(width: 10),
            SizedBox(
              width: 92,
              child: Text(skill.label, style: theme.textTheme.bodyMedium),
            ),
            Expanded(
              child: LinearProgressIndicator(
                value: total == 0 ? 0 : right / total,
                minHeight: 8,
                borderRadius: BorderRadius.circular(4),
              ),
            ),
            const SizedBox(width: 12),
            Text(
              '$right/$total',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.question, required this.chosen});

  final PlacementQuestion question;
  final String chosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final passage = question.passage;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (passage != null) ...[
            Text(
              question.skill == PlacementSkill.listening
                  ? 'Dinlenen: “$passage”'
                  : passage,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(question.prompt, style: theme.textTheme.bodyMedium),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: chosen,
                  style: TextStyle(
                    color: theme.colorScheme.error,
                    decoration: TextDecoration.lineThrough,
                  ),
                ),
                const TextSpan(text: '  →  '),
                TextSpan(
                  text: question.correctOption,
                  style: TextStyle(
                    color: isDark ? AppColors.success : AppColors.successDark,
                    fontWeight: FontWeight.w700,
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
