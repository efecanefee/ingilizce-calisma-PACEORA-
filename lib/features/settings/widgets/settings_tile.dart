import 'package:flutter/material.dart';

import '../../../app/motion.dart';
import '../settings_section.dart';

/// Tüm ayar satırlarının ortak görünümü: nötr simge kutusu, başlık, isteğe
/// bağlı açıklama ve sağda kontrol ya da ok.
///
/// Simgeler renksizdir; tek istisna [danger]: geri alınamaz işlemler hata
/// rengindedir.
///
/// [below] verilirse (ör. tema seçici, vurgu renkleri) satırın altında, aynı
/// kart hücresinde gösterilir.
class SettingsTile extends StatelessWidget {
  const SettingsTile({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.trailing,
    this.onTap,
    this.below,
    this.danger = false,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final Widget? below;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dark = theme.brightness == Brightness.dark;
    final color = danger
        ? theme.colorScheme.error
        : SettingsSection.iconColor(context);
    final tint = danger
        ? color.withValues(alpha: dark ? 0.16 : 0.10)
        : SettingsSection.iconTint(context);

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
          color: tint,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Icon(icon, size: 20, color: color),
      ),
      title: Text(
        title,
        style: theme.textTheme.bodyLarge?.copyWith(
          fontWeight: FontWeight.w600,
          color: danger ? color : null,
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
    final row = trailing == null ? tile : MergeSemantics(child: tile);
    if (below == null) return row;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: below,
        ),
      ],
    );
  }
}
