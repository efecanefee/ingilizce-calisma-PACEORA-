import 'package:flutter/material.dart';

import 'mascot.dart';
import 'theme.dart';

/// Logo: lime halka içinde Pace rozeti + "PACEORA" kelime markası.
/// Rozet kendi koyu zeminini taşır; köşeleri şeffaf olduğu için açık ve
/// koyu temada aynı görünür.
abstract class LogoAssets {
  static const mark = MascotAssets.badge;
  static const slogan = 'Learn English. Go Further.';
}

/// Yalnızca amblem (Pace rozeti). AppBar ve başlıklarda kullanılır.
class PaceoraMark extends StatelessWidget {
  const PaceoraMark({super.key, this.size = 32});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Image.asset(
      LogoAssets.mark,
      width: size,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      semanticLabel: 'Paceora',
    );
  }
}

/// "PACEORA" yazısı: PACE lime, ORA metin renginde, eğik ve kalın.
class _WordmarkText extends StatelessWidget {
  const _WordmarkText({required this.fontSize});

  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: 'PACE',
            // Açık zeminde parlak lime okunmuyor; koyu tonu kullan.
            style: TextStyle(
              color: isDark ? AppColors.brandLime : AppColors.brandLimeDark,
            ),
          ),
          TextSpan(
            text: 'ORA',
            style: TextStyle(color: theme.colorScheme.onSurface),
          ),
        ],
      ),
      style: theme.textTheme.titleLarge?.copyWith(
        fontSize: fontSize,
        fontWeight: FontWeight.w900,
        fontStyle: FontStyle.italic,
        letterSpacing: -0.5,
        height: 1,
      ),
      semanticsLabel: 'Paceora',
    );
  }
}

/// Amblem + "PACEORA" yazısı — yatay başlık kilidi.
class PaceoraWordmark extends StatelessWidget {
  const PaceoraWordmark({super.key, this.markSize = 30});

  final double markSize;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        PaceoraMark(size: markSize),
        const SizedBox(width: 10),
        _WordmarkText(fontSize: markSize * 0.72),
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
    final theme = Theme.of(context);
    return SizedBox(
      width: size * 1.3,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          PaceoraMark(size: size * 0.62),
          SizedBox(height: size * 0.06),
          FittedBox(child: _WordmarkText(fontSize: size * 0.2)),
          SizedBox(height: size * 0.04),
          FittedBox(
            child: Text(
              LogoAssets.slogan,
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                letterSpacing: 0.4,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
