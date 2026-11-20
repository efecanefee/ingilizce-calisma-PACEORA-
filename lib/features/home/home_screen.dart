import 'dart:math';

import 'package:clock/clock.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/avatar.dart';
import '../../app/constants.dart';
import '../../app/logo.dart';
import '../../app/mascot.dart';
import '../../app/motion.dart';
import '../../app/pace_messages.dart';
import '../../app/theme.dart';
import '../../data/database.dart';
import '../../data/profile_style.dart';
import '../../data/providers.dart';
import '../../data/repository.dart' show mondayOf;
import '../../data/rewards.dart';
import '../../data/streak_freeze.dart';
import '../program/program_screen.dart';
import '../settings/settings_screen.dart' show showApiKeySheet;
import '../wardrobe/wardrobe_sheet.dart';

/// Ana ekran ("Bugün" sekmesi): karşılama, bugünün dersi, günlük hedef,
/// haftanın özeti ve pratik alanları.
class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider);
    final plan = ref.watch(weekPlanProvider);

    return Scaffold(
      appBar: AppBar(title: const PaceoraWordmark(markSize: 28)),
      body: switch ((profile, plan)) {
        (AsyncError(:final error), _) ||
        (_, AsyncError(:final error)) => _ErrorView(message: '$error'),
        (AsyncData(value: null), _) => const _NoProfileView(),
        (AsyncData(value: final user?), AsyncData(value: final week)) =>
          _HomeBody(user: user, week: week),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({required this.user, required this.week});

  final UserProfile user;
  final WeekPlan week;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = week.today;
    final lesson = ref.watch(todayLessonProvider).value;
    final game = ref.watch(gameProvider).value;
    final sectionStyle = Theme.of(
      context,
    ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700);

    var index = 0;
    Widget item(Widget child) => child.entrance(index++);

    return RefreshIndicator(
      onRefresh: () async {
        ref.invalidate(gameProvider);
        ref.invalidate(flashcardSummaryProvider);
        await ref.read(gameProvider.future);
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          item(_HeroCard(user: user, level: game?.level)),
          const SizedBox(height: 16),
          if (week.offline) ...[
            item(const _OfflineBadge()),
            const SizedBox(height: 12),
          ],
          if (today == null)
            item(const _EmptyPlanCard())
          else
            item(
              _TodayCard(
                day: today,
                dailyMinutes: user.dailyMinutes,
                lesson: lesson,
                onStudy: () => context.push('/lesson'),
                onComplete: () =>
                    ref.read(weekPlanProvider.notifier).completeDay(today),
              ),
            ),
          const SizedBox(height: 16),
          item(const _DailyGoalCard()),
          // Anahtar yoksa kişisel derslerin nasıl açılacağını anlatır.
          const _ApiKeyHint(),
          const SizedBox(height: 28),
          item(
            Row(
              children: [
                Expanded(child: Text('Bu hafta', style: sectionStyle)),
                TextButton(
                  onPressed: () => context.go('/program'),
                  child: const Text('Programı gör'),
                ),
              ],
            ),
          ),
          item(_WeekStrip(week: week)),
          const SizedBox(height: 28),
          item(Text('Pratik alanı', style: sectionStyle)),
          const SizedBox(height: 12),
          item(const _PracticeGrid()),
        ],
      ),
    );
  }
}

/// Gemini anahtarı yokken (paylaşım sürümü) gösterilen, kapatılabilen kart.
class _ApiKeyHint extends ConsumerStatefulWidget {
  const _ApiKeyHint();

  static const dismissedKey = 'api_key_hint_dismissed';

  @override
  ConsumerState<_ApiKeyHint> createState() => _ApiKeyHintState();
}

class _ApiKeyHintState extends ConsumerState<_ApiKeyHint> {
  late bool _dismissed =
      ref.read(sharedPreferencesProvider).getBool(_ApiKeyHint.dismissedKey) ??
      false;

  Future<void> _dismiss() async {
    setState(() => _dismissed = true);
    await ref
        .read(sharedPreferencesProvider)
        .setBool(_ApiKeyHint.dismissedKey, true);
  }

  @override
  Widget build(BuildContext context) {
    final hasKey = ref.watch(geminiServiceProvider).hasApiKey;
    if (hasKey || _dismissed) return const SizedBox.shrink();

    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.auto_awesome_rounded, color: context.pace.accentDark),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Sana özel dersler için anahtar ekle',
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Şu an hazır derslerle çalışıyorsun. Google AI Studio\'dan '
                      'ücretsiz bir Gemini anahtarı alıp eklersen dersler, '
                      'hikayeler ve sohbet seviyene göre üretilir.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 8),
                    FilledButton.tonal(
                      onPressed: () => showApiKeySheet(context),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size(0, 40),
                      ),
                      child: const Text('Anahtar ekle'),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Kapat',
                onPressed: _dismiss,
                icon: const Icon(Icons.close_rounded, size: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Hareketli gradyanlı karşılama kartı: selam, seri ve oyuncu seviyesi.
class _HeroCard extends StatefulWidget {
  const _HeroCard({required this.user, required this.level});

  final UserProfile user;
  final PlayerLevel? level;

  @override
  State<_HeroCard> createState() => _HeroCardState();
}

class _HeroCardState extends State<_HeroCard>
    with SingleTickerProviderStateMixin {
  // Gradyanın yavaşça "nefes alması" kartı canlı gösterir.
  late final _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 6),
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // "Animasyonları azalt" açıksa gradyan durur.
    if (MediaQuery.disableAnimationsOf(context)) {
      _controller.stop();
    } else if (!_controller.isAnimating) {
      _controller.repeat(reverse: true);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final user = widget.user;
    final level = widget.level;
    const onHero = Colors.white;

    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_controller.value);
        return Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(28),
            gradient: LinearGradient(
              begin: Alignment(-1 + t, -1),
              end: Alignment(1, 1 - t),
              colors: [
                AppColors.graphite900,
                AppColors.graphite700,
                context.pace.accentDark,
              ],
              stops: [0, 0.55 + 0.15 * t, 1],
            ),
            boxShadow: [
              BoxShadow(
                color: context.pace.accentDark.withValues(alpha: 0.25 + 0.15 * t),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: child,
        );
      },
      child: Stack(
        children: [
          // Köşede dönen soluk şimşek: markanın imzası.
          Positioned(
            right: -18,
            top: -18,
            child:
                Icon(
                      Icons.bolt_rounded,
                      size: 140,
                      color: context.pace.accent.withValues(alpha: 0.08),
                    )
                    .animate(onPlay: Motion.loop(reverse: true))
                    .rotate(begin: -0.03, end: 0.03, duration: 3.seconds),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Avatar ve seri üstte; selam altta tam genişlikte. Yan yana
                // dizildiklerinde ad ve hedef satırı ikiye kırılıyordu.
                Row(
                  children: [
                    _HeroAvatar(level: level?.level ?? 1),
                    const Spacer(),
                    const _StreakChip(),
                  ],
                ),
                const SizedBox(height: 14),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Merhaba, ${user.name}',
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.w800,
                              color: onHero,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            'Seviye '
                            '${DifficultyLevel.fromCode(user.level).label} · '
                            'günde ${user.dailyMinutes} dk',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: onHero.withValues(alpha: 0.75),
                            ),
                          ),
                          const SizedBox(height: 10),
                          const _PaceBubble(),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    const _HeroPace(),
                  ],
                ),
                const SizedBox(height: 16),
                if (level != null) _XpBar(level: level),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pace'in konuşma balonu: güne ve seriye göre kısa bir mesaj. Kuyruğu
/// sağdaki Pace'i gösterir.
class _PaceBubble extends ConsumerWidget {
  const _PaceBubble();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final display = ref.watch(streakDisplayProvider);
    final message = paceMessage(
      status: display.status,
      streak: display.streak,
      now: clock.now(),
    );
    return Semantics(
      label: 'Pace diyor ki: $message',
      excludeSemantics: true,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.12),
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(12),
            topRight: Radius.circular(12),
            bottomLeft: Radius.circular(12),
            bottomRight: Radius.circular(3),
          ),
        ),
        child: Text(
          message,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: Theme.of(context).textTheme.labelMedium?.copyWith(
            color: Colors.white.withValues(alpha: 0.92),
            height: 1.3,
          ),
        ),
      ),
    );
  }
}

/// Karşılama kartındaki Pace: serinin durumuna göre poz değiştirir.
class _HeroPace extends ConsumerWidget {
  const _HeroPace();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(streakDisplayProvider).status;
    final mood = switch (status) {
      StreakStatus.done => PaceMood.cheer,
      StreakStatus.protected => PaceMood.surprised,
      _ => PaceMood.run,
    };
    // Pace'e dokununca dolabı açılır.
    return Semantics(
      button: true,
      label: "Pace'in dolabını aç",
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => showWardrobeSheet(context),
        // Sabit kutu: görsel yüklenirken yazılar kaymaz, dokunma alanı
        // pozdan bağımsız kalır.
        child: SizedBox(
          width: 88,
          height: 80,
          child: Align(
            alignment: Alignment.bottomRight,
            child: ExcludeSemantics(
              child: EquippedPace(mood: mood, size: 80),
            ),
          ),
        ),
      ),
    );
  }
}

/// Karşılama kartındaki avatar; dokununca profil açılır.
class _HeroAvatar extends ConsumerWidget {
  const _HeroAvatar({required this.level});

  final int level;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final style = ref.watch(profileStyleProvider);
    return Semantics(
      button: true,
      label: 'Profilim',
      child: GestureDetector(
        onTap: () {
          Haptics.tap();
          context.push('/profile');
        },
        child: PlayerAvatar.of(style, level: level, size: 52),
      ),
    );
  }
}

/// Seri rozeti: dokununca seri koruma sayfası açılır. Gün kaçırıldıysa ve
/// haklar seriyi koruyorsa alev yerine buz görünür.
class _StreakChip extends ConsumerWidget {
  const _StreakChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final display = ref.watch(streakDisplayProvider);
    final owned = ref.watch(freezeProvider).owned;
    final streak = display.streak;
    final protected = display.status == StreakStatus.protected;

    return Semantics(
      button: true,
      label: 'Seri koruma',
      child: GestureDetector(
        onTap: () => showFreezeSheet(context),
        child: _StreakGlow(
          // Seri yanarken çerçeve döner ve rozet parlar; koptuysa sakin kalır.
          active: streak > 0 && !protected,
          protected: protected,
          child: Container(
            // Dokunma alanı en az 48 dp (erişilebilirlik yönergesi).
            constraints: const BoxConstraints(minHeight: 48),
            alignment: Alignment.center,
            padding: const EdgeInsets.fromLTRB(14, 9, 14, 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                _streakRow(theme, streak, protected, owned),
                if (streak > 0) ...[
                  const SizedBox(height: 6),
                  _MilestoneBar(streak: streak, protected: protected),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _streakRow(ThemeData theme, int streak, bool protected, int owned) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (protected)
          const Icon(Icons.ac_unit_rounded, color: AppColors.ice)
        else
          PulsingFlame(active: streak > 0),
        const SizedBox(width: 6),
        // Seri arttığında yeni sayı aşağıdan kayarak gelir.
        AnimatedSwitcher(
          duration: Motion.medium,
          transitionBuilder: (child, animation) => SlideTransition(
            position: Tween(
              begin: const Offset(0, 0.6),
              end: Offset.zero,
            ).animate(animation),
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Text(
            '$streak gün',
            key: ValueKey(streak),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
        // Eldeki haklar küçük buz taneleriyle.
        for (var i = 0; i < owned; i++)
          const Padding(
            padding: EdgeInsets.only(left: 4),
            child: Icon(
              Icons.ac_unit_rounded,
              size: 14,
              color: AppColors.ice,
            ),
          ),
      ],
    );
  }
}

/// Seri rozetinin zemini: yanan seride dönen sıcak renkli çerçeve, nefes
/// alan ışıltı ve ara ara üstünden geçen parıltı.
class _StreakGlow extends StatefulWidget {
  const _StreakGlow({
    required this.active,
    required this.protected,
    required this.child,
  });

  final bool active;
  final bool protected;
  final Widget child;

  @override
  State<_StreakGlow> createState() => _StreakGlowState();
}

class _StreakGlowState extends State<_StreakGlow>
    with SingleTickerProviderStateMixin {
  static const _radius = 16.0;
  static const _fire = [
    AppColors.fire,
    AppColors.fireLight,
    AppColors.fireRed,
    AppColors.fire,
  ];

  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    // Seri sönükken de oluşturulur; dispose'da tembel oluşturma hata verir.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(_StreakGlow old) {
    super.didUpdateWidget(old);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // "Animasyonları azalt" açıksa çerçeve durur, parıltı kapanır.
    final still = MediaQuery.disableAnimationsOf(context);
    if (still && _controller.isAnimating) _controller.stop();
    if (!widget.active) {
      return Container(
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(_radius),
          border: Border.all(
            color: widget.protected
                ? AppColors.ice
                : Colors.white.withValues(alpha: 0.15),
          ),
        ),
        child: widget.child,
      );
    }

    final glowing = AnimatedBuilder(
      animation: _controller,
      child: widget.child,
      builder: (context, child) {
        final t = _controller.value;
        // Işıltı bir turda iki kez nefes alır.
        final breath = 0.5 + 0.5 * sin(t * 4 * pi);
        return CustomPaint(
          foregroundPainter: _RotatingBorderPainter(
            turn: t,
            colors: _fire,
            radius: _radius,
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.fire.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(_radius),
              boxShadow: [
                BoxShadow(
                  color: const Color(
                    0xFFFF9F1C,
                  ).withValues(alpha: 0.18 + 0.22 * breath),
                  blurRadius: 10 + 8 * breath,
                ),
              ],
            ),
            child: child,
          ),
        );
      },
    );

    if (still) return glowing;
    return glowing
        .animate(onPlay: Motion.loop())
        .shimmer(
          delay: 2.seconds,
          duration: 1200.ms,
          color: AppColors.fireGlow.withValues(alpha: 0.35),
        );
  }
}

class _RotatingBorderPainter extends CustomPainter {
  _RotatingBorderPainter({
    required this.turn,
    required this.colors,
    required this.radius,
  });

  final double turn;
  final List<Color> colors;
  final double radius;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..shader = SweepGradient(
        colors: colors,
        transform: GradientRotation(turn * 2 * pi),
      ).createShader(rect);
    canvas.drawRRect(
      RRect.fromRectAndRadius(rect.deflate(0.9), Radius.circular(radius)),
      paint,
    );
  }

  @override
  bool shouldRepaint(_RotatingBorderPainter old) => old.turn != turn;
}

/// Sıradaki seri hedefine doğru dolan ince bar.
class _MilestoneBar extends StatelessWidget {
  const _MilestoneBar({required this.streak, required this.protected});

  final int streak;
  final bool protected;

  @override
  Widget build(BuildContext context) {
    final m = streakMilestone(streak);
    final progress = (streak - m.from) / (m.to - m.from);
    final colors = protected
        ? const [AppColors.ice, AppColors.iceLight]
        : const [AppColors.fireRed, AppColors.fireLight];

    return Semantics(
      label: 'Sıradaki hedef ${m.to} gün',
      child: SizedBox(
        width: 72,
        height: 5,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(3),
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(color: Colors.white.withValues(alpha: 0.15)),
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: progress),
                duration: Motion.slow,
                curve: Motion.curve,
                builder: (context, v, _) => FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: v.clamp(0.0, 1.0),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: colors),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Seri koruma: haklar, harcanabilir XP ve satın alma.
Future<void> showFreezeSheet(BuildContext context) {
  Haptics.tap();
  return showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (_) => const _FreezeSheet(),
  );
}

class _FreezeSheet extends ConsumerStatefulWidget {
  const _FreezeSheet();

  @override
  ConsumerState<_FreezeSheet> createState() => _FreezeSheetState();
}

class _FreezeSheetState extends ConsumerState<_FreezeSheet> {
  var _busy = false;

  Future<void> _buy() async {
    setState(() => _busy = true);
    final ok = await buyFreeze(ref);
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Haptics.success();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    const ice = AppColors.ice;
    final freeze = ref.watch(freezeProvider);
    final display = ref.watch(streakDisplayProvider);
    final xp = ref.watch(gameProvider).value?.level.xp ?? 0;
    final balance = freeze.balance(xp);
    final full = freeze.owned >= maxFreezes;
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.7);

    final statusText = switch (display.status) {
      StreakStatus.done => 'Bugünü tamamladın, serin güvende.',
      StreakStatus.pending =>
        'Bugün bir ders bitirirsen serin ${display.streak + 1} güne çıkar.',
      StreakStatus.protected =>
        '${display.freezesNeeded} gün kaçırdın ama hakların serini koruyor. '
            'Bugün çalışırsan ${display.freezesNeeded} hak harcanır, serin '
            'sürer.',
      StreakStatus.broken =>
        'Serin koptu. Bugün çalışarak yeni bir seri başlat; bir dahaki sefere '
            'hakların seni korusun.',
    };

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
        child: Column(
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < maxFreezes; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6),
                    child: AnimatedContainer(
                      duration: Motion.medium,
                      width: 64,
                      height: 64,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: i < freeze.owned
                            ? ice.withValues(alpha: 0.2)
                            : theme.colorScheme.surfaceContainerHighest,
                        border: Border.all(
                          color: i < freeze.owned
                              ? ice
                              : theme.colorScheme.outlineVariant,
                          width: 2,
                        ),
                      ),
                      child: Icon(
                        Icons.ac_unit_rounded,
                        size: 32,
                        color: i < freeze.owned
                            ? ice
                            : theme.colorScheme.outline,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              'Seri koruma',
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Bir gün çalışamazsan hakkın o günü karşılar, serin bozulmaz. '
              'En fazla $maxFreezes hak tutabilirsin; hak, gün kaçırıp '
              'sonra çalıştığında kendiliğinden harcanır.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(color: muted),
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Row(
                children: [
                  Icon(
                    display.status == StreakStatus.protected
                        ? Icons.ac_unit_rounded
                        : Icons.local_fire_department_rounded,
                    color: display.status == StreakStatus.protected
                        ? ice
                        : AppColors.warning,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(statusText, style: theme.textTheme.bodyMedium),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _busy || !freeze.canBuy(xp) ? null : _buy,
                style: FilledButton.styleFrom(
                  minimumSize: const Size.fromHeight(52),
                ),
                icon: const Icon(Icons.ac_unit_rounded),
                label: Text(
                  full
                      ? 'Haklar dolu ($maxFreezes/$maxFreezes)'
                      : 'Hak al · $freezeCost XP',
                ),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              full
                  ? 'Harcanabilir XP: $balance'
                  : balance >= freezeCost
                  ? 'Harcanabilir XP: $balance. Seviyen düşmez.'
                  : 'Harcanabilir XP: $balance. '
                        '${freezeCost - balance} XP daha kazanınca hak '
                        'alabilirsin.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(color: muted),
            ),
          ],
        ),
      ),
    );
  }
}

/// Oyuncu seviyesi ve bir sonraki seviyeye kalan XP.
class _XpBar extends StatelessWidget {
  const _XpBar({required this.level});

  final PlayerLevel level;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: context.pace.accent,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Lv ${level.level}',
                style: theme.textTheme.labelLarge?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.graphite900,
                ),
              ),
            ),
            const SizedBox(width: 10),
            // Dar ekranda ve büyük yazıda unvan kısalır, XP her zaman görünür.
            Expanded(
              child: Text(
                level.title,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
            CountUpText(
              value: level.xp,
              suffix: ' XP',
              style: theme.textTheme.labelLarge?.copyWith(
                color: context.pace.accent,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
        const SizedBox(height: 10),
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: level.progress),
            duration: const Duration(milliseconds: 900),
            curve: Motion.curve,
            builder: (context, v, _) => Stack(
              children: [
                Container(
                  height: 10,
                  color: Colors.white.withValues(alpha: 0.12),
                ),
                FractionallySizedBox(
                      widthFactor: v.clamp(0.02, 1.0),
                      child: Container(
                        height: 10,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [context.pace.accentDim, context.pace.accent],
                          ),
                        ),
                      ),
                    )
                    .animate(onPlay: Motion.loop())
                    .shimmer(
                      delay: 2.seconds,
                      duration: 1200.ms,
                      color: Colors.white.withValues(alpha: 0.6),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Seviye ${level.level + 1} için ${level.xpToNext} XP',
          style: theme.textTheme.labelSmall?.copyWith(
            color: Colors.white.withValues(alpha: 0.65),
          ),
        ),
      ],
    );
  }
}

/// Bugünkü hedef: halka + sıradaki adıma yönlendiren görev listesi.
class _DailyGoalCard extends ConsumerWidget {
  const _DailyGoalCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final goal = ref.watch(dailyGoalProvider).value;
    if (goal == null) return const SizedBox.shrink();
    final next = goal.next;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          children: [
            Row(
              children: [
                _GoalRing(progress: goal.progress, complete: goal.complete),
                const SizedBox(width: 18),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Bugünkü hedefin',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      AnimatedSwitcher(
                        duration: Motion.medium,
                        child: Text(
                          goal.complete
                              ? 'Hepsi tamam! Serin güvende 🎉'
                              : '${goal.doneCount}/${goal.tasks.length} adım · '
                                    'sıradaki: ${next!.label.toLowerCase()}',
                          key: ValueKey(goal.doneCount),
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(
                              alpha: 0.7,
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            for (final task in goal.tasks)
              _GoalTaskRow(
                task: task,
                done: goal.done.contains(task),
                isNext: task == next,
              ),
          ],
        ),
      ),
    );
  }
}

class _GoalTaskRow extends ConsumerWidget {
  const _GoalTaskRow({
    required this.task,
    required this.done,
    required this.isNext,
  });

  final DailyTask task;
  final bool done;
  final bool isNext;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final accent = theme.colorScheme.primary;

    final row = PressableScale(
      borderRadius: BorderRadius.circular(14),
      onTap: () async {
        await context.push(task.route);
        // Satır bu arada listeden kalkmış olabilir; ölü ref kullanılamaz.
        if (!context.mounted) return;
        ref.invalidate(flashcardSummaryProvider);
        ref.invalidate(gameProvider);
      },
      child: AnimatedContainer(
        duration: Motion.medium,
        margin: const EdgeInsets.only(top: 8),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          color: isNext
              ? accent.withValues(alpha: 0.1)
              : theme.colorScheme.surfaceContainerHighest.withValues(
                  alpha: 0.4,
                ),
          border: Border.all(
            color: isNext ? accent : Colors.transparent,
            width: 1.5,
          ),
        ),
        child: Row(
          children: [
            Icon(task.icon, size: 20, color: done ? AppColors.success : accent),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                task.label,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: isNext ? FontWeight.w700 : FontWeight.w500,
                  decoration: done ? TextDecoration.lineThrough : null,
                  color: done
                      ? theme.colorScheme.onSurface.withValues(alpha: 0.5)
                      : null,
                ),
              ),
            ),
            if (isNext)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                  color: accent,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'SIRADAKİ',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onPrimary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            const SizedBox(width: 8),
            AnimatedSwitcher(
              duration: Motion.medium,
              transitionBuilder: (child, a) =>
                  ScaleTransition(scale: a, child: child),
              child: Icon(
                done ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
                key: ValueKey(done),
                color: done ? AppColors.success : theme.colorScheme.outline,
              ),
            ),
          ],
        ),
      ),
    );

    return isNext
        ? row
              .animate(onPlay: Motion.loop(reverse: true))
              .scaleXY(
                begin: 1,
                end: 1.015,
                duration: 1100.ms,
                curve: Curves.easeInOut,
              )
        : row;
  }
}

/// Animasyonla dolan ilerleme halkası.
class _GoalRing extends StatelessWidget {
  const _GoalRing({required this.progress, required this.complete});

  final double progress;
  final bool complete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final color = complete
        ? AppColors.success
        : (isDark ? context.pace.accent : context.pace.accentDark);

    final ring = TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: progress),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutBack,
      builder: (context, v, _) => SizedBox(
        width: 64,
        height: 64,
        child: CustomPaint(
          painter: _RingPainter(
            progress: v,
            color: color,
            track: theme.colorScheme.surfaceContainerHighest,
          ),
          child: Center(
            child: complete
                ? const Icon(
                    Icons.emoji_events_rounded,
                    color: AppColors.success,
                    size: 28,
                  )
                : Text(
                    '%${(v * 100).round().clamp(0, 100)}',
                    style: theme.textTheme.labelLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
          ),
        ),
      ),
    );

    return complete
        ? ring
              .animate(onPlay: Motion.loop(reverse: true))
              .scaleXY(begin: 1, end: 1.08, duration: 900.ms)
        : ring;
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter({
    required this.progress,
    required this.color,
    required this.track,
  });

  final double progress;
  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    const stroke = 7.0;
    final rect = Offset.zero & size;
    final arcRect = rect.deflate(stroke / 2);
    final base = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..color = track;
    canvas.drawArc(arcRect, 0, 2 * pi, false, base);

    if (progress <= 0) return;
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..shader = SweepGradient(
        startAngle: -pi / 2,
        endAngle: 3 * pi / 2,
        colors: [color.withValues(alpha: 0.6), color],
        transform: const GradientRotation(-pi / 2),
      ).createShader(rect);
    canvas.drawArc(
      arcRect,
      -pi / 2,
      2 * pi * progress.clamp(0, 1),
      false,
      paint,
    );
  }

  @override
  bool shouldRepaint(_RingPainter old) =>
      old.progress != progress || old.color != color || old.track != track;
}

/// Haftanın 7 günü tek satırda; dokununca Program sekmesine geçer.
class _WeekStrip extends StatelessWidget {
  const _WeekStrip({required this.week});

  final WeekPlan week;

  static const _initials = ['Pt', 'Sa', 'Ça', 'Pe', 'Cu', 'Ct', 'Pz'];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final accent = isDark ? context.pace.accent : context.pace.accentDark;
    final now = clock.now();
    final todayIndex = now.weekday - DateTime.monday;
    final monday = mondayOf(now);
    final byIndex = {for (final d in week.days) d.dayIndex: d};

    // Her gün ayrı bir kutucuk: dokununca o günün konusu açılır.
    return Row(
      children: [
        for (var i = 0; i < 7; i++) ...[
          if (i > 0) const SizedBox(width: 6),
          Expanded(
            child:
                _DayTile(
                      initial: _initials[i],
                      dayName: AppConstants.weekdayNames[i],
                      date: DateTime(
                        monday.year,
                        monday.month,
                        monday.day + i,
                      ).day,
                      done: byIndex[i]?.status == 'completed',
                      today: i == todayIndex,
                      past: i < todayIndex,
                      accent: accent,
                      onTap: byIndex[i] == null
                          ? null
                          : () => showPlanDayDetails(context, byIndex[i]!),
                    )
                    .animate(delay: (60 * i).ms)
                    .scale(
                      begin: const Offset(0.6, 0.6),
                      duration: Motion.medium,
                      curve: Curves.easeOutBack,
                    ),
          ),
        ],
      ],
    );
  }
}

/// Haftanın bir günü: gün kısaltması, tarih ve durum işareti.
class _DayTile extends StatelessWidget {
  const _DayTile({
    required this.initial,
    required this.dayName,
    required this.date,
    required this.done,
    required this.today,
    required this.past,
    required this.accent,
    required this.onTap,
  });

  final String initial;
  final String dayName;
  final int date;
  final bool done;
  final bool today;
  final bool past;
  final Color accent;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final muted = theme.colorScheme.onSurface.withValues(alpha: 0.55);

    final Color fill;
    final Color fg;
    if (done) {
      fill = AppColors.success.withValues(alpha: 0.16);
      fg = theme.brightness == Brightness.dark
          ? AppColors.success
          : AppColors.successDark;
    } else if (today) {
      fill = accent.withValues(alpha: 0.14);
      fg = accent;
    } else {
      fill = theme.colorScheme.surfaceContainer;
      fg = past ? muted : theme.colorScheme.onSurface;
    }

    final icon = done
        ? Icons.check_rounded
        : today
        ? Icons.play_arrow_rounded
        : past
        ? Icons.remove_rounded
        : Icons.circle_outlined;

    return Semantics(
      button: onTap != null,
      label:
          '$dayName $date, '
          '${done ? 'tamamlandı' : today ? 'bugün' : past ? 'kaçırıldı' : 'yakında'}',
      excludeSemantics: true,
      child: PressableScale(
        onTap: onTap,
        borderRadius: BorderRadius.circular(14),
        child: Ink(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: fill,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: today ? accent : theme.colorScheme.outlineVariant,
              width: today ? 2 : 1,
            ),
          ),
          child: Column(
            children: [
              Text(
                initial,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: today ? accent : muted,
                  fontWeight: today ? FontWeight.w800 : null,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                '$date',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: fg,
                ),
              ),
              const SizedBox(height: 4),
              Icon(icon, size: 14, color: fg),
            ],
          ),
        ),
      ),
    );
  }
}

/// Dersin dışındaki çalışma alanlarına kısayollar.
class _PracticeGrid extends ConsumerWidget {
  const _PracticeGrid();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cards = ref.watch(flashcardSummaryProvider).value;
    final rally = ref.watch(matchRecordsProvider);
    final roleplay = ref.watch(roleplayRecordsProvider);
    final due = cards?.due ?? 0;

    Future<void> open(String route) async {
      await context.push(route);
      if (!context.mounted) return;
      ref.invalidate(flashcardSummaryProvider);
      ref.invalidate(gameProvider);
    }

    final tiles = [
      _PracticeTile(
        icon: Icons.style_rounded,
        title: 'Flash kartlar',
        subtitle: due > 0
            ? '$due kart seni bekliyor'
            : cards == null || cards.total == 0
            ? 'Ders bitirince dolar'
            : 'Bugünlük tamam',
        badge: due > 0 ? '$due' : null,
        onTap: () => open('/flashcards'),
      ),
      _PracticeTile(
        icon: Icons.auto_stories_rounded,
        title: 'Günün hikayesi',
        subtitle: 'Oku ve anla',
        onTap: () => open('/story'),
      ),
      _PracticeTile(
        icon: Icons.record_voice_over_rounded,
        title: 'Konuşma',
        subtitle: 'Söyle, puanını gör',
        onTap: () => open('/speaking'),
      ),
      _PracticeTile(
        icon: Icons.hearing_rounded,
        title: 'Dinle ve yaz',
        subtitle: 'Kulağını eğit',
        onTap: () => open('/dictation'),
      ),
      _PracticeTile(
        icon: Icons.edit_note_rounded,
        title: 'Hata defterim',
        subtitle: 'Pekişmeyenler',
        onTap: () => open('/mistakes'),
      ),
      _PracticeTile(
        icon: Icons.assessment_rounded,
        title: 'Haftalık rapor',
        subtitle: 'Seviye önerisi',
        onTap: () => open('/review'),
      ),
    ];

    // Sabit en-boy oranı büyük yazı boyutunda kutucuğu taşırıyordu;
    // yükseklik yazı ölçeğiyle birlikte büyür.
    final scaler = MediaQuery.textScalerOf(context);
    return Column(
      children: [
        GridView(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 2,
            mainAxisSpacing: 12,
            crossAxisSpacing: 12,
            mainAxisExtent: 84 + scaler.scale(56),
          ),
          children: [
            for (final (i, tile) in tiles.indexed)
              tile
                  .animate(delay: Motion.stagger * i)
                  .fadeIn(duration: Motion.medium)
                  .scale(
                    begin: const Offset(0.9, 0.9),
                    curve: Curves.easeOutBack,
                  ),
          ],
        ),
        for (final (i, banner) in [
          _FeatureBanner(
            icon: Icons.forum_rounded,
            color: AppColors.iceDeep,
            title: 'AI ile sohbet',
            subtitle: roleplay.completed > 0
                ? '${roleplay.completed} sohbet · ${roleplay.goalScenarios.length}'
                      ' görev başarıldı'
                : 'Kafede, otelde, iş görüşmesinde konuş',
            onTap: () => open('/roleplay'),
          ),
          _FeatureBanner(
            icon: Icons.bolt_rounded,
            color: AppColors.warning,
            title: 'Kelime Rallisi',
            subtitle: rally.games > 0
                ? 'Rekorun: ${rally.bestScore} puan'
                : '60 saniyede eşleştir, rekor kır',
            onTap: () => open('/match'),
          ),
        ].indexed) ...[
          const SizedBox(height: 12),
          banner
              .animate(delay: Motion.stagger * (tiles.length + i))
              .fadeIn(duration: Motion.medium)
              .slideY(begin: 0.15, curve: Motion.curve),
        ],
      ],
    );
  }
}

/// Öne çıkan pratik girişi (sohbet, ralli): renkli, tam genişlikte kart.
class _FeatureBanner extends StatelessWidget {
  const _FeatureBanner({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return PressableScale(
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(
            colors: [
              color.withValues(alpha: 0.22),
              theme.colorScheme.surfaceContainer,
            ],
          ),
          border: Border.all(color: color.withValues(alpha: 0.5)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 22, color: color),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    subtitle,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(
                        alpha: 0.65,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Icon(
              Icons.chevron_right_rounded,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ],
        ),
      ),
    );
  }
}

class _PracticeTile extends StatelessWidget {
  const _PracticeTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.badge,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return PressableScale(
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: theme.colorScheme.outlineVariant),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: (isDark ? context.pace.accent : context.pace.accentDark)
                        .withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, size: 20, color: theme.colorScheme.primary),
                ),
                const Spacer(),
                if (badge != null)
                  Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 3,
                        ),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.primary,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          badge!,
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: theme.colorScheme.onPrimary,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      )
                      .animate(onPlay: Motion.loop(reverse: true))
                      .scaleXY(begin: 1, end: 1.12, duration: 800.ms),
              ],
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              subtitle,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _OfflineBadge extends StatelessWidget {
  const _OfflineBadge();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Row(
        children: [
          Icon(Icons.cloud_off, size: 18, color: theme.colorScheme.outline),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Çevrimdışı plan — Gemini\'ye ulaşılamadığı için hazır program kullanılıyor.',
              style: theme.textTheme.bodySmall,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayCard extends StatelessWidget {
  const _TodayCard({
    required this.day,
    required this.dailyMinutes,
    required this.lesson,
    required this.onStudy,
    required this.onComplete,
  });

  final WeeklyPlanDay day;
  final int dailyMinutes;

  /// Bugünkü ders kaydı; henüz üretilmediyse null.
  final Lesson? lesson;

  final VoidCallback onStudy;
  final VoidCallback onComplete;

  /// Tamamlanmış gün için skor/süre özeti.
  ///
  /// Gün elle işaretlenmişse ders kaydı ve skor olmaz; o durumda düz mesaj.
  String _completedSummary() {
    final score = lesson?.score;
    if (score == null) return 'Bugünkü çalışman tamam. Yarın görüşürüz!';

    final minutes = ((lesson?.durationSeconds ?? 0) / 60).ceil();
    final duration = minutes > 0 ? ' · $minutes dk' : '';
    return 'Ders tamam · %${score.round()}$duration';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final done = day.status == 'completed';
    // Ders başlanmış ama bitmemişse buton "devam et" der.
    final inProgress = lesson != null && !lesson!.completed;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  'BUGÜN',
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 1.2,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const Spacer(),
                Text(
                  '$dailyMinutes dk',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              day.grammarTopic,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  Icons.style_outlined,
                  size: 18,
                  color: theme.colorScheme.outline,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    day.vocabTheme,
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            if (done) ...[
              Row(
                children: [
                  const Icon(Icons.check_circle, color: AppColors.success)
                      .animate()
                      .scale(duration: Motion.slow, curve: Curves.elasticOut),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      _completedSummary(),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onStudy,
                  child: const Text('Dersi tekrar aç'),
                ),
              ),
            ] else ...[
              FilledButton.icon(
                    onPressed: onStudy,
                    icon: Icon(
                      inProgress ? Icons.play_arrow : Icons.school_outlined,
                    ),
                    label: Text(inProgress ? 'Derse devam et' : 'Bugünü çalış'),
                  )
                  // Ara ara geçen parıltı asıl eyleme dikkat çeker.
                  .animate(onPlay: Motion.loop())
                  .shimmer(
                    delay: 2500.ms,
                    duration: 1200.ms,
                    color: Colors.white.withValues(alpha: 0.45),
                  ),
              // Ders üretilemediği ya da başka bir yerde çalışıldığı durumlar
              // için elle işaretleme yolu açık kalıyor.
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onComplete,
                  child: const Text('Çalışmadan tamamlandı işaretle'),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _EmptyPlanCard extends ConsumerWidget {
  const _EmptyPlanCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Bu hafta için henüz plan yok',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 8),
            const Text('Yeni bir haftalık program oluşturalım.'),
            const SizedBox(height: 18),
            FilledButton(
              onPressed: () => ref.read(weekPlanProvider.notifier).regenerate(),
              child: const Text('Programımı oluştur'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Profil yokken ana ekrana düşülürse (ör. prefs sıfırlanmışsa) çıkış yolu.
class _NoProfileView extends StatelessWidget {
  const _NoProfileView();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Profilini henüz oluşturmadın.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: () => context.go('/onboarding'),
              child: const Text('Kuruluma başla'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  const _ErrorView({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 40,
              color: Theme.of(context).colorScheme.error,
            ),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
          ],
        ),
      ),
    );
  }
}
