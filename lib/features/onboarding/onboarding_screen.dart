import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/answer_option.dart';
import '../../app/constants.dart';
import '../../app/logo.dart';
import '../../app/mascot.dart';
import '../../app/motion.dart';
import '../../app/sounds.dart';
import '../../data/level_check.dart';
import '../../data/placement.dart';
import '../../data/providers.dart';
import '../placement/placement_screen.dart';

/// Dört adımlı onboarding: isim → seviye → seviye önizlemesi → günlük süre.
///
/// Son adımda profil kaydedilir ve Gemini'den haftalık plan üretilir.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 4;

  final _pageController = PageController();
  final _nameController = TextEditingController();

  int _step = 0;
  DifficultyLevel _level = DifficultyLevel.b1;

  /// Seviye testten geldiyse önizleme adımında kontrol soruları sorulmaz.
  bool _placementDone = false;
  int _dailyMinutes = AppConstants.defaultDailyMinutes;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    // İsim boşken "Devam" pasif kalsın diye her tuşta yeniden çiz.
    _nameController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  bool get _canContinue => _step != 0 || _nameController.text.trim().isNotEmpty;

  void _next() {
    // İsim adımından sonra klavye açık kalıp seçenekleri örtmesin.
    FocusScope.of(context).unfocus();
    if (_step < _stepCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
    }
  }

  Future<void> _takePlacementTest() async {
    final level = await openPlacementTest(context);
    if (level != null && mounted) {
      setState(() {
        _level = level;
        _placementDone = true;
      });
    }
  }

  void _back() {
    if (_step == 0) return;
    _pageController.previousPage(
      duration: const Duration(milliseconds: 250),
      curve: Curves.easeOut,
    );
  }

  Future<void> _finish() async {
    setState(() => _submitting = true);
    try {
      await ref.read(profileProvider.notifier).save(
            name: _nameController.text.trim(),
            level: _level.code,
            dailyMinutes: _dailyMinutes,
          );
      final result = await ref.read(weekPlanProvider.notifier).regenerate();
      await ref
          .read(sharedPreferencesProvider)
          .setBool(AppConstants.prefOnboardingDone, true);

      if (!mounted) return;
      if (result.offline) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Gemini\'ye ulaşılamadı, hazır program yüklendi. '
              'Ana ekrandan planı yenileyebilirsin.',
            ),
          ),
        );
      }
      context.go('/');
    } catch (e) {
      if (!mounted) return;
      setState(() => _submitting = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Kayıt sırasında hata: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final content = Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  if (_step > 0)
                    IconButton(
                      onPressed: _submitting ? null : _back,
                      icon: const Icon(Icons.arrow_back),
                      tooltip: 'Geri',
                    ),
                  // İlk adımda marka zaten büyük logo ile karşılıyor.
                  Expanded(
                    child: _step > 0
                        ? const Center(child: PaceoraWordmark())
                        : const SizedBox.shrink(),
                  ),
                  if (_step > 0) const SizedBox(width: 48),
                ],
              ),
              const SizedBox(height: 16),
              LinearProgressIndicator(
                value: (_step + 1) / _stepCount,
                minHeight: 6,
                borderRadius: BorderRadius.circular(3),
              ),
              const SizedBox(height: 32),
              Expanded(
                child: PageView(
                  controller: _pageController,
                  physics: const NeverScrollableScrollPhysics(),
                  onPageChanged: (i) => setState(() => _step = i),
                  children: [
                    _NameStep(controller: _nameController),
                    _LevelStep(
                      selected: _level,
                      onChanged: (l) => setState(() {
                        _level = l;
                        _placementDone = false;
                      }),
                      onTest: _takePlacementTest,
                    ),
                    _LevelCheckStep(
                      // Seviye değişince kontrol baştan başlar.
                      key: ValueKey(_level),
                      level: _level,
                      placementDone: _placementDone,
                      onChangeLevel: (l) => setState(() => _level = l),
                    ),
                    _MinutesStep(
                      selected: _dailyMinutes,
                      onChanged: (m) => setState(() => _dailyMinutes = m),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: (!_canContinue || _submitting) ? null : _next,
                child: _submitting
                    ? const SizedBox(
                        height: 22,
                        width: 22,
                        child: CircularProgressIndicator(strokeWidth: 2.5),
                      )
                    : Text(_step == _stepCount - 1 ? 'Programımı oluştur' : 'Devam'),
              ),
              if (_submitting) ...[
                const SizedBox(height: 12),
                Text(
                  'Haftalık programın hazırlanıyor…',
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );

    // Android'in sistem geri tuşu ilk adım dışında uygulamayı kapatmasın;
    // ekrandaki geri oku gibi bir önceki adıma dönsün.
    return PopScope(
      canPop: _step == 0,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop && !_submitting) _back();
      },
      child: content,
    );
  }
}

/// Adımların ortak başlık + açıklama düzeni.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({
    required this.title,
    required this.subtitle,
    required this.child,
    this.header,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// Başlığın üstünde gösterilecek isteğe bağlı görsel (ilk adımdaki logo).
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (header != null) ...[
            header!
                .animate()
                .fadeIn(duration: Motion.slow)
                .scale(begin: const Offset(0.85, 0.85), curve: Curves.easeOutBack),
            const SizedBox(height: 32),
          ],
          Text(
            title,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ).entrance(1),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ).entrance(2),
          const SizedBox(height: 28),
          child.entrance(3),
        ],
      ),
    );
  }
}

class _NameStep extends StatelessWidget {
  const _NameStep({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      header: const Center(child: AnimatedPaceoraLockup()),
      title: 'Merhaba! Sana nasıl hitap edelim?',
      subtitle: 'Günlük derslerinde ve raporlarında bu ismi kullanacağız.',
      child: TextField(
        controller: controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        textInputAction: TextInputAction.done,
        decoration: const InputDecoration(hintText: 'Adın'),
      ),
    );
  }
}

class _LevelStep extends StatelessWidget {
  const _LevelStep({
    required this.selected,
    required this.onChanged,
    required this.onTest,
  });

  final DifficultyLevel selected;
  final ValueChanged<DifficultyLevel> onChanged;
  final VoidCallback onTest;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Seviyen ne durumda?',
      subtitle:
          'Emin değilsen kısa testi çöz ya da B1 ile başla — uygulama ilerledikçe zorluğu kendisi ayarlıyor.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final level in DifficultyLevel.values)
                ChoiceChip(
                  label: Text(level.label),
                  selected: level == selected,
                  onSelected: (_) => onChanged(level),
                ),
            ],
          ),
          const SizedBox(height: 20),
          Card(
            child: ListTile(
              contentPadding: const EdgeInsets.fromLTRB(8, 4, 16, 4),
              leading: const PaceMascot(
                mood: PaceMood.study,
                size: 52,
                animate: false,
              ),
              title: const Text('Kısa seviye testi'),
              subtitle: Text('$placementQuestionCount soru, yaklaşık 3 dakika'),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: onTest,
            ),
          ),
        ],
      ),
    );
  }
}

/// Seçilen seviyenin önizlemesi ve isteğe bağlı 4 soruluk kontrol.
class _LevelCheckStep extends StatefulWidget {
  const _LevelCheckStep({
    super.key,
    required this.level,
    required this.placementDone,
    required this.onChangeLevel,
  });

  final DifficultyLevel level;
  final bool placementDone;
  final ValueChanged<DifficultyLevel> onChangeLevel;

  @override
  State<_LevelCheckStep> createState() => _LevelCheckStepState();
}

class _LevelCheckStepState extends State<_LevelCheckStep> {
  final _answers = <int>[];
  bool _started = false;

  /// Seçildi, renkli geri bildirim gösteriliyor.
  int? _picked;

  Future<void> _choose(int option) async {
    if (_picked != null) return;
    Haptics.tap();
    final question = _preview.questions[_answers.length];
    Sounds.answer(correct: question.isCorrect(option));
    setState(() => _picked = option);
    await Future<void>.delayed(const Duration(milliseconds: 900));
    if (!mounted) return;
    setState(() {
      _answers.add(option);
      _picked = null;
    });
  }

  LevelPreview get _preview => LevelPreview.of(widget.level);

  int get _correct => [
    for (var i = 0; i < _answers.length; i++)
      if (_preview.questions[i].isCorrect(_answers[i])) i,
  ].length;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = _preview;

    return _StepScaffold(
      title: '${widget.level.label} seviyesinde neler var?',
      subtitle: widget.placementDone
          ? 'Seviye testine göre programın bu konular üzerine kurulacak.'
          : 'Programın bu konular üzerine kurulacak. İstersen 4 soruluk kısa '
                'kontrolle seviyenin sana uygun olup olmadığını gör.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Nelere odaklanacağız',
                    style: theme.textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 10),
                  for (final item in preview.focus)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.check_circle_rounded,
                            size: 18,
                            color: theme.colorScheme.primary,
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              item,
                              style: theme.textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
          if (!widget.placementDone) ...[
            const SizedBox(height: 16),
            _buildCheck(theme),
          ],
        ],
      ),
    );
  }

  Widget _buildCheck(ThemeData theme) {
    final questions = _preview.questions;

    if (!_started) {
      return OutlinedButton.icon(
        onPressed: () => setState(() => _started = true),
        icon: const Icon(Icons.quiz_rounded),
        label: const Text('4 soruluk kontrolü çöz'),
      );
    }

    if (_answers.length < questions.length) {
      final q = questions[_answers.length];
      return Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Soru ${_answers.length + 1}/${questions.length}',
                style: theme.textTheme.labelMedium,
              ),
              const SizedBox(height: 6),
              Text(
                q.prompt,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < q.options.length; i++)
                    AnswerOption(
                      label: q.options[i],
                      expand: false,
                      state: answerStateFor(
                        option: i,
                        correct: q.answer,
                        picked: _picked,
                      ),
                      onPressed: _picked == null ? () => _choose(i) : null,
                    ),
                ],
              ),
            ],
          ),
        ),
      );
    }

    final verdict = levelCheckVerdict(widget.level, _correct);
    final suggested = switch (verdict) {
      LevelCheckVerdict.lower => widget.level.step(-1),
      LevelCheckVerdict.higher => widget.level.step(1),
      LevelCheckVerdict.fits => null,
    };
    final message = switch (verdict) {
      LevelCheckVerdict.fits => 'Bu seviye sana uygun görünüyor.',
      LevelCheckVerdict.higher =>
        'Hepsi doğru! ${suggested!.label} seviyesi seni daha çok geliştirebilir.',
      LevelCheckVerdict.lower =>
        'Biraz zorlandın; ${suggested!.label} ile başlamak daha rahat olabilir.',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${questions.length} sorudan $_correct doğru',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(message, style: theme.textTheme.bodyMedium),
            if (suggested != null) ...[
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () => widget.onChangeLevel(suggested),
                child: Text('${suggested.label} seviyesine geç'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _MinutesStep extends StatelessWidget {
  const _MinutesStep({required this.selected, required this.onChanged});

  final int selected;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return _StepScaffold(
      title: 'Günde ne kadar vakit ayırabilirsin?',
      subtitle: 'Kısa ve düzenli çalışmak, uzun ve seyrek çalışmaktan iyidir.',
      child: Column(
        children: [
          // Ders üretimi öncesi açık bilgilendirme.
          Padding(
            padding: const EdgeInsets.only(bottom: 16),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lock_outline_rounded,
                  size: 18,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Programın ve derslerin Google Gemini ile hazırlanır. '
                    'Seviyen ve konular paylaşılır, adın paylaşılmaz. '
                    'Ayrıntılar: Ayarlar > Gizlilik.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          for (final minutes in AppConstants.dailyMinuteOptions)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(20),
                onTap: () => onChanged(minutes),
                child: Card(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                    side: BorderSide(
                      color: minutes == selected
                          ? theme.colorScheme.primary
                          : theme.colorScheme.outlineVariant,
                      width: minutes == selected ? 2 : 1,
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    child: Row(
                      children: [
                        Icon(
                          minutes == selected
                              ? Icons.radio_button_checked
                              : Icons.radio_button_unchecked,
                          color: minutes == selected
                              ? theme.colorScheme.primary
                              : theme.colorScheme.outline,
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Günde $minutes dakika',
                                style: theme.textTheme.titleMedium
                                    ?.copyWith(fontWeight: FontWeight.w600),
                              ),
                              Text(
                                AppConstants.dailyMinuteHint(minutes),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: theme.colorScheme.onSurface
                                      .withValues(alpha: 0.65),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
