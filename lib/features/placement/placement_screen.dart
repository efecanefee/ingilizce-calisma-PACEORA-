import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/constants.dart';
import '../../app/mascot.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/placement.dart';
import '../../data/providers.dart';

/// Kısa seviye testini açar; bitirilirse bulunan seviyeyi döndürür.
Future<DifficultyLevel?> openPlacementTest(BuildContext context) {
  return Navigator.of(context).push<DifficultyLevel>(
    MaterialPageRoute(builder: (_) => const PlacementTestScreen()),
  );
}

/// Kısa seviye testi (kademe başına 2 soru). Sorular tek tek gelir; cevap seçilince
/// sıradakine geçilir. Sonda seviye ve doğru sayısı gösterilir.
class PlacementTestScreen extends ConsumerStatefulWidget {
  const PlacementTestScreen({super.key, this.random});

  /// Soru seçimi ve karıştırma için; testlerde sabit tohum verilir.
  final Random? random;

  @override
  ConsumerState<PlacementTestScreen> createState() =>
      _PlacementTestScreenState();
}

class _PlacementTestScreenState extends ConsumerState<PlacementTestScreen> {
  final _answers = <int>[];

  /// Her açılışta havuzdan yeni sorular, seçenekler karışık.
  late final _questions = drawPlacementQuestions(widget.random);

  int get _index => _answers.length;
  bool get _done => _index >= _questions.length;

  int get _correct => [
    for (var i = 0; i < _answers.length; i++)
      if (_questions[i].isCorrect(_answers[i])) i,
  ].length;

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
    Haptics.tap();
    setState(() => _answers.add(option));
    if (_done) {
      await PlacementRecord.save(
        ref.read(sharedPreferencesProvider),
        placementLevel(_correct),
      );
    }
  }

  void _undo() {
    if (_answers.isEmpty) return;
    setState(_answers.removeLast);
  }

  @override
  Widget build(BuildContext context) {
    final inProgress = _answers.isNotEmpty && !_done;
    return PopScope(
      canPop: !inProgress,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmExit();
      },
      child: _buildScaffold(),
    );
  }

  Widget _buildScaffold() {
    return Scaffold(
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
                  correct: _correct,
                  level: placementLevel(_correct),
                )
              : _QuestionView(
                  key: ValueKey(_index),
                  index: _index,
                  total: _questions.length,
                  question: _questions[_index],
                  onChoose: _choose,
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
    required this.total,
    required this.question,
    required this.onChoose,
  });

  final int index;
  final int total;
  final PlacementQuestion question;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
      children: [
        LinearProgressIndicator(
          value: index / total,
          minHeight: 6,
          borderRadius: BorderRadius.circular(3),
        ),
        const SizedBox(height: 8),
        Text(
          'Soru ${index + 1}/$total · boşluğa uyanı seç',
          style: theme.textTheme.labelMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.72),
          ),
        ),
        const SizedBox(height: 16),
        const Center(
          child: PaceMascot(mood: PaceMood.study, size: 110, animate: false),
        ),
        const SizedBox(height: 16),
        Text(
          question.prompt,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 20),
        for (var i = 0; i < question.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: OutlinedButton(
              onPressed: () => onChoose(i),
              style: OutlinedButton.styleFrom(
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 18),
              ),
              child: Text(question.options[i]),
            ),
          ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({
    super.key,
    required this.questions,
    required this.answers,
    required this.correct,
    required this.level,
  });

  final List<PlacementQuestion> questions;
  final List<int> answers;
  final int correct;
  final DifficultyLevel level;

  int get total => questions.length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 24),
      children: [
        const Center(child: PaceMascot(mood: PaceMood.cheer, size: 170)),
        const SizedBox(height: 20),
        Text(
          'Seviyen: ${level.label}',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          '$total sorudan $correct doğru. Program bu seviyeye göre '
          'hazırlanacak; ilerledikçe zorluk kendiliğinden ayarlanır.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
        const SizedBox(height: 28),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(level),
          child: const Text('Bu seviyeyle devam et'),
        ),
        if (correct < total) ...[
          const SizedBox(height: 20),
          // Yanlışlar ve doğru cevaplar: testten bir şey öğrenilsin.
          Card(
            clipBehavior: Clip.antiAlias,
            child: ExpansionTile(
              leading: const Icon(Icons.fact_check_rounded),
              title: Text('Yanlışlarını gör (${total - correct})'),
              childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              children: [
                for (var i = 0; i < total; i++)
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

class _ReviewRow extends StatelessWidget {
  const _ReviewRow({required this.question, required this.chosen});

  final PlacementQuestion question;
  final String chosen;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
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
