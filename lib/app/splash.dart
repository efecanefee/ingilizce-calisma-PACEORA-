import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'logo.dart';
import 'theme.dart';

/// Uygulama açılırken sistem açılış ekranının (Android 12+ ortada rozet)
/// devamı: ilk karesi onunla birebir aynıdır (aynı zemin, ortada 180 dp
/// rozet), sonra rozetin çevresinde hale belirir, PACEORA yazısı üstte harf
/// harf gelir, slogan altta açılır. Kısa süre sonra solarak uygulamaya geçer;
/// dokununca hemen geçilir.
class SplashOverlay extends StatefulWidget {
  const SplashOverlay({super.key, required this.child, this.enabled = true});

  final Widget child;

  /// Testlerde ve yeniden kurulumlarda kapalı.
  final bool enabled;

  /// Açılış ekranının ekranda kalma süresi (animasyonlar açıkken).
  static const duration = Duration(milliseconds: 2600);

  /// Hareket azaltılmışsa yalnızca kısa bir an gösterilir.
  static const reducedDuration = Duration(milliseconds: 700);

  @override
  State<SplashOverlay> createState() => _SplashOverlayState();
}

class _SplashOverlayState extends State<SplashOverlay>
    with TickerProviderStateMixin {
  late bool _visible = widget.enabled;
  Timer? _timer;

  // initState'te kurulur: tembel (late) olsaydı ilk kez dispose sırasında
  // oluşturulup hata verirdi.
  late final AnimationController _exit;

  @override
  void initState() {
    super.initState();
    _exit = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 450),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed && mounted) {
          setState(() => _visible = false);
        }
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_visible && _timer == null) {
      final reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
      _timer = Timer(
        reduced ? SplashOverlay.reducedDuration : SplashOverlay.duration,
        _dismiss,
      );
    }
  }

  void _dismiss() {
    _timer?.cancel();
    if (mounted && !_exit.isAnimating) _exit.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _exit.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!_visible) return widget.child;
    return Stack(
      fit: StackFit.expand,
      children: [
        widget.child,
        FadeTransition(
          opacity: ReverseAnimation(_exit),
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: _dismiss,
            child: const _SplashView(),
          ),
        ),
      ],
    );
  }
}

class _SplashView extends StatefulWidget {
  const _SplashView();

  @override
  State<_SplashView> createState() => _SplashViewState();
}

class _SplashViewState extends State<_SplashView>
    with SingleTickerProviderStateMixin {
  /// Sistem açılış ekranının zemini (android ic_launcher_background).
  static const background = Color(0xFF1C1F24);

  /// Sistem açılış ekranındaki rozet boyutu (288 dp simgenin 180 dp'lik içi).
  static const badgeSize = 180.0;

  late final AnimationController _spin = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 8),
  );

  late bool _reduced;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    if (_reduced) {
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
    // Zemin her zaman koyu: sistem açılış ekranıyla aynı.
    return Theme(
      data: buildTheme(Brightness.dark, AppAccent.values.first),
      child: Builder(
        builder: (context) {
          final theme = Theme.of(context);
          return Semantics(
            label: 'Paceora açılıyor',
            child: ColoredBox(
              color: background,
              child: Stack(
                children: [
                  // Rozet ve hale: tam ortada, sistem ekranıyla aynı yerde.
                  Center(
                    child: SizedBox.square(
                      dimension: badgeSize * 1.45,
                      child: _halo(
                        const Center(child: PaceoraMark(size: badgeSize)),
                      ),
                    ),
                  ),
                  // PACEORA üstte, harf harf.
                  Align(
                    alignment: const Alignment(0, -0.62),
                    child: LetterByLetterWordmark(
                      fontSize: 46,
                      reduced: _reduced,
                      delay: 250.ms,
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, 0.55),
                    child: _late(
                      Text(
                        LogoAssets.slogan,
                        style: theme.textTheme.titleSmall?.copyWith(
                          color: Colors.white.withValues(alpha: 0.7),
                          letterSpacing: 0.6,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  /// Hale ilk karede yoktur (sistem ekranında yalnız rozet var); yavaşça
  /// belirir ve dönmeye başlar.
  Widget _halo(Widget child) {
    if (_reduced) {
      return CustomPaint(
        painter: PaceHaloPainter(turn: 0, color: AppColors.brandLime),
        child: child,
      );
    }
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOut,
      builder: (context, appear, child) => AnimatedBuilder(
        animation: _spin,
        builder: (context, child) => CustomPaint(
          painter: PaceHaloPainter(
            turn: _spin.value,
            color: AppColors.brandLime,
            opacity: appear,
          ),
          child: child,
        ),
        child: child,
      ),
      child: child,
    );
  }

  Widget _late(Widget child) => _reduced
      ? child
      : child
          .animate()
          .fadeIn(delay: 1500.ms, duration: 700.ms)
          .slideY(begin: 0.5, end: 0, curve: Curves.easeOutCubic);
}
