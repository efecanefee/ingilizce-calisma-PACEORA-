import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/motion.dart';
import '../../data/providers.dart';
import 'groups/about_group.dart';
import 'groups/advanced_group.dart';
import 'groups/appearance_group.dart';
import 'groups/data_group.dart';
import 'groups/notifications_group.dart';
import 'groups/study_group.dart';
import 'profile/profile_header.dart';

// Ana ekran ve ders ekranı anahtar formunu buradan açar.
export 'sheets/api_key_sheet.dart' show showApiKeySheet;

/// Ayarlar: profil kartı ve bölümlere ayrılmış tercihler.
///
/// Her bölümün tek bir rengi vardır (`settings_section.dart`); satırların
/// hepsi aynı `SettingsTile` görünümünü kullanır.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(profileProvider).value;

    var index = 0;
    Widget item(Widget child) => child.entrance(index++);
    const gap = SizedBox(height: 20);

    return Scaffold(
      appBar: AppBar(title: const Text('Ayarlar')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
        children: [
          if (user != null) ...[
            item(ProfileHeader(user: user)),
            const SizedBox(height: 24),
            item(StudyGroup(user: user)),
            gap,
          ],
          item(const AppearanceGroup()),
          gap,
          item(const NotificationsGroup()),
          gap,
          item(const DataGroup()),
          gap,
          item(const AdvancedGroup()),
          gap,
          item(const AboutGroup()),
        ],
      ),
    );
  }
}
