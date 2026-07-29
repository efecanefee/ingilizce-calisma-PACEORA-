import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants.dart';
import '../../app/logo.dart';
import '../../data/providers.dart';

/// Üç adımlı onboarding: isim → seviye → günlük süre.
///
/// Son adımda profil kaydedilir ve Gemini'den haftalık plan üretilir.
class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  static const _stepCount = 3;

  final _pageController = PageController();
  final _nameController = TextEditingController();

  int _step = 0;
  DifficultyLevel _level = DifficultyLevel.b1;
  int _dailyMinutes = AppConstants.dailyMinuteOptions[1];
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
    if (_step < _stepCount - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    } else {
      _finish();
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

    return Scaffold(
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
                      onChanged: (l) => setState(() => _level = l),
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
            header!,
            const SizedBox(height: 32),
          ],
          Text(
            title,
            style: theme.textTheme.headlineSmall
                ?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.7)),
          ),
          const SizedBox(height: 28),
          child,
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
      header: const Center(child: PaceoraLockup()),
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
  const _LevelStep({required this.selected, required this.onChanged});

  final DifficultyLevel selected;
  final ValueChanged<DifficultyLevel> onChanged;

  @override
  Widget build(BuildContext context) {
    return _StepScaffold(
      title: 'Seviyen ne durumda?',
      subtitle:
          'Emin değilsen B1 ile başla — uygulama ilerledikçe zorluğu kendisi ayarlıyor.',
      child: Wrap(
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
                      vertical: 18,
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
                        Text(
                          'Günde $minutes dakika',
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
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
