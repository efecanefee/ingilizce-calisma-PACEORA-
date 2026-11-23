import 'package:flutter/material.dart';

import '../settings_section.dart';

/// Kart içinde gruplanmış ayar satırları.
///
/// Bölümün kendi sayfasında ([SettingsSectionPage]) başlık sayfa çubuğunda
/// yazdığı için grup başlığı gösterilmez; başka bir yerde kullanılırsa
/// nötr renkte küçük bir başlık çıkar.
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
    final onOwnPage = SettingsPageScope.of(context) == section;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (!onOwnPage)
          Padding(
            padding: const EdgeInsets.only(left: 4, bottom: 8),
            child: Semantics(
              header: true,
              child: Text(
                section.title,
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.1,
                  color: theme.colorScheme.onSurfaceVariant,
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
    );
  }
}

/// Hangi bölümün sayfasında olunduğunu alttaki gruplara bildirir.
class SettingsPageScope extends InheritedWidget {
  const SettingsPageScope({
    super.key,
    required this.section,
    required super.child,
  });

  final SettingsSection section;

  /// En yakın bölüm sayfası; ana Ayarlar listesindeyse null.
  static SettingsSection? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<SettingsPageScope>()?.section;

  @override
  bool updateShouldNotify(SettingsPageScope oldWidget) =>
      section != oldWidget.section;
}
