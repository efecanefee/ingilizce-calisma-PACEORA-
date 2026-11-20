import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/providers.dart';
import '../data/rewards.dart';
import '../data/streak_freeze.dart';
import 'mascot.dart';
import 'motion.dart';
import 'theme.dart';

/// Tek seferlik konfeti patlaması. Zamanlayıcı kullanmaz; yalnızca kendi
/// animasyon denetleyicisiyle çalışır.
class ConfettiBurst extends StatefulWidget {
  const ConfettiBurst({super.key, this.particles = 90, this.seed = 7});

  final int particles;
  final int seed;

  @override
  State<ConfettiBurst> createState() => _ConfettiBurstState();
}

class _ConfettiBurstState extends State<ConfettiBurst>
    with SingleTickerProviderStateMixin {
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  )..forward();

  late final _pieces = _generate();

  List<_Piece> _generate() {
    final random = Random(widget.seed);
    final colors = [
      context.pace.accent,
      AppColors.success,
      AppColors.warning,
      Color(0xFF60A5FA),
      Color(0xFFF472B6),
      Colors.white,
    ];
    return List.generate(widget.particles, (_) {
      final angle = -pi / 2 + (random.nextDouble() - 0.5) * pi * 1.1;
      final speed = 0.55 + random.nextDouble() * 0.75;
      return _Piece(
        vx: cos(angle) * speed,
        vy: sin(angle) * speed,
        spin: (random.nextDouble() - 0.5) * 18,
        size: 5 + random.nextDouble() * 7,
        color: colors[random.nextInt(colors.length)],
        round: random.nextBool(),
      );
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) => CustomPaint(
          size: Size.infinite,
          painter: _ConfettiPainter(_pieces, _controller.value),
        ),
      ),
    );
  }
}

class _Piece {
  const _Piece({
    required this.vx,
    required this.vy,
    required this.spin,
    required this.size,
    required this.color,
    required this.round,
  });

  final double vx;
  final double vy;
  final double spin;
  final double size;
  final Color color;
  final bool round;
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter(this.pieces, this.t);

  final List<_Piece> pieces;
  final double t;

  @override
  void paint(Canvas canvas, Size size) {
    if (t == 0 || t == 1) return;
    final origin = Offset(size.width / 2, size.height * 0.42);
    final scale = size.shortestSide;
    final paint = Paint();
    // Son çeyrekte parçalar solarak kaybolur.
    final opacity = t < 0.75 ? 1.0 : (1 - (t - 0.75) / 0.25);

    for (final p in pieces) {
      // Basit balistik: ilk hız + yerçekimi, hava sürtünmesiyle yavaşlama.
      final drag = 1 - exp(-3 * t);
      final x = origin.dx + p.vx * scale * drag;
      final y = origin.dy + p.vy * scale * drag + 0.9 * scale * t * t;
      paint.color = p.color.withValues(alpha: opacity);

      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.spin * t);
      if (p.round) {
        canvas.drawCircle(Offset.zero, p.size / 2, paint);
      } else {
        canvas.drawRect(
          Rect.fromCenter(
            center: Offset.zero,
            width: p.size,
            height: p.size * 0.5,
          ),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter old) => old.t != t;
}

/// Kutlanacak tek bir olay.
class Celebration {
  const Celebration({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    this.chip,
    this.art,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;

  /// Kartın altındaki küçük etiket (ör. "Seviye 3").
  final String? chip;

  /// İkon dairesi yerine gösterilecek görsel (ör. Pace).
  final Widget? art;
}

/// Uygulamanın en üstünde durur; yeni oyuncu seviyesi ya da rozet
/// kazanıldığında hangi ekranda olunursa olunsun kutlama gösterir.
///
/// "Görüldü" bilgisi SharedPreferences'ta tutulur. İlk açılışta mevcut durum
/// sessizce kaydedilir; yalnızca bundan sonraki kazanımlar kutlanır.
class CelebrationHost extends ConsumerStatefulWidget {
  const CelebrationHost({super.key, required this.child});

  final Widget child;

  /// Hangi ekrandan olursa olsun bir kutlama gösterir (ör. forma alındı,
  /// seri hedefi). Kuyruktaki diğer kutlamalardan sonra sıraya girer.
  static void show(BuildContext context, Celebration celebration) {
    context
        .findAncestorStateOfType<_CelebrationHostState>()
        ?._enqueue(celebration);
  }

  @override
  ConsumerState<CelebrationHost> createState() => _CelebrationHostState();
}

class _CelebrationHostState extends ConsumerState<CelebrationHost> {
  static const _seenLevelKey = 'seen_player_level';
  static const _seenBadgesKey = 'seen_badges';

  final _queue = <Celebration>[];
  var _shown = 0;

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  void _check(GameState game) {
    final prefs = _prefs;
    final earned = game.earnedBadgeIds;

    if (!prefs.containsKey(_seenLevelKey)) {
      prefs.setInt(_seenLevelKey, game.level.level);
      prefs.setStringList(_seenBadgesKey, earned.toList());
      return;
    }

    final seenLevel = prefs.getInt(_seenLevelKey) ?? 1;
    final seenBadges = (prefs.getStringList(_seenBadgesKey) ?? const [])
        .toSet();
    final fresh = <Celebration>[];

    if (game.level.level > seenLevel) {
      fresh.add(
        Celebration(
          title: 'Seviye atladın!',
          subtitle: 'Artık "${game.level.title}" unvanını taşıyorsun.',
          icon: Icons.military_tech_rounded,
          color: context.pace.accent,
          chip: 'Seviye ${game.level.level}',
        ),
      );
    }
    for (final badge in badges) {
      if (earned.contains(badge.id) && !seenBadges.contains(badge.id)) {
        fresh.add(
          Celebration(
            title: 'Yeni rozet: ${badge.title}',
            subtitle: badge.description,
            icon: badge.icon,
            color: badge.color,
            chip: 'Rozet',
          ),
        );
      }
    }

    prefs.setInt(_seenLevelKey, game.level.level);
    prefs.setStringList(_seenBadgesKey, earned.toList());
    if (fresh.isNotEmpty) setState(() => _queue.addAll(fresh));
  }

  void _enqueue(Celebration c) => setState(() => _queue.add(c));

  /// Seri yeni bir hedefe (3, 7, 14… gün) ulaştıysa kutlar. İlk açılışta
  /// mevcut durum sessizce kaydedilir.
  void _checkStreak(int streak) {
    final prefs = _prefs;
    final reached = reachedStreakMilestone(streak);
    final seen = prefs.getInt(seenStreakMilestoneKey);
    if (seen == null || reached < seen) {
      // Seri koptuysa sayaç da geri alınır; yeniden ulaşılınca kutlanır.
      prefs.setInt(seenStreakMilestoneKey, reached);
      return;
    }
    if (reached <= seen) return;
    prefs.setInt(seenStreakMilestoneKey, reached);
    final next = streakMilestone(streak).to;
    _enqueue(
      Celebration(
        title: '$reached günlük seri!',
        subtitle: 'Harika gidiyorsun. Sıradaki hedef: $next gün.',
        icon: Icons.local_fire_department_rounded,
        color: const Color(0xFFFF9F1C),
        chip: 'Seri hedefi',
        art: const EquippedPace(mood: PaceMood.cheer, size: 130),
      ),
    );
  }

  void _dismiss() {
    setState(() {
      _queue.removeAt(0);
      _shown++;
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(gameProvider, (_, next) {
      if (next case AsyncData(:final value)) _check(value);
    });
    ref.listen(streakDisplayProvider, (previous, next) {
      // Profil yüklenmeden gelen 0 değeri hedef sayacını sıfırlamasın.
      if (ref.read(profileProvider).value == null) return;
      _checkStreak(next.streak);
    });
    // Profil yoksa (onboarding) ödül de yok; dinlemeyi başlatmak yeterli.
    ref.watch(gameProvider);

    return Stack(
      children: [
        widget.child,
        if (_queue.isNotEmpty)
          Positioned.fill(
            child: _CelebrationView(
              key: ValueKey(_shown),
              celebration: _queue.first,
              onDismiss: _dismiss,
            ),
          ),
      ],
    );
  }
}

class _CelebrationView extends StatelessWidget {
  const _CelebrationView({
    super.key,
    required this.celebration,
    required this.onDismiss,
  });

  final Celebration celebration;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final c = celebration;

    return Material(
      type: MaterialType.transparency,
      child: Stack(
        children: [
          Positioned.fill(
            child: GestureDetector(
              onTap: onDismiss,
              child: const ColoredBox(color: Color(0xB3000000)),
            ).animate().fadeIn(duration: Motion.medium),
          ),
          const Positioned.fill(child: ConfettiBurst()),
          Center(
                child: Padding(
                  padding: const EdgeInsets.all(32),
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(24, 28, 24, 20),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surfaceContainer,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: [
                        BoxShadow(
                          color: c.color.withValues(alpha: 0.35),
                          blurRadius: 40,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        c.art ??
                            Container(
                              width: 96,
                              height: 96,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                gradient: RadialGradient(
                                  colors: [
                                    c.color,
                                    c.color.withValues(alpha: 0.55),
                                  ],
                                ),
                                boxShadow: [
                                  BoxShadow(
                                    color: c.color.withValues(alpha: 0.6),
                                    blurRadius: 24,
                                  ),
                                ],
                              ),
                              child: Icon(
                                c.icon,
                                size: 52,
                                color: AppColors.graphite900,
                              ),
                            )
                            .animate()
                            .scale(
                              begin: const Offset(0.2, 0.2),
                              duration: Motion.slow,
                              curve: Curves.elasticOut,
                            )
                            .then()
                            .shimmer(duration: 900.ms, color: Colors.white),
                        const SizedBox(height: 20),
                        Text(
                          c.title,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ).entrance(2),
                        const SizedBox(height: 8),
                        Text(
                          c.subtitle,
                          textAlign: TextAlign.center,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.75,
                            ),
                          ),
                        ).entrance(3),
                        if (c.chip != null) ...[
                          const SizedBox(height: 14),
                          Chip(
                            label: Text(c.chip!),
                            avatar: Icon(Icons.star_rounded, color: c.color),
                          ).entrance(4),
                        ],
                        const SizedBox(height: 18),
                        FilledButton(
                          onPressed: onDismiss,
                          child: const Text('Harika!'),
                        ).entrance(5),
                      ],
                    ),
                  ),
                ),
              )
              .animate()
              .fadeIn(duration: Motion.fast)
              .scale(
                begin: const Offset(0.85, 0.85),
                curve: Curves.easeOutBack,
              ),
        ],
      ),
    );
  }
}
