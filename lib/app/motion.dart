import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';

/// Uygulama genelinde ortak hareket dili.
///
/// Süreler kısa tutuldu: animasyon içeriği süslemeli, kullanıcıyı bekletmemeli.
abstract class Motion {
  static const fast = Duration(milliseconds: 180);
  static const medium = Duration(milliseconds: 320);
  static const slow = Duration(milliseconds: 600);

  static const curve = Curves.easeOutCubic;

  /// Liste öğeleri arasındaki gecikme (sırayla belirme).
  static const stagger = Duration(milliseconds: 60);
}

/// Alt sayfalar için yumuşak kayma + solma geçişi.
CustomTransitionPage<void> motionPage(GoRouterState state, Widget child) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: Motion.medium,
    reverseTransitionDuration: Motion.fast,
    transitionsBuilder: (context, animation, secondary, child) {
      final curved = CurvedAnimation(parent: animation, curve: Motion.curve);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween(begin: const Offset(0, 0.06), end: Offset.zero)
              .animate(curved),
          child: child,
        ),
      );
    },
  );
}

extension EntranceAnimation on Widget {
  /// Listede [index]. sıradaki öğe için yukarı kayarak belirme.
  Widget entrance(int index) => animate(delay: Motion.stagger * index)
      .fadeIn(duration: Motion.medium, curve: Motion.curve)
      .slideY(begin: 0.12, end: 0, duration: Motion.medium, curve: Motion.curve);
}

/// Basılınca hafifçe küçülen dokunma alanı; kartlara fiziksel his verir.
class PressableScale extends StatefulWidget {
  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.borderRadius = const BorderRadius.all(Radius.circular(20)),
  });

  final Widget child;
  final VoidCallback? onTap;
  final BorderRadius borderRadius;

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool value) {
    if (widget.onTap == null || _pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedScale(
      scale: _pressed ? 0.96 : 1,
      duration: Motion.fast,
      curve: Motion.curve,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: widget.borderRadius,
          onTap: widget.onTap == null
              ? null
              : () {
                  HapticFeedback.selectionClick();
                  widget.onTap!();
                },
          onTapDown: (_) => _set(true),
          onTapUp: (_) => _set(false),
          onTapCancel: () => _set(false),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Sıfırdan hedef değere sayan metin (skor, istatistik).
class CountUpText extends StatelessWidget {
  const CountUpText({
    super.key,
    required this.value,
    this.prefix = '',
    this.suffix = '',
    this.style,
    this.duration = Motion.slow,
  });

  final num value;
  final String prefix;
  final String suffix;
  final TextStyle? style;
  final Duration duration;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: duration,
      curve: Motion.curve,
      builder: (context, v, _) =>
          Text('$prefix${v.round()}$suffix', style: style),
    );
  }
}

/// Seri rozetindeki alevin sürekli "nefes alması".
class PulsingFlame extends StatelessWidget {
  const PulsingFlame({super.key, this.size = 18, this.active = true});

  final double size;

  /// Seri sıfırsa alev söner (soluk ve hareketsiz).
  final bool active;

  @override
  Widget build(BuildContext context) {
    final flame = Text('🔥', style: TextStyle(fontSize: size));
    if (!active) return Opacity(opacity: 0.35, child: flame);
    return flame
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleXY(begin: 0.9, end: 1.12, duration: 900.ms, curve: Curves.easeInOut)
        .rotate(begin: -0.02, end: 0.02, duration: 900.ms);
  }
}
