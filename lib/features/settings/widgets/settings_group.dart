import 'package:flutter/material.dart';

import '../settings_section.dart';

/// Başlıklı, kart içinde gruplanmış ayar satırları.
///
/// Başlık bölüm rengiyle yazılır; içindeki her [SettingsTile] rengini
/// [SettingsSectionScope] üzerinden buradan alır, böylece bir gruptaki tüm
/// simgeler aynı renkte kalır.
class SettingsGroup extends StatelessWidget {
  const SettingsGroup({
    super.key,
    required this.section,
    required this.children,
  });

  final SettingsSection section;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SettingsSectionScope(
      section: section,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                section.title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: section.color(context),
                ),
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
      ),
    );
  }
}

/// Satırlara içinde bulundukları bölümü bildirir.
class SettingsSectionScope extends InheritedWidget {
  const SettingsSectionScope({
    super.key,
    required this.section,
    required super.child,
  });

  final SettingsSection section;

  /// En yakın gruptaki bölüm; grup dışında [SettingsSection.about] (nötr).
  static SettingsSection of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<SettingsSectionScope>()
          ?.section ??
      SettingsSection.about;

  @override
  bool updateShouldNotify(SettingsSectionScope oldWidget) =>
      section != oldWidget.section;
}
