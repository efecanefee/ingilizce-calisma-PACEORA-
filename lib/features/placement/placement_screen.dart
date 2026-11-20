import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/constants.dart';
import '../../app/mascot.dart';
import '../../app/motion.dart';
import '../../data/placement.dart';
import '../../data/providers.dart';

/// Kısa seviye testini açar; bitirilirse bulunan seviyeyi döndürür.
Future<DifficultyLevel?> openPlacementTest(BuildContext context) {
  return Navigator.of(context).push<DifficultyLevel>(
    MaterialPageRoute(builder: (_) => const PlacementTestScreen()),
  );
}

/// 12 soruluk seviye testi. Sorular tek tek gelir; cevap seçilince
/// sıradakine geçilir. Sonda seviye ve doğru sayısı gösterilir.
class PlacementTestScreen extends ConsumerStatefulWidget {
  const PlacementTestScreen({super.key});

  @override
  ConsumerState<PlacementTestScreen> createState() =>
      _PlacementTestScreenState();
}

class _PlacementTestScreenState extends ConsumerState<PlacementTestScreen> {
  final _answers = <int>[];

  int get _index => _answers.length;
  bool get _done => _index >= placementQuestions.length;

  int get _correct => [
    for (var i = 0; i < _answers.length; i++)
      if (placementQuestions[i].isCorrect(_answers[i])) i,
  ].length;

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
                  correct: _correct,
                  total: placementQuestions.length,
                  level: placementLevel(_correct),
                )
              : _QuestionView(
                  key: ValueKey(_index),
                  index: _index,
                  question: placementQuestions[_index],
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
    required this.question,
    required this.onChoose,
  });

  final int index;
  final PlacementQuestion question;
  final ValueChanged<int> onChoose;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = placementQuestions.length;

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
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
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
    required this.correct,
    required this.total,
    required this.level,
  });

  final int correct;
  final int total;
  final DifficultyLevel level;

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
      ],
    );
  }
}
