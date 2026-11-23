import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import 'constants.dart';
import 'mascot.dart';
import 'motion.dart';
import 'theme.dart';

/// Tanıtım turu bekliyor mu? Onboarding bitince açılır, tur bitince ya da
/// atlanınca kapanır. Ayarlar > "Tanıtımı yeniden izle" tekrar açar.
///
/// Güncelleme alan eski kullanıcılarda bayrak yoktur; tur yalnızca ilk
/// kurulumda kendiliğinden çıkar.
class TourNotifier extends Notifier<bool> {
  @override
  bool build() =>
      ref
          .watch(sharedPreferencesProvider)
          .getBool(AppConstants.prefTourPending) ??
      false;

  Future<void> start() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(AppConstants.prefTourPending, true);
    state = true;
  }

  Future<void> finish() async {
    await ref
        .read(sharedPreferencesProvider)
        .setBool(AppConstants.prefTourPending, false);
    state = false;
  }
}

final tourProvider = NotifierProvider<TourNotifier, bool>(TourNotifier.new);

/// Turun bir adımı: hangi sekme gösterilir, Pace ne der.
class TourStep {
  const TourStep({
    required this.tab,
    required this.title,
    required this.body,
    this.mood = PaceMood.run,
  });

  /// Alt çubuktaki sekme sırası; null ise ok çizilmez (karşılama/kapanış).
  final int? tab;
  final String title;
  final String body;
  final PaceMood mood;
}

const tourSteps = <TourStep>[
  TourStep(
    tab: null,
    mood: PaceMood.cheer,
    title: 'Merhaba, ben Pace!',
    body:
        'İngilizce yolculuğunda koşu arkadaşınım. Sana uygulamayı bir '
        'dakikada gezdireyim.',
  ),
  TourStep(
    tab: 0,
    title: 'Bugün',
    body:
        'Her gün seni günün dersi bekler. Serini, haftanı ve beni de '
        'burada görürsün.',
  ),
  TourStep(
    tab: 1,
    mood: PaceMood.study,
    title: 'Pratik',
    body:
        'Kartlar, hikayeler, konuşma, dikte, rol yapma ve Kelime Rallisi. '
        'Dersten sonra canın isterse ekstra çalış.',
  ),
  TourStep(
    tab: 2,
    title: 'Program',
    body:
        'Programın bugün başladı; her 7 günde bir seviyene göre yenilenir. '
        'Ay görünümünde hangi gün çalıştığını görürsün.',
  ),
  TourStep(
    tab: 3,
    mood: PaceMood.surprised,
    title: 'İlerleme',
    body:
        'Seviyen, rozetlerin, hata defterin ve haftalık raporun burada. '
        'Ne kadar yol aldığına şaşıracaksın!',
  ),
  TourStep(
    tab: 4,
    title: 'Ayarlar',
    body:
        'Günlük süreni, temayı ve hatırlatma saatini buradan değiştirirsin. '
        'Bu turu da oradan yeniden izleyebilirsin.',
  ),
  TourStep(
    tab: 0,
    mood: PaceMood.cheer,
    title: 'Hazırsın!',
    body: 'Hadi ilk dersine başlayalım. Ben hep buradayım.',
  ),
];

/// Ekranın üstüne çıkan tanıtım: karartılmış zemin, Pace ve konuşma balonu.
///
/// Her adımda ilgili sekmeye geçilir ([onTab]); balonun oku alt çubuktaki o
/// sekmeyi gösterir.
class WelcomeTour extends ConsumerStatefulWidget {
  const WelcomeTour({super.key, required this.onTab, this.tabCount = 5});

  final ValueChanged<int> onTab;
  final int tabCount;

  @override
  ConsumerState<WelcomeTour> createState() => _WelcomeTourState();
}

class _WelcomeTourState extends ConsumerState<WelcomeTour> {
  var _index = 0;

  TourStep get _step => tourSteps[_index];
  bool get _last => _index == tourSteps.length - 1;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _showTab());
  }

  void _showTab() {
    final tab = _step.tab;
    if (tab != null && mounted) widget.onTab(tab);
  }

  void _next() {
    Haptics.tap();
    if (_last) {
      _finish();
      return;
    }
    setState(() => _index++);
    _showTab();
  }

  void _back() {
    Haptics.tap();
    setState(() => _index--);
    _showTab();
  }

  void _finish() {
    widget.onTab(0);
    ref.read(tourProvider.notifier).finish();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final step = _step;
    final width = MediaQuery.sizeOf(context).width;
    final tab = step.tab;
    // Okun yatay konumu: sekmenin ortası.
    final arrowX = tab == null ? null : (width / widget.tabCount) * (tab + 0.5);

    return Positioned.fill(
      child: Material(
        color: Colors.black.withValues(alpha: 0.55),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              // EquippedPace'in kendi `animate` alanı uzantıyı gölgelediği
              // için sarmalanır.
              SizedBox(child: EquippedPace(mood: step.mood, size: 132))
                  .animate(key: ValueKey(_index))
                  .slideY(
                    begin: 0.25,
                    duration: Motion.medium,
                    curve: Curves.easeOutBack,
                  )
                  .fadeIn(duration: Motion.fast),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
                child: _Bubble(
                  key: ValueKey('bubble$_index'),
                  step: step,
                  progress: '${_index + 1}/${tourSteps.length}',
                  last: _last,
                  onNext: _next,
                  onBack: _index == 0 ? null : _back,
                  onSkip: _last ? null : _finish,
                ),
              ),
              // Ok: balondan alt çubuktaki sekmeye.
              SizedBox(
                height: 18,
                width: double.infinity,
                child: arrowX == null
                    ? null
                    : CustomPaint(
                        painter: _ArrowPainter(
                          x: arrowX,
                          color: theme.colorScheme.surfaceContainerHigh,
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

class _Bubble extends StatelessWidget {
  const _Bubble({
    super.key,
    required this.step,
    required this.progress,
    required this.last,
    required this.onNext,
    required this.onBack,
    required this.onSkip,
  });

  final TourStep step;
  final String progress;
  final bool last;
  final VoidCallback onNext;
  final VoidCallback? onBack;
  final VoidCallback? onSkip;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    return Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 12),
          decoration: BoxDecoration(
            color: theme.colorScheme.surfaceContainerHigh,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      step.title,
                      style: theme.textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  Text(
                    progress,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(step.body, style: theme.textTheme.bodyLarge),
              const SizedBox(height: 10),
              Row(
                children: [
                  if (onSkip != null)
                    TextButton(onPressed: onSkip, child: const Text('Atla')),
                  const Spacer(),
                  if (onBack != null)
                    IconButton(
                      tooltip: 'Geri',
                      onPressed: onBack,
                      icon: const Icon(Icons.arrow_back_rounded),
                    ),
                  const SizedBox(width: 4),
                  FilledButton(
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 44),
                      backgroundColor: isDark
                          ? context.pace.accent
                          : context.pace.accentDark,
                      foregroundColor: isDark
                          ? AppColors.graphite900
                          : Colors.white,
                    ),
                    onPressed: onNext,
                    child: Text(last ? 'Başla' : 'İleri'),
                  ),
                ],
              ),
            ],
          ),
        )
        .animate()
        .fadeIn(duration: Motion.fast)
        .slideY(begin: 0.08, duration: Motion.medium, curve: Motion.curve);
  }
}

class _ArrowPainter extends CustomPainter {
  _ArrowPainter({required this.x, required this.color});

  final double x;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()
      ..moveTo(x - 12, 0)
      ..lineTo(x + 12, 0)
      ..lineTo(x, size.height)
      ..close();
    canvas.drawPath(path, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_ArrowPainter old) => old.x != x || old.color != color;
}
