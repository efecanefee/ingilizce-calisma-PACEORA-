import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/constants.dart';
import '../../../data/database.dart';
import '../../../data/placement.dart';
import '../../../data/providers.dart';
import '../../placement/placement_screen.dart';
import '../widgets/settings_sheet.dart';

/// Profil düzenleme formunu alt sayfada açar.
Future<void> openProfileSheet(BuildContext context, UserProfile user) =>
    openSettingsSheet(context, 'Profili düzenle', ProfileForm(user: user));

/// Ad, seviye ve günlük süre düzenleme formu (alt sayfada açılır).
class ProfileForm extends ConsumerStatefulWidget {
  const ProfileForm({super.key, required this.user});

  final UserProfile user;

  @override
  ConsumerState<ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<ProfileForm> {
  late final _nameController = TextEditingController(text: widget.user.name);
  late DifficultyLevel _level = DifficultyLevel.fromCode(widget.user.level);
  late int _minutes = widget.user.dailyMinutes;
  bool _saving = false;

  /// Seviye testi daha önce çözüldü mü; çözülmediyse seviye kilitli.
  late bool _tested =
      PlacementRecord.read(ref.read(sharedPreferencesProvider)) != null;

  @override
  void initState() {
    super.initState();
    // Klavyeden de Türkçe harf tuşlarından da yazılınca Kaydet güncellensin.
    _nameController.addListener(() => setState(() {}));
  }

  Future<void> _takeTest() async {
    final level = await openPlacementTest(context);
    if (level == null || !mounted) return;
    setState(() {
      _tested = true;
      _level = level;
    });
  }

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
    final navigator = Navigator.of(context);
    final shouldOfferRefresh = _planAffected;
    // Snackbar eylemi sayfa kapandıktan sonra çalışır; o anda bu State'in
    // ref'i ölmüş olur. Notifier önceden alınır.
    final planNotifier = ref.read(weekPlanProvider.notifier);

    try {
      await ref
          .read(profileProvider.notifier)
          .save(name: name, level: _level.code, dailyMinutes: _minutes);
      navigator.pop();
      messenger.showSnackBar(
        SnackBar(
          content: const Text('Profil güncellendi.'),
          action: shouldOfferRefresh
              ? SnackBarAction(
                  label: 'Programı yenile',
                  onPressed: planNotifier.regenerate,
                )
              : null,
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Kaydedilemedi: $e')));
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: _nameController,
          textCapitalization: TextCapitalization.words,
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
                // Seviye testi çözülmeden seviye elle değiştirilemez.
                onSelected: _tested
                    ? (_) => setState(() => _level = level)
                    : null,
              ),
          ],
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: Text(
                _tested
                    ? 'Seviye testi sonucun: '
                          '${PlacementRecord.read(ref.read(sharedPreferencesProvider))?.label}'
                    : 'Seviyeni değiştirmek için önce kısa seviye testini çöz.',
                style: theme.textTheme.bodySmall,
              ),
            ),
            TextButton.icon(
              onPressed: _saving ? null : _takeTest,
              icon: const Icon(Icons.quiz_rounded, size: 18),
              label: Text(_tested ? 'Tekrar çöz' : 'Testi çöz'),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text('Günlük çalışma süresi', style: theme.textTheme.labelLarge),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: [
            for (final minutes in AppConstants.dailyMinuteOptions)
              ChoiceChip(
                label: Text('$minutes dk'),
                selected: minutes == _minutes,
                onSelected: (_) => setState(() => _minutes = minutes),
              ),
          ],
        ),
        const SizedBox(height: 8),
        Text(
          AppConstants.dailyMinuteHint(_minutes),
          style: theme.textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: (!_changed || _saving) ? null : _save,
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}
