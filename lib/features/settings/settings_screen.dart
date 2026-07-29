import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/constants.dart';
import '../../data/database.dart';
import '../../data/providers.dart';
import '../../data/settings_providers.dart';

/// Profil, Gemini anahtarı, tema ve veri sıfırlama.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          if (profile case AsyncData(value: final user?)) ...[
            const _SectionTitle('Profil'),
            _ProfileSection(user: user),
            const SizedBox(height: 28),
          ],
          const _SectionTitle('Gemini API anahtarı'),
          const _ApiKeySection(),
          const SizedBox(height: 28),
          const _SectionTitle('Görünüm'),
          const _ThemeSection(),
          const SizedBox(height: 28),
          const _SectionTitle('Veriler'),
          const _ResetSection(),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Text(
        text,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _ProfileSection extends ConsumerStatefulWidget {
  const _ProfileSection({required this.user});

  final UserProfile user;

  @override
  ConsumerState<_ProfileSection> createState() => _ProfileSectionState();
}

class _ProfileSectionState extends ConsumerState<_ProfileSection> {
  late final _nameController = TextEditingController(text: widget.user.name);
  late DifficultyLevel _level = DifficultyLevel.fromCode(widget.user.level);
  late int _minutes = widget.user.dailyMinutes;
  bool _saving = false;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  bool get _changed =>
      _nameController.text.trim() != widget.user.name ||
      _level.code != widget.user.level ||
      _minutes != widget.user.dailyMinutes;

  /// Seviye veya süre değiştiyse mevcut hafta programı artık kullanıcıya uygun
  /// değil; kaydettikten sonra yenilemeyi öneriyoruz.
  bool get _planAffected =>
      _level.code != widget.user.level || _minutes != widget.user.dailyMinutes;

  Future<void> _save() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    final shouldOfferRefresh = _planAffected;

    try {
      await ref.read(profileProvider.notifier).save(
            name: name,
            level: _level.code,
            dailyMinutes: _minutes,
          );
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Profil güncellendi.'),
          action: shouldOfferRefresh
              ? SnackBarAction(
                  label: 'Programı yenile',
                  onPressed: () =>
                      ref.read(weekPlanProvider.notifier).regenerate(),
                )
              : null,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _nameController,
              textCapitalization: TextCapitalization.words,
              onChanged: (_) => setState(() {}),
              decoration: const InputDecoration(labelText: 'Adın'),
            ),
            const SizedBox(height: 20),
            Text('Seviye', style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final level in DifficultyLevel.values)
                  ChoiceChip(
                    label: Text(level.label),
                    selected: level == _level,
                    onSelected: (_) => setState(() => _level = level),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            Text('Günlük çalışma süresi', style: theme.textTheme.labelLarge),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              children: [
                for (final minutes in AppConstants.dailyMinuteOptions)
                  ChoiceChip(
                    label: Text('$minutes dk'),
                    selected: minutes == _minutes,
                    onSelected: (_) => setState(() => _minutes = minutes),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: (!_changed || _saving) ? null : _save,
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ApiKeySection extends ConsumerStatefulWidget {
  const _ApiKeySection();

  @override
  ConsumerState<_ApiKeySection> createState() => _ApiKeySectionState();
}

class _ApiKeySectionState extends ConsumerState<_ApiKeySection> {
  late final _controller =
      TextEditingController(text: ref.read(apiKeyProvider));
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    await ref.read(apiKeyProvider.notifier).save(_controller.text);
    if (!mounted) return;
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          _controller.text.trim().isEmpty
              ? 'Kendi anahtarın silindi; uygulamayla gelen anahtar kullanılacak.'
              : 'Anahtar kaydedildi.',
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasCustomKey = ref.watch(apiKeyProvider).isNotEmpty;
    final usable = ref.watch(geminiServiceProvider).hasApiKey;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              hasCustomKey
                  ? 'Kendi anahtarın kullanılıyor.'
                  : usable
                      ? 'Uygulamayla gelen anahtar kullanılıyor. Kendi anahtarını '
                          'girersen kota senin hesabından düşer.'
                      : 'Tanımlı anahtar yok. Ders üretimi için bir anahtar gerekli; '
                          'haftalık program anahtarsız da hazır listeden gelir.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              obscureText: _obscure,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: 'Gemini API anahtarı',
                hintText: 'AIza…',
                suffixIcon: IconButton(
                  tooltip: _obscure ? 'Göster' : 'Gizle',
                  icon: Icon(
                    _obscure ? Icons.visibility : Icons.visibility_off,
                  ),
                  onPressed: () => setState(() => _obscure = !_obscure),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Anahtarı aistudio.google.com/apikey adresinden ücretsiz alabilirsin. '
              'Anahtar yalnızca bu cihazda saklanır.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: 16),
            // Butonlar tema gereği tam genişlik ister (Size.fromHeight), bu
            // yüzden satırda esnek olmayan çocuk olarak bırakılamaz.
            Row(
              children: [
                if (hasCustomKey) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        _controller.clear();
                        _save();
                      },
                      child: const Text('Sil'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  flex: 2,
                  child: FilledButton(
                    onPressed: _save,
                    child: const Text('Kaydet'),
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

class _ThemeSection extends ConsumerWidget {
  const _ThemeSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: SegmentedButton<ThemeMode>(
          segments: const [
            ButtonSegment(value: ThemeMode.system, label: Text('Sistem')),
            ButtonSegment(value: ThemeMode.light, label: Text('Açık')),
            ButtonSegment(value: ThemeMode.dark, label: Text('Koyu')),
          ],
          selected: {mode},
          onSelectionChanged: (selection) =>
              ref.read(themeModeProvider.notifier).save(selection.first),
        ),
      ),
    );
  }
}

class _ResetSection extends ConsumerStatefulWidget {
  const _ResetSection();

  @override
  ConsumerState<_ResetSection> createState() => _ResetSectionState();
}

class _ResetSectionState extends ConsumerState<_ResetSection> {
  bool _busy = false;

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tüm veriler silinsin mi?'),
        content: const Text(
          'Profilin, haftalık programın, derslerin, serin ve hata defterin '
          'kalıcı olarak silinir. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Sil'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    final router = GoRouter.of(context);
    try {
      await ref.read(repositoryProvider).resetAll();
      await ref
          .read(sharedPreferencesProvider)
          .setBool(AppConstants.prefOnboardingDone, false);

      // Bellekteki durum da sıfırlanmalı; aksi halde silinen profil ekranda kalır.
      ref.invalidate(profileProvider);
      ref.invalidate(weekPlanProvider);
      ref.invalidate(todayLessonProvider);

      router.go('/onboarding');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Her şeyi sıfırlar ve kurulumu baştan başlatır.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton(
              onPressed: _busy ? null : _reset,
              style: OutlinedButton.styleFrom(
                foregroundColor: theme.colorScheme.error,
              ),
              child: const Text('Verileri sıfırla'),
            ),
          ],
        ),
      ),
    );
  }
}
