import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/constants.dart';
import '../../app/motion.dart';
import '../../data/providers.dart';
import '../../data/settings_providers.dart';
import 'groups/about_group.dart';
import 'groups/advanced_group.dart';
import 'groups/appearance_group.dart';
import 'groups/data_group.dart';
import 'groups/notifications_group.dart';
import 'groups/study_group.dart';
import 'profile/profile_header.dart';
import 'settings_section.dart';
import 'widgets/settings_group.dart';

// Ana ekran ve ders ekranı anahtar formunu buradan açar.
export 'sheets/api_key_sheet.dart' show showApiKeySheet;

/// Ayarlar: üstte Pace'li profil kartı, altında kategori kartları.
///
/// Her kart bir bölümün kısa özetini gösterir (ör. "15 dk · B1"); dokununca
/// bölümün kendi sayfası ([SettingsSectionPage]) açılır. Böylece uzun ve
/// kalabalık tek liste yerine kısa bir menü görünür.
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
            item(ProfileHeader(user: user)),
            const SizedBox(height: 20),
          ],
          item(
            _CardRow(
              left: user == null ? null : SettingsSection.study,
              right: SettingsSection.appearance,
            ),
          ),
          const SizedBox(height: 12),
          item(
            const _CardRow(
              left: SettingsSection.notifications,
              right: SettingsSection.data,
            ),
          ),
          const SizedBox(height: 12),
          item(
            Card(
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: const [
                  _SectionRow(section: SettingsSection.advanced),
                  Divider(height: 1, indent: 64),
                  _SectionRow(section: SettingsSection.about),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Bir bölümün sayfasını açar.
void openSettingsSection(BuildContext context, SettingsSection section) {
  Haptics.tap();
  Navigator.of(context).push(
    MaterialPageRoute<void>(
      builder: (_) => SettingsSectionPage(section: section),
    ),
  );
}

/// Bölümün kısa özeti: kartta başlığın altında görünür.
String _summary(WidgetRef ref, SettingsSection section) {
  switch (section) {
    case SettingsSection.study:
      final user = ref.watch(profileProvider).value;
      return user == null ? '' : '${user.dailyMinutes} dk · ${user.level}';
    case SettingsSection.appearance:
      return switch (ref.watch(themeModeProvider)) {
        ThemeMode.dark => 'Koyu tema',
        ThemeMode.light => 'Açık tema',
        ThemeMode.system => 'Sistem teması',
      };
    case SettingsSection.notifications:
      final reminder = ref.watch(reminderProvider);
      if (!reminder.enabled) return 'Hatırlatma kapalı';
      final t = reminder.time;
      return 'Her gün ${t.hour.toString().padLeft(2, '0')}:'
          '${t.minute.toString().padLeft(2, '0')}';
    case SettingsSection.data:
      return 'Yedekle, geri yükle';
    case SettingsSection.advanced:
      return 'Kendi anahtarın, bağlantı testi, hata kaydı';
    case SettingsSection.about:
      return 'Sürüm ${AppConstants.appVersion} · gizlilik, geri bildirim';
  }
}

/// İki kategori kartı yan yana, eşit yükseklikte.
class _CardRow extends StatelessWidget {
  const _CardRow({required this.left, required this.right});

  final SettingsSection? left;
  final SettingsSection right;

  @override
  Widget build(BuildContext context) {
    final left = this.left;
    if (left == null) return _SectionCard(section: right);
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(child: _SectionCard(section: left)),
          const SizedBox(width: 12),
          Expanded(child: _SectionCard(section: right)),
        ],
      ),
    );
  }
}

/// Kategori kartı: nötr simge, bölüm adı ve kısa özet.
class _SectionCard extends ConsumerWidget {
  const _SectionCard({required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final summary = _summary(ref, section);
    return Card(
      key: ValueKey('settings-${section.name}'),
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => openSettingsSection(context, section),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _IconBox(icon: section.icon),
              const SizedBox(height: 14),
              Text(
                section.label,
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                summary,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seyrek kullanılan bölümler için tam genişlikte satır.
class _SectionRow extends ConsumerWidget {
  const _SectionRow({required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    return ListTile(
      key: ValueKey('settings-${section.name}'),
      onTap: () => openSettingsSection(context, section),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      leading: _IconBox(icon: section.icon),
      title: Text(
        section.label,
        style: theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
      ),
      subtitle: Text(_summary(ref, section)),
      trailing: Icon(
        Icons.chevron_right_rounded,
        color: theme.colorScheme.outline,
      ),
    );
  }
}

class _IconBox extends StatelessWidget {
  const _IconBox({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 36,
      height: 36,
      decoration: BoxDecoration(
        color: SettingsSection.iconTint(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(icon, size: 20, color: SettingsSection.iconColor(context)),
    );
  }
}

/// Tek bir bölümün sayfası.
class SettingsSectionPage extends ConsumerWidget {
  const SettingsSectionPage({super.key, required this.section});

  final SettingsSection section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).value;
    final Widget content = switch (section) {
      SettingsSection.study =>
        user == null ? const SizedBox.shrink() : StudyGroup(user: user),
      SettingsSection.appearance => const AppearanceGroup(),
      SettingsSection.notifications => const NotificationsGroup(),
      SettingsSection.data => const DataGroup(),
      SettingsSection.advanced => const AdvancedGroup(),
      SettingsSection.about => const AboutGroup(),
    };
    return Scaffold(
      appBar: AppBar(title: Text(section.label)),
      body: SettingsPageScope(
        section: section,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [content.entrance(0)],
        ),
      ),
    );
  }
}
