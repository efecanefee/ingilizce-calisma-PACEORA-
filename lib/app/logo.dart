import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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

/// Karşılama ekranının hareketli logosu: üstte harf harf beliren PACEORA
/// yazısı, ortada dönen lime halka ve nefes alan parıltının içinde Pace
/// rozeti, altta slogan.
///
/// Sistemde "animasyonları azalt" açıksa her şey son hâlinde, hareketsiz
/// gösterilir.
class AnimatedPaceoraLockup extends StatefulWidget {
  const AnimatedPaceoraLockup({super.key, this.size = 190});

  final double size;

  @override
  State<AnimatedPaceoraLockup> createState() => _AnimatedPaceoraLockupState();
}

class _AnimatedPaceoraLockupState extends State<AnimatedPaceoraLockup>
    with SingleTickerProviderStateMixin {
  /// Halka, parıltı ve yörünge ışıkları aynı saatle döner (8 sn'de bir tur).
  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (reduced) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    final size = widget.size;
    final ringSize = size * 0.82;
    final lime = theme.brightness == Brightness.dark
        ? AppColors.brandLime
        : AppColors.brandLimeDark;

    return Semantics(
      label: 'Paceora. ${LogoAssets.slogan}',
      excludeSemantics: true,
      child: SizedBox(
        width: size * 1.3,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LetterByLetterWordmark(fontSize: size * 0.2, reduced: reduced),
            SizedBox(height: size * 0.06),
            SizedBox.square(
              dimension: ringSize,
              child: AnimatedBuilder(
                animation: _spin,
                builder: (context, child) => CustomPaint(
                  painter: PaceHaloPainter(turn: _spin.value, color: lime),
                  child: child,
                ),
                child: Center(child: _badge(size, reduced)),
              ),
            ),
            SizedBox(height: size * 0.05),
            _fadeLate(
              FittedBox(
                child: Text(
                  LogoAssets.slogan,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                    letterSpacing: 0.4,
                  ),
                ),
              ),
              reduced,
            ),
          ],
        ),
      ),
    );
  }

  /// Rozet önce yaylanarak büyür, sonra çok hafif nefes alır.
  Widget _badge(double size, bool reduced) {
    final badge = PaceoraMark(size: size * 0.6);
    if (reduced) return badge;
    return badge
        .animate()
        .scale(
          begin: const Offset(0.6, 0.6),
          duration: 900.ms,
          curve: Curves.elasticOut,
        )
        .fadeIn(duration: 400.ms)
        .then()
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(end: 1.04, duration: 1800.ms, curve: Curves.easeInOut);
  }

  Widget _fadeLate(Widget child, bool reduced) => reduced
      ? child
      : child
            .animate()
            .fadeIn(delay: 1300.ms, duration: 700.ms)
            .slideY(begin: 0.4, end: 0, curve: Curves.easeOutCubic);
}

/// PACEORA harfleri soldan sağa, sırayla yukarı kayarak belirir; sonra
/// üzerinden bir ışık geçer.
class LetterByLetterWordmark extends StatelessWidget {
  const LetterByLetterWordmark({
    super.key,
    required this.fontSize,
    required this.reduced,
    this.delay = Duration.zero,
  });

  /// İlk harften önce beklenecek süre.
  final Duration delay;

  final double fontSize;
  final bool reduced;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final base = theme.textTheme.titleLarge?.copyWith(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      fontStyle: FontStyle.italic,
      letterSpacing: -0.5,
      height: 1,
    );
    const word = 'PACEORA';
    final row = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < word.length; i++)
          _letter(
            Text(
              word[i],
              style: base?.copyWith(
                color: i < 4
                    ? (isDark ? AppColors.brandLime : AppColors.brandLimeDark)
                    : theme.colorScheme.onSurface,
              ),
            ),
            i,
          ),
      ],
    );
    final fitted = FittedBox(child: row);
    if (reduced) return fitted;
    return fitted
        .animate(delay: delay + 1200.ms)
        .shimmer(
          duration: 1400.ms,
          color: AppColors.brandLime.withValues(alpha: 0.9),
        );
  }

  Widget _letter(Widget letter, int index) => reduced
      ? letter
      : letter
            .animate(delay: delay + (140 * index).ms)
            .fadeIn(duration: 500.ms, curve: Curves.easeOut)
            .slideY(
              begin: 0.6,
              end: 0,
              duration: 600.ms,
              curve: Curves.easeOutBack,
            )
            .blurXY(begin: 6, end: 0, duration: 500.ms);
}

/// Rozetin arkasındaki hareketli hale: nefes alan parıltı, dönen yarım
/// halka ve yörüngedeki üç küçük ışık.
class PaceHaloPainter extends CustomPainter {
  PaceHaloPainter({required this.turn, required this.color, this.opacity = 1});

  /// Halenin görünürlüğü (açılışta yavaşça belirmesi için).
  final double opacity;

  /// 0–1 arası tur.
  final double turn;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (opacity <= 0) return;
    final fading = opacity < 1;
    if (fading) {
      canvas.saveLayer(
        Offset.zero & size,
        Paint()..color = Color.fromRGBO(0, 0, 0, opacity),
      );
    }
    _paintHalo(canvas, size);
    if (fading) canvas.restore();
  }

  void _paintHalo(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final angle = turn * 2 * math.pi;

    // Nefes alan yumuşak parıltı (turda iki kez).
    final breath = 0.5 + 0.5 * math.sin(angle * 2);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.22 + 0.12 * breath),
            color.withValues(alpha: 0),
          ],
        ).createShader(Rect.fromCircle(center: center, radius: radius)),
    );

    // Dönen, ucu parlayan yay.
    final ringRect = Rect.fromCircle(center: center, radius: radius * 0.86);
    final stroke = radius * 0.045;
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(angle);
    canvas.translate(-center.dx, -center.dy);
    canvas.drawArc(
      ringRect,
      0,
      math.pi * 1.4,
      false,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.round
        ..shader = SweepGradient(
          colors: [color.withValues(alpha: 0), color],
          stops: const [0, 0.7],
        ).createShader(ringRect),
    );
    canvas.restore();

    // Ters yönde dönen ince kesikli iç halka.
    final inner = radius * 0.94;
    final dash = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke * 0.35
      ..color = color.withValues(alpha: 0.35);
    const dashes = 36;
    for (var i = 0; i < dashes; i += 2) {
      final start = -angle * 0.6 + i * 2 * math.pi / dashes;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: inner),
        start,
        math.pi / dashes,
        false,
        dash,
      );
    }

    // Yörüngede dönen üç ışık.
    for (var i = 0; i < 3; i++) {
      final a = angle * 1.5 + i * 2 * math.pi / 3;
      final p = center + Offset(math.cos(a), math.sin(a)) * radius * 0.86;
      final r = stroke * (0.9 + 0.3 * math.sin(angle * 4 + i));
      canvas.drawCircle(
        p,
        r * 2.2,
        Paint()..color = color.withValues(alpha: 0.18),
      );
      canvas.drawCircle(p, r, Paint()..color = color);
    }
  }

  @override
  bool shouldRepaint(PaceHaloPainter old) =>
      old.turn != turn || old.color != color || old.opacity != opacity;
}
