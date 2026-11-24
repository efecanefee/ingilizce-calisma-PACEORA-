import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/answer_option.dart';
import '../../app/celebrate_banner.dart';
import '../../app/constants.dart';
import '../../app/error_view.dart';
import '../../app/mascot.dart';
import '../../app/motion.dart';
import '../../app/sounds.dart';
import '../../data/level_check.dart';
import '../../data/level_exam.dart';
import '../../data/placement.dart';
import '../../data/providers.dart';
import '../../data/rewards.dart';

/// Seviye atlama sınavı: bir üst kademeden 10 soru.
class LevelExamScreen extends ConsumerWidget {
  const LevelExamScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).value;
    final bank = ref.watch(placementBankProvider);
    final current = user == null ? null : DifficultyLevel.fromCode(user.level);
    final target = current == null ? null : levelExamTarget(current);

    return Scaffold(
      appBar: AppBar(title: const Text('Seviye atlama sınavı')),
      body: switch (bank) {
        _ when current == null => const Center(
          child: CircularProgressIndicator(),
        ),
        _ when target == null => const Center(
          child: Padding(
            padding: EdgeInsets.all(32),
            child: Text(
              'Zaten en üst seviyedesin. Tebrikler!',
              textAlign: TextAlign.center,
            ),
          ),
        ),
        AsyncData(:final value) => _Exam(
          bank: value,
          current: current,
          target: target,
        ),
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(placementBankProvider),
        ),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _Exam extends ConsumerStatefulWidget {
  const _Exam({
    required this.bank,
    required this.current,
    required this.target,
  });

  final PlacementBank bank;
  final DifficultyLevel current;
  final DifficultyLevel target;

  @override
  ConsumerState<_Exam> createState() => _ExamState();
}

class _ExamState extends ConsumerState<_Exam> {
  late final List<PlacementQuestion> _questions = drawLevelExam(
    widget.bank,
    widget.target,
  );
  final _answers = <int>[];
  bool _started = false;
  int? _picked;
  bool _applying = false;
  bool _applied = false;

  int get _correct => [
    for (var i = 0; i < _answers.length; i++)
      if (_questions[i].isCorrect(_answers[i])) i,
  ].length;

  bool get _done => _answers.length >= _questions.length;
  bool get _passed => _correct >= levelExamPassMark(_questions.length);

  Future<void> _choose(int option) async {
    if (_picked != null) return;
    Haptics.tap();
    final q = _questions[_answers.length];
    Sounds.answer(correct: q.isCorrect(option));
    setState(() => _picked = option);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _answers.add(option);
      _picked = null;
    });
    if (_done) {
      await ref
          .read(sharedPreferencesProvider)
          .setString(levelExamAtKey, clock.now().toIso8601String());
      if (_passed) Haptics.success();
    }
  }

  Future<void> _apply() async {
    setState(() => _applying = true);
    final messenger = ScaffoldMessenger.of(context);
    final repository = ref.read(repositoryProvider);
    final prefs = ref.read(sharedPreferencesProvider);
    await repository.updateLevel(widget.target.code);
    await prefs.setInt(levelUpsKey, (prefs.getInt(levelUpsKey) ?? 0) + 1);
    await ref.read(profileProvider.notifier).refresh();
    // Kalan günler yeni seviyeye göre yeniden yazılır; ilerleme korunur.
    await ref.read(weekPlanProvider.notifier).regenerate();
    ref.invalidate(gameProvider);
    if (!mounted) return;
    setState(() {
      _applying = false;
      _applied = true;
    });
    celebrateWithBanner(
      context,
      title: 'Yeni seviye: ${widget.target.label}!',
      message: 'Sınavı geçtin. Programın yeni seviyene göre hazırlandı.',
      sound: SoundEffect.levelUp,
    );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          'Artık ${widget.target.label} seviyesindesin. Programın yenilendi.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (!_started) return _intro(theme);
    if (_done) return _result(theme);

    final q = _questions[_answers.length];
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
      children: [
        Row(
          children: [
            Text(
              '${_answers.length + 1}/${_questions.length}',
              style: theme.textTheme.labelLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: _answers.length / _questions.length,
                  minHeight: 6,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(q.skill.instruction, style: theme.textTheme.labelLarge),
        const SizedBox(height: 8),
        if (q.passage != null) ...[
          Card(
            margin: EdgeInsets.zero,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Text(
                q.passage!,
                style: theme.textTheme.bodyLarge?.copyWith(height: 1.45),
              ),
            ),
          ),
          const SizedBox(height: 14),
        ],
        Text(
          q.prompt,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 16),
        for (var i = 0; i < q.options.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: AnswerOption(
              label: q.options[i],
              state: answerStateFor(
                option: i,
                correct: q.answer,
                picked: _picked,
              ),
              onPressed: _picked == null ? () => _choose(i) : null,
            ),
          ),
      ],
    );
  }

  Widget _intro(ThemeData theme) => ListView(
    padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
    children: [
      const Center(child: PaceSticker(PacePose.confident, size: 150)),
      const SizedBox(height: 16),
      Text(
        '${widget.current.label} → ${widget.target.label}',
        textAlign: TextAlign.center,
        style: theme.textTheme.headlineSmall?.copyWith(
          fontWeight: FontWeight.w800,
        ),
      ),
      const SizedBox(height: 8),
      Text(
        '${_questions.length} soru, ${widget.target.label} seviyesinden. '
        '${levelExamPassMark(_questions.length)} doğru yaparsan bir üst '
        'seviyeye geçebilirsin. Süre sınırı yok.',
        textAlign: TextAlign.center,
        style: theme.textTheme.bodyLarge,
      ),
      const SizedBox(height: 28),
      FilledButton.icon(
        style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
        onPressed: () => setState(() => _started = true),
        icon: const Icon(Icons.play_arrow_rounded),
        label: const Text('Sınava başla'),
      ),
    ],
  );

  Widget _result(ThemeData theme) {
    final passed = _passed;
    final focus = LevelPreview.of(widget.target).focus;
    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Center(
          child: PaceSticker(
            passed ? PacePose.graduate : PacePose.strong,
            size: 140,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          '${_questions.length} sorudan $_correct doğru',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          passed
              ? '${widget.target.label} seviyesine hazırsın!'
              : 'Henüz değil — ${levelExamPassMark(_questions.length)} doğru '
                    'gerekiyordu. 3 hafta sonra yeniden dene; şu konulara '
                    'odaklan:',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyLarge,
        ),
        if (!passed) ...[
          const SizedBox(height: 12),
          for (final item in focus)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(Icons.arrow_right_rounded),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
        ],
        const SizedBox(height: 28),
        if (passed && !_applied)
          FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
            ),
            onPressed: _applying ? null : _apply,
            icon: const Icon(Icons.trending_up_rounded),
            label: Text('${widget.target.label} seviyesine geç'),
          ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => context.canPop() ? context.pop() : context.go('/'),
          child: Text(passed && !_applied ? 'Şimdilik kalsın' : 'Kapat'),
        ),
      ],
    );
  }
}
