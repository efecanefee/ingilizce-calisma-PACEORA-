import 'package:flutter/material.dart';

import 'constants.dart';

/// Logo görselleri koyu zeminli üretildiği için yuvarlatılmış bir rozet
/// içinde gösterilir — açık temada da kasıtlı durur.
abstract class LogoAssets {
  static const mark = 'assets/images/paceora_mark.png';
  static const lockup = 'assets/images/paceora_logo.png';
}

/// Yalnızca amblem (kadran + şimşek). AppBar ve başlıklarda kullanılır.
class PaceoraMark extends StatelessWidget {
  const PaceoraMark({super.key, this.size = 32, this.radius = 9});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.asset(
        LogoAssets.mark,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}

/// Amblem + "Paceora" yazısı — yatay başlık kilidi.
class PaceoraWordmark extends StatelessWidget {
  const PaceoraWordmark({super.key, this.markSize = 30});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PaceoraMark(size: markSize),
        const SizedBox(width: 10),
        Text(
          AppConstants.appName,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.3,
          ),
        ),
      ],
    );
  }
}

/// Amblem + kelime markası + slogan içeren tam logo.
class PaceoraLockup extends StatelessWidget {
  const PaceoraLockup({super.key, this.size = 190});

  final double size;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: Image.asset(
        LogoAssets.lockup,
        width: size,
        height: size,
        fit: BoxFit.cover,
        filterQuality: FilterQuality.medium,
      ),
    );
  }
}
