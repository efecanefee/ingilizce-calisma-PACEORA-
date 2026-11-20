import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../app/constants.dart';
import '../../app/error_reporting.dart';
import '../../app/logo.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/backup.dart';
import '../../data/database.dart';
import '../../data/feedback.dart';
import '../../data/gemini_service.dart';
import '../../data/placement.dart';
import '../../data/profile_style.dart';
import '../../data/providers.dart';
import '../../data/rewards.dart';
import '../../data/settings_providers.dart';
import '../placement/placement_screen.dart';

/// Ayarlar: profil kartı ve gruplanmış tercihler.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).value;

    var index = 0;
    Widget item(Widget child) => child.entrance(index++);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          if (user != null) ...[
            item(_ProfileHeader(user: user)),
            const SizedBox(height: 24),
            item(_StudyGroup(user: user)),
            const SizedBox(height: 20),
          ],
          item(const _AppearanceGroup()),
          const SizedBox(height: 20),
          item(const _AiGroup()),
          const SizedBox(height: 20),
          item(const _DataGroup()),
          const SizedBox(height: 20),
          item(const _AboutGroup()),
        ],
      ),
    );
  }
}

// --- Ortak yapı taşları ------------------------------------------------------

/// Başlıklı, kart içinde gruplanmış ayar satırları.
class _SettingsGroup extends StatelessWidget {
  const _SettingsGroup({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 8),
          child: Text(
            // Başlıklar doğrudan büyük yazıldı: toUpperCase Türkçeye duyarsız
            // ("Verilerim" → "VERILERIM").
            title,
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.1,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Card(
          clipBehavior: Clip.antiAlias,
          child: Column(
            children: [
              for (final (i, child) in children.indexed) ...[
                if (i > 0) const Divider(height: 1, indent: 64),
                child,
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// Renkli simge kutulu ayar satırı.
class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.color,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.danger = false,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tile = ListTile(
      onTap: onTap == null
          ? null
          : () {
              Haptics.tap();
              onTap!();
            },
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.16),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: danger ? theme.colorScheme.error : null,
        ),
      ),
      subtitle: subtitle == null ? null : Text(subtitle!),
      trailing:
          trailing ??
          (onTap == null
              ? null
              : Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.outline,
                )),
    );
    // Anahtar (Switch) gibi bir kontrol varsa başlıkla tek düğüm olsun;
    // ekran okuyucu "Titreşim, açık" diye okur.
    return trailing == null ? tile : MergeSemantics(child: tile);
  }
}

/// Gemini API anahtarı formunu alt sayfada açar (ana ekrandaki karttan da
/// kullanılır).
Future<void> showApiKeySheet(BuildContext context) =>
    _openSheet(context, 'Gemini API anahtarı', const _ApiKeyForm());

Future<void> _openSheet(BuildContext context, String title, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheetContext) => Padding(
      // Klavye açılınca sayfa yukarı kalksın.
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
      ),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                style: Theme.of(
                  sheetContext,
                ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    ),
  );
}

// --- Profil kartı ------------------------------------------------------------

class _ProfileHeader extends ConsumerWidget {
  const _ProfileHeader({required this.user});

  final UserProfile user;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final game = ref.watch(gameProvider).value;
    final cards = ref.watch(flashcardSummaryProvider).value;
    final first = user.name.isEmpty ? '?' : user.name.characters.first;
    // Türkçe büyük harf: i → İ, ı → I (toUpperCase "i"yi "I" yapar).
    final initial = switch (first) {
      'i' => 'İ',
      'ı' => 'I',
      _ => first.toUpperCase(),
    };

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(26),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.graphite900,
            AppColors.graphite700,
            context.pace.accentDark,
          ],
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                    width: 64,
                    height: 64,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(
                        colors: [context.pace.accent, context.pace.accentDim],
                      ),
                    ),
                    child: Text(
                      initial,
                      style: theme.textTheme.headlineMedium?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: AppColors.graphite900,
                      ),
                    ),
                  )
                  .animate(onPlay: Motion.loop(reverse: true))
                  .boxShadow(
                    begin: const BoxShadow(
                      color: Colors.transparent,
                      blurRadius: 0,
                    ),
                    end: BoxShadow(
                      color: context.pace.accent.withValues(alpha: 0.5),
                      blurRadius: 18,
                    ),
                    borderRadius: BorderRadius.circular(32),
                    duration: 1400.ms,
                  ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.name,
                      style: theme.textTheme.titleLarge?.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${DifficultyLevel.fromCode(user.level).code} · '
                      '${game == null ? '' : 'Lv ${game.level.level} ${game.level.title}'}',
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: context.pace.accent,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton.filledTonal(
                tooltip: 'Profili düzenle',
                onPressed: () => _openSheet(
                  context,
                  'Profili düzenle',
                  _ProfileForm(user: user),
                ),
                icon: const Icon(Icons.edit_rounded),
              ),
            ],
          ),
          const SizedBox(height: 18),
          Row(
            children: [
              _HeaderStat(
                value: ref.watch(streakDisplayProvider).streak,
                label: 'gün seri',
              ),
              _HeaderStat(value: game?.stats.lessons ?? 0, label: 'ders'),
              _HeaderStat(value: cards?.total ?? 0, label: 'kart'),
              _HeaderStat(value: game?.level.xp ?? 0, label: 'XP'),
            ],
          ),
        ],
      ),
    );
  }
}

class _HeaderStat extends StatelessWidget {
  const _HeaderStat({required this.value, required this.label});

  final int value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          CountUpText(
            value: value,
            style: theme.textTheme.titleLarge?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.w800,
            ),
          ),
          Text(
            label,
            style: theme.textTheme.labelSmall?.copyWith(
              color: Colors.white.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

/// Ad, seviye ve günlük süre düzenleme formu (alt sayfada açılır).
class _ProfileForm extends ConsumerStatefulWidget {
  const _ProfileForm({required this.user});

  final UserProfile user;

  @override
  ConsumerState<_ProfileForm> createState() => _ProfileFormState();
}

class _ProfileFormState extends ConsumerState<_ProfileForm> {
  late final _nameController = TextEditingController(text: widget.user.name);
  late DifficultyLevel _level = DifficultyLevel.fromCode(widget.user.level);
  late int _minutes = widget.user.dailyMinutes;
  bool _saving = false;

  /// Seviye testi daha önce çözüldü mü; çözülmediyse seviye kilitli.
  late bool _tested =
      PlacementRecord.read(ref.read(sharedPreferencesProvider)) != null;

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
        // Seçenekler çoğaldı; form uzamasın diye tek satırda kaydırılır.
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final minutes in AppConstants.dailyMinuteOptions)
                Padding(
                  padding: const EdgeInsets.only(right: 10),
                  child: ChoiceChip(
                    label: Text('$minutes dk'),
                    selected: minutes == _minutes,
                    onSelected: (_) => setState(() => _minutes = minutes),
                  ),
                ),
            ],
          ),
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

// --- Çalışma -----------------------------------------------------------------

class _StudyGroup extends ConsumerWidget {
  const _StudyGroup({required this.user});

  final UserProfile user;

  Future<void> _toggleReminder(
    BuildContext context,
    WidgetRef ref,
    bool value,
  ) async {
    final messenger = ScaffoldMessenger.of(context);
    final ok = await ref.read(reminderProvider.notifier).setEnabled(value);
    if (!ok) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text(
            'Bildirim izni verilmedi. Telefon ayarlarından Paceora için '
            'bildirimlere izin verebilirsin.',
          ),
        ),
      );
    }
  }

  Future<void> _pickTime(BuildContext context, WidgetRef ref) async {
    final current = ref.read(reminderProvider).time;
    final picked = await showTimePicker(
      context: context,
      initialTime: current,
      helpText: 'Hatırlatma saati',
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      await ref.read(reminderProvider.notifier).setTime(picked);
    }
  }

  Future<void> _regenerate(BuildContext context, WidgetRef ref) async {
    final messenger = ScaffoldMessenger.of(context);
    messenger.showSnackBar(
      const SnackBar(content: Text('Haftalık program hazırlanıyor…')),
    );
    final result = await ref.read(weekPlanProvider.notifier).regenerate();
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            result.offline
                ? 'Gemini\'ye ulaşılamadı; hazır program yüklendi.'
                : 'Haftalık programın yenilendi.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final reminder = ref.watch(reminderProvider);
    final time =
        '${reminder.time.hour.toString().padLeft(2, '0')}:${reminder.time.minute.toString().padLeft(2, '0')}';

    void editProfile() =>
        _openSheet(context, 'Profili düzenle', _ProfileForm(user: user));

    return _SettingsGroup(
      title: 'ÇALIŞMA',
      children: [
        _SettingsTile(
          icon: Icons.signal_cellular_alt_rounded,
          color: AppColors.success,
          title: 'Seviye',
          subtitle: DifficultyLevel.fromCode(user.level).label,
          onTap: editProfile,
        ),
        _SettingsTile(
          icon: Icons.timer_rounded,
          color: AppColors.blue,
          title: 'Günlük süre',
          subtitle: 'Günde ${user.dailyMinutes} dakika',
          onTap: editProfile,
        ),
        _SettingsTile(
          icon: Icons.notifications_active_rounded,
          color: AppColors.warning,
          title: 'Her gün hatırlat',
          subtitle: reminder.enabled
              ? 'Her gün $time\'da bildirim'
              : 'Serini kaybetmemen için bildirim gönderir',
          trailing: Switch(
            value: reminder.enabled,
            onChanged: (v) => _toggleReminder(context, ref, v),
          ),
        ),
        AnimatedSize(
          duration: Motion.medium,
          curve: Motion.curve,
          child: reminder.enabled
              ? _SettingsTile(
                  icon: Icons.schedule_rounded,
                  color: AppColors.warning,
                  title: 'Hatırlatma saati',
                  trailing: Text(
                    time,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                  onTap: () => _pickTime(context, ref),
                )
              : const SizedBox(width: double.infinity),
        ),
        _SettingsTile(
          icon: Icons.autorenew_rounded,
          color: AppColors.violet,
          title: 'Haftalık programı yenile',
          subtitle: 'Seviyene göre yeni konular üretir; ilerlemen korunur',
          onTap: () => _regenerate(context, ref),
        ),
      ],
    );
  }
}

// --- Görünüm ve his ----------------------------------------------------------

/// Vurgu rengi seçici: her seçenek için renk yuvarlağı, seçili olan tikli.
class _AccentPicker extends ConsumerWidget {
  const _AccentPicker();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selected = ref.watch(accentProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final accent in AppAccent.values)
          Semantics(
            button: true,
            selected: accent == selected,
            label: '${accent.label} vurgu rengi',
            child: Tooltip(
              message: accent.label,
              child: GestureDetector(
                onTap: () {
                  Haptics.tap();
                  ref.read(accentProvider.notifier).save(accent);
                },
                child: AnimatedContainer(
                  duration: Motion.fast,
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: isDark
                          ? [accent.spark, accent.dim]
                          : [accent.dim, accent.dark],
                    ),
                    border: Border.all(
                      color: accent == selected
                          ? Theme.of(context).colorScheme.onSurface
                          : Colors.transparent,
                      width: 2.5,
                    ),
                  ),
                  child: accent == selected
                      ? Icon(
                          Icons.check_rounded,
                          size: 20,
                          color: isDark ? AppColors.graphite900 : Colors.white,
                        )
                      : null,
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _AppearanceGroup extends ConsumerWidget {
  const _AppearanceGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final haptics = ref.watch(hapticsProvider);

    return _SettingsGroup(
      title: 'GÖRÜNÜM VE HİS',
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: context.pace.accentDim.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.palette_rounded,
                      size: 20,
                      color: context.pace.accentDim,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Tema',
                    style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ThemeMode>(
                  segments: const [
                    ButtonSegment(
                      value: ThemeMode.system,
                      label: Text('Sistem'),
                      icon: Icon(Icons.brightness_auto_rounded),
                    ),
                    ButtonSegment(
                      value: ThemeMode.light,
                      label: Text('Açık'),
                      icon: Icon(Icons.light_mode_rounded),
                    ),
                    ButtonSegment(
                      value: ThemeMode.dark,
                      label: Text('Koyu'),
                      icon: Icon(Icons.dark_mode_rounded),
                    ),
                  ],
                  selected: {mode},
                  showSelectedIcon: false,
                  onSelectionChanged: (selection) {
                    Haptics.tap();
                    ref.read(themeModeProvider.notifier).save(selection.first);
                  },
                ),
              ),
              const SizedBox(height: 16),
              Text(
                'Vurgu rengi',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              const _AccentPicker(),
            ],
          ),
        ),
        _SettingsTile(
          icon: Icons.vibration_rounded,
          color: AppColors.pink,
          title: 'Titreşim',
          subtitle: 'Dokunuşlarda hafif titreşim',
          trailing: Switch(
            value: haptics,
            onChanged: (v) => ref.read(hapticsProvider.notifier).set(v),
          ),
        ),
      ],
    );
  }
}

// --- Yapay zeka --------------------------------------------------------------

class _AiGroup extends ConsumerWidget {
  const _AiGroup();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasCustomKey = ref.watch(apiKeyProvider).isNotEmpty;
    final usable = ref.watch(geminiServiceProvider).hasApiKey;

    return _SettingsGroup(
      title: 'YAPAY ZEKA',
      children: [
        _SettingsTile(
          icon: Icons.auto_awesome_rounded,
          color: AppColors.gemini,
          title: 'Gemini API anahtarı',
          subtitle: hasCustomKey
              ? 'Kendi anahtarın kullanılıyor'
              : usable
              ? 'Uygulamayla gelen anahtar kullanılıyor'
              : 'Anahtar yok — dersler üretilemez',
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                usable ? Icons.check_circle_rounded : Icons.error_rounded,
                color: usable ? AppColors.success : AppColors.warning,
                size: 20,
              ),
              const SizedBox(width: 4),
              Icon(
                Icons.chevron_right_rounded,
                color: Theme.of(context).colorScheme.outline,
              ),
            ],
          ),
          onTap: () => showApiKeySheet(context),
        ),
        _SettingsTile(
          icon: Icons.network_check_rounded,
          color: AppColors.blue,
          title: 'Bağlantıyı test et',
          subtitle: 'Anahtar, model ve yanıt süresini kontrol eder',
          onTap: () =>
              _openSheet(context, 'Bağlantı testi', const _ConnectionTest()),
        ),
      ],
    );
  }
}

/// Gemini bağlantısını uçtan uca dener ve sonucu Türkçe gösterir.
class _ConnectionTest extends ConsumerStatefulWidget {
  const _ConnectionTest();

  @override
  ConsumerState<_ConnectionTest> createState() => _ConnectionTestState();
}

class _ConnectionTestState extends ConsumerState<_ConnectionTest> {
  late final Future<GeminiConnectionReport> _report = ref
      .read(geminiServiceProvider)
      .testConnection();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return FutureBuilder<GeminiConnectionReport>(
      future: _report,
      builder: (context, snapshot) {
        final report = snapshot.data;
        if (report == null) {
          return const Padding(
            padding: EdgeInsets.symmetric(vertical: 24),
            child: Column(
              children: [
                CircularProgressIndicator(),
                SizedBox(height: 16),
                Text('Gemini\'ye bağlanılıyor…'),
              ],
            ),
          );
        }

        final seconds = report.elapsed == null
            ? null
            : (report.elapsed!.inMilliseconds / 1000).toStringAsFixed(1);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Icon(
                  report.ok ? Icons.check_circle_rounded : Icons.error_rounded,
                  color: report.ok ? AppColors.success : AppColors.error,
                  size: 32,
                ).animate().scale(curve: Curves.elasticOut, duration: 600.ms),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    report.ok ? 'Bağlantı çalışıyor' : 'Bağlantı kurulamadı',
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (report.model != null)
              _ReportRow(label: 'Kullanılan model', value: report.model!),
            if (seconds != null)
              _ReportRow(label: 'Yanıt süresi', value: '$seconds sn'),
            if (report.availableModels.isNotEmpty)
              _ReportRow(
                label: report.listedFromApi
                    ? 'Erişilebilir modeller'
                    : 'Denenen modeller (liste alınamadı)',
                value: report.availableModels.take(5).join('\n'),
              ),
            if (report.error != null)
              _ReportRow(label: 'Hata', value: report.error!, isError: true),
          ],
        );
      },
    );
  }
}

class _ReportRow extends StatelessWidget {
  const _ReportRow({
    required this.label,
    required this.value,
    this.isError = false,
  });

  final String label;
  final String value;
  final bool isError;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: theme.textTheme.labelMedium),
          const SizedBox(height: 2),
          SelectableText(
            value,
            style: theme.textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w600,
              color: isError ? theme.colorScheme.error : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _ApiKeyForm extends ConsumerStatefulWidget {
  const _ApiKeyForm();

  @override
  ConsumerState<_ApiKeyForm> createState() => _ApiKeyFormState();
}

class _ApiKeyFormState extends ConsumerState<_ApiKeyForm> {
  late final _controller = TextEditingController(
    text: ref.read(apiKeyProvider),
  );
  bool _obscure = true;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    await ref.read(apiKeyProvider.notifier).save(_controller.text);
    if (!mounted) return;
    navigator.pop();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Dersler, hikayeler ve haftalık rapor Gemini ile üretilir. Kendi '
          'anahtarını girersen kota senin hesabından düşer.',
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
              icon: Icon(_obscure ? Icons.visibility : Icons.visibility_off),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Anahtarı aistudio.google.com/apikey adresinden ücretsiz alabilirsin. '
          'Anahtar bu cihazın güvenli kasasında şifreli saklanır.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
        const SizedBox(height: 20),
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
    );
  }
}

// --- Verilerim ---------------------------------------------------------------

class _DataGroup extends ConsumerStatefulWidget {
  const _DataGroup();

  @override
  ConsumerState<_DataGroup> createState() => _DataGroupState();
}

class _DataGroupState extends ConsumerState<_DataGroup> {
  bool _busy = false;

  Future<void> _reset() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.warning_amber_rounded),
        title: const Text('Tüm veriler silinsin mi?'),
        content: const Text(
          'Profilin, programın, derslerin, kartların, rozetlerin, serin ve hata '
          'defterin kalıcı olarak silinir. Bu işlem geri alınamaz.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(dialogContext).colorScheme.error,
              minimumSize: const Size(0, 44),
            ),
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
      final prefs = ref.read(sharedPreferencesProvider);
      await prefs.setBool(AppConstants.prefOnboardingDone, false);
      // Ödül ve tekrar sayaçları da sıfırlanır; yoksa yeni profil eski
      // XP'yle başlardı.
      for (final key in prefs.getKeys().toList()) {
        if (key.startsWith('cards_reviewed_') ||
            key.startsWith('plan_offline_') ||
            // Kelime Rallisi XP'si ve rekorları, profil görünümü.
            key.startsWith('match_') ||
            key.startsWith('speech_') ||
            key.startsWith('roleplay_') ||
            key.startsWith('streak_') ||
            key.startsWith('profile_') ||
            key.startsWith('wardrobe_') ||
            key == PlacementRecord.levelKey ||
            key == levelUpsKey ||
            key == 'seen_player_level' ||
            key == 'seen_badges') {
          await prefs.remove(key);
        }
      }

      // Bellekteki durum da sıfırlanmalı; aksi halde silinen profil ekranda kalır.
      _invalidateData();

      router.go('/onboarding');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Veritabanı ya da ayarlar dışarıdan değiştiğinde bellekteki durumu
  /// tazeler (sıfırlama, yedekten geri yükleme).
  void _invalidateData() {
    ref.invalidate(profileProvider);
    ref.invalidate(wardrobeProvider);
    ref.invalidate(weekPlanProvider);
    ref.invalidate(todayLessonProvider);
    ref.invalidate(flashcardSummaryProvider);
    ref.invalidate(progressProvider);
    ref.invalidate(weeklyReportsProvider);
    ref.invalidate(gameProvider);
    ref.invalidate(profileStyleProvider);
    ref.invalidate(freezeProvider);
  }

  /// Tüm ilerlemeyi JSON dosyası olarak paylaşır (Drive, Dosyalar, e-posta…).
  Future<void> _export() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final json = await Backup.export(
        ref.read(databaseProvider),
        ref.read(sharedPreferencesProvider),
      );
      final name = Backup.fileName();
      await SharePlus.instance.share(
        ShareParams(
          files: [
            XFile.fromData(
              utf8.encode(json),
              mimeType: 'application/json',
              name: name,
            ),
          ],
          fileNameOverrides: [name],
          subject: 'Paceora yedeği',
        ),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Yedek alınamadı: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  /// Seçilen yedek dosyasını geri yükler; mevcut veriler yerini alır.
  Future<void> _restore() async {
    final messenger = ScaffoldMessenger.of(context);
    final router = GoRouter.of(context);
    final picked = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked == null || !mounted) return;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        icon: const Icon(Icons.restore_rounded),
        title: const Text('Yedek geri yüklensin mi?'),
        content: Text(
          '"${picked.name}" yüklenecek. Bu cihazdaki mevcut ilerlemen yedekteki '
          'verilerle değiştirilir.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Geri yükle'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await Backup.restore(
        await picked.xFile.readAsString(),
        ref.read(databaseProvider),
        ref.read(sharedPreferencesProvider),
      );
      _invalidateData();
      ref.invalidate(themeModeProvider);
      ref.invalidate(accentProvider);
      ref.invalidate(hapticsProvider);
      ref.invalidate(reminderProvider);
      messenger.showSnackBar(
        const SnackBar(content: Text('Yedek geri yüklendi.')),
      );
      router.go('/');
    } on FormatException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Geri yüklenemedi: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return _SettingsGroup(
      title: 'VERİLERİM',
      children: [
        _SettingsTile(
          icon: Icons.edit_note_rounded,
          color: AppColors.error,
          title: 'Hata defterim',
          subtitle: 'Pekişmeyen ifadeler',
          onTap: () => context.push('/mistakes'),
        ),
        _SettingsTile(
          icon: Icons.assessment_rounded,
          color: AppColors.mint,
          title: 'Haftalık rapor',
          subtitle: 'Değerlendirme ve seviye önerisi',
          onTap: () => context.push('/review'),
        ),
        _SettingsTile(
          icon: Icons.upload_file_rounded,
          color: AppColors.blue,
          title: 'Verileri dışa aktar',
          subtitle: 'Tüm ilerlemeni bir dosyaya yedekle',
          onTap: _busy ? null : _export,
        ),
        _SettingsTile(
          icon: Icons.restore_rounded,
          color: AppColors.violet,
          title: 'Yedekten geri yükle',
          subtitle: 'Başka cihazdan aldığın yedeği yükle',
          onTap: _busy ? null : _restore,
        ),
        _SettingsTile(
          icon: Icons.delete_forever_rounded,
          color: Theme.of(context).colorScheme.error,
          title: 'Verileri sıfırla',
          subtitle: 'Her şeyi siler ve kurulumu baştan başlatır',
          danger: true,
          onTap: _busy ? null : _reset,
        ),
      ],
    );
  }
}

// --- Hakkında ----------------------------------------------------------------

class _AboutGroup extends StatelessWidget {
  const _AboutGroup();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        _SettingsGroup(
          title: 'HAKKINDA',
          children: [
            const _SettingsTile(
              icon: Icons.info_rounded,
              color: AppColors.blue,
              title: 'Sürüm',
              trailing: Text(AppConstants.appVersion),
            ),
            _SettingsTile(
              icon: Icons.lock_rounded,
              color: AppColors.success,
              title: 'Gizlilik',
              subtitle:
                  'İlerlemen cihazda; dersler için konu ve cevaplar '
                  'Google Gemini\'ye gider, adın gitmez',
              onTap: () =>
                  _openSheet(context, 'Gizlilik', const _PrivacyDetails()),
            ),
            const _FeedbackTile(),
            const _ErrorLogTile(),
            _SettingsTile(
              icon: Icons.description_rounded,
              color: AppColors.graphite400,
              title: 'Açık kaynak lisansları',
              onTap: () => showLicensePage(
                context: context,
                applicationName: AppConstants.appName,
                applicationVersion: AppConstants.appVersion,
                applicationIcon: const Padding(
                  padding: EdgeInsets.all(12),
                  child: PaceoraMark(size: 56),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 28),
        const PaceoraMark(size: 44)
            .animate(onPlay: Motion.loop(reverse: true))
            .moveY(
              begin: -3,
              end: 3,
              duration: 1600.ms,
              curve: Curves.easeInOut,
            ),
        const SizedBox(height: 10),
        Text(
          'Learn English. Go Further.',
          style: theme.textTheme.labelLarge?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
          ),
        ),
      ],
    );
  }
}

/// Hangi verinin nerede durduğu ve Gemini'ye ne gittiği.
class _PrivacyDetails extends StatelessWidget {
  const _PrivacyDetails();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget section(IconData icon, String title, String body) => Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(body, style: theme.textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        section(
          Icons.phone_android_rounded,
          'Cihazında kalanlar',
          'Profilin, ilerlemen, serin, hata defterin, kartların ve '
              'ayarların yalnızca bu telefonda saklanır. Hesap ya da Paceora '
              'sunucusu yoktur.',
        ),
        section(
          Icons.auto_awesome_rounded,
          'Google Gemini\'ye gidenler',
          'Program, ders, hikaye, rapor ve sohbet üretmek için seviyen, '
              'günlük süren, günün konusu, tekrar edilecek ifadeler ve sohbet '
              'mesajların Google\'ın Gemini API\'sine gönderilir. Adın '
              'gönderilmez. Ücretsiz Gemini anahtarlarında Google bu içerikleri '
              'ürünlerini geliştirmek için kullanabilir.',
        ),
        section(
          Icons.mic_rounded,
          'Mikrofon',
          'Konuşma pratiğinde sesin telefonun konuşma tanıma servisiyle '
              'metne çevrilir; ses kaydı Paceora tarafından saklanmaz.',
        ),
        section(
          Icons.key_rounded,
          'API anahtarın',
          'Kendi anahtarını girersen telefonun güvenli kasasında şifreli '
              'saklanır ve yedeklere girmez.',
        ),
        section(
          Icons.delete_outline_rounded,
          'Silme',
          'Ayarlar > Verileri sıfırla her şeyi bu cihazdan siler.',
        ),
      ],
    );
  }
}

/// E-posta ile geri bildirim: sürüm ve platform hazır gelir, hata kaydı
/// yalnızca kullanıcı isterse eklenir.
class _FeedbackTile extends ConsumerWidget {
  const _FeedbackTile();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return _SettingsTile(
      icon: Icons.mail_rounded,
      color: AppColors.violet,
      title: 'Geri bildirim gönder',
      subtitle: 'Öneri, hata ya da soru: e-posta ile yaz',
      onTap: () => _send(context, ref),
    );
  }

  Future<void> _send(BuildContext context, WidgetRef ref) async {
    final log = ref.read(errorLogProvider);
    final messenger = ScaffoldMessenger.of(context);
    var attachLog = false;
    if (log.entries.isNotEmpty) {
      final choice = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => StatefulBuilder(
          builder: (dialogContext, setState) => AlertDialog(
            title: const Text('Geri bildirim gönder'),
            content: CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: attachLog,
              onChanged: (v) => setState(() => attachLog = v ?? false),
              title: Text('Hata kaydını ekle (${log.entries.length})'),
              subtitle: const Text(
                'Sorunu bulmamıza yardım eder; kişisel bilgi içermez.',
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(),
                child: const Text('Vazgeç'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
                onPressed: () => Navigator.of(dialogContext).pop(true),
                child: const Text('E-postayı aç'),
              ),
            ],
          ),
        ),
      );
      if (choice != true) return;
    }
    final uri = feedbackMailUri(
      platform: defaultTargetPlatform.name,
      errorReport: attachLog
          ? log.report(appVersion: AppConstants.appVersion)
          : null,
    );
    final opened = await ref.read(mailLauncherProvider)(uri);
    if (opened) return;
    // E-posta uygulaması yoksa adres panoya kopyalanır.
    await Clipboard.setData(
      const ClipboardData(text: AppConstants.supportEmail),
    );
    messenger.showSnackBar(
      const SnackBar(
        content: Text(
          'E-posta uygulaması açılamadı. Adres kopyalandı: '
          '${AppConstants.supportEmail}',
        ),
      ),
    );
  }
}

/// Cihazdaki hata kaydı: kaç hata olduğu, paylaşma ve temizleme.
class _ErrorLogTile extends ConsumerStatefulWidget {
  const _ErrorLogTile();

  @override
  ConsumerState<_ErrorLogTile> createState() => _ErrorLogTileState();
}

class _ErrorLogTileState extends ConsumerState<_ErrorLogTile> {
  @override
  Widget build(BuildContext context) {
    final log = ref.watch(errorLogProvider);
    final count = log.entries.length;
    return _SettingsTile(
      icon: Icons.bug_report_rounded,
      color: AppColors.graphite400,
      title: 'Hata kaydı',
      subtitle: count == 0
          ? 'Kayıtlı hata yok'
          : '$count hata kaydı · yalnızca bu cihazda',
      onTap: count == 0 ? null : () => _open(log),
    );
  }

  Future<void> _open(ErrorLog log) async {
    final action = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hata kaydı'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView(
            shrinkWrap: true,
            children: [
              const Text(
                'Bu kayıt yalnızca bu cihazda tutulur ve kendiliğinden hiçbir '
                'yere gönderilmez. Bir sorunu bildirmek istersen paylaşabilirsin.',
              ),
              const SizedBox(height: 12),
              for (final e in log.entries.take(5))
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    e.message,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(dialogContext).textTheme.bodySmall,
                  ),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop('clear'),
            child: const Text('Temizle'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(minimumSize: const Size(0, 44)),
            onPressed: () => Navigator.of(dialogContext).pop('share'),
            child: const Text('Paylaş'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    switch (action) {
      case 'share':
        await SharePlus.instance.share(
          ShareParams(
            text: log.report(appVersion: AppConstants.appVersion),
            subject: 'Paceora hata kaydı',
          ),
        );
      case 'clear':
        await log.clear();
        setState(() {});
    }
  }
}
