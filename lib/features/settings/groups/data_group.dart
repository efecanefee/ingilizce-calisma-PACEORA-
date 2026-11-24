import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/constants.dart';
import '../../../data/backup.dart';
import '../../../data/level_exam.dart';
import '../../../data/placement.dart';
import '../../../data/profile_style.dart';
import '../../../data/providers.dart';
import '../../../data/rewards.dart';
import '../../../data/settings_providers.dart';
import '../settings_section.dart';
import '../widgets/settings_group.dart';
import '../widgets/settings_tile.dart';

/// VERİLERİM: yedek alma, geri yükleme ve her şeyi sıfırlama.
class DataGroup extends ConsumerStatefulWidget {
  const DataGroup({super.key});

  @override
  ConsumerState<DataGroup> createState() => _DataGroupState();
}

class _DataGroupState extends ConsumerState<DataGroup> {
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
            key.startsWith('writing_') ||
            key.startsWith(AppConstants.prefShortDayPrefix) ||
            key.startsWith('streak_') ||
            key.startsWith('profile_') ||
            key.startsWith('wardrobe_') ||
            key == PlacementRecord.levelKey ||
            key == levelUpsKey ||
            key == levelExamAtKey ||
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
      ref.invalidate(soundsProvider);
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
    return SettingsGroup(
      section: SettingsSection.data,
      children: [
        SettingsTile(
          icon: Icons.upload_file_rounded,
          title: 'Verileri dışa aktar',
          subtitle: 'Tüm ilerlemeni bir dosyaya yedekle',
          onTap: _busy ? null : _export,
        ),
        SettingsTile(
          icon: Icons.restore_rounded,
          title: 'Yedekten geri yükle',
          subtitle: 'Başka cihazdan aldığın yedeği yükle',
          onTap: _busy ? null : _restore,
        ),
        SettingsTile(
          icon: Icons.delete_forever_rounded,
          title: 'Verileri sıfırla',
          subtitle: 'Her şeyi siler ve kurulumu baştan başlatır',
          danger: true,
          onTap: _busy ? null : _reset,
        ),
      ],
    );
  }
}
