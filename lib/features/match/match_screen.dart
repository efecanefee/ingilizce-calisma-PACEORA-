import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/error_view.dart';
import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/match_game.dart';
import '../../data/providers.dart';

/// Kelime Rallisi: 60 saniyelik eşleştirme turu.
class MatchScreen extends ConsumerWidget {
  const MatchScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final deck = ref.watch(matchDeckProvider);
    return Scaffold(
      appBar: AppBar(title: const Text('Kelime Rallisi')),
      body: switch (deck) {
        AsyncError(:final error) => ErrorView(
          error: error,
          onRetry: () => ref.invalidate(matchDeckProvider),
        ),
        AsyncData(:final value) when value.length < matchMinPairs =>
          _NotEnoughCards(count: value.length),
        AsyncData(:final value) => _MatchGame(deck: value),
        _ => const Center(child: CircularProgressIndicator()),
      },
    );
  }
}

class _NotEnoughCards extends StatelessWidget {
  const _NotEnoughCards({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Küçük ekranda ve büyük yazıda sığmayabilir; kaydırılabilir.
    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.bolt_rounded,
              size: 56,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'Rallide yarışmak için en az $matchMinPairs kelime gerekli',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Destende $count kelime var. Ders bitirerek ya da günün '
              'hikayesinde kelimelere dokunup havuzuna ekleyerek desteni '
              'doldurabilirsin.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium,
            ),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: () => context.pushReplacement('/story'),
              icon: const Icon(Icons.auto_stories_rounded),
              label: const Text('Günün hikayesine git'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _Phase { intro, playing, finished }

class _MatchGame extends ConsumerStatefulWidget {
  const _MatchGame({required this.deck});

  final List<MatchPair> deck;

  @override
  ConsumerState<_MatchGame> createState() => _MatchGameState();
}

class _MatchGameState extends ConsumerState<_MatchGame> {
  static const _tick = Duration(milliseconds: 100);

  var _phase = _Phase.intro;
  late MatchBoard _board;
  Timer? _timer;
  var _remaining = matchRoundDuration;
  MatchSummary? _summary;

  /// Yanlış eşleşmede kısa süre kırmızı yanan kutucuklar.
  final _wrong = <(MatchSide, int)>{};

  /// Kutucukların yeniden çizim anahtarı: yanlışta sarsıntıyı yeniden başlatır.
  var _shakeId = 0;

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _board = MatchBoard(widget.deck);
      _remaining = matchRoundDuration;
      _summary = null;
      _wrong.clear();
      _phase = _Phase.playing;
    });
    // Stopwatch yerine sayaç: testlerde sahte zamanla ilerleyebilsin.
    _timer = Timer.periodic(_tick, (_) {
      final next = _remaining - _tick;
      if (next <= Duration.zero) {
        _finish();
      } else {
        setState(() => _remaining = next);
      }
    });
  }

  Future<void> _finish() async {
    _timer?.cancel();
    _timer = null;
    setState(() {
      _remaining = Duration.zero;
      _phase = _Phase.finished;
    });
    final summary = await finishMatchRound(ref, _board);
    if (!mounted) return;
    if (summary.isNewBest) Haptics.success();
    setState(() => _summary = summary);
  }

  void _tap(MatchSide side, int row) {
    if (_phase != _Phase.playing) return;
    final cell = (side, row);
    final selectedBefore = _board.selected;
    final outcome = _board.tap(side, row);
    switch (outcome) {
      case MatchOutcome.correct:
        Haptics.success();
        setState(() {});
        Future<void>.delayed(const Duration(milliseconds: 220), () {
          if (!mounted || _phase != _Phase.playing) return;
          setState(_board.refill);
        });
      case MatchOutcome.wrong:
        Haptics.tap();
        final cells = {cell, ?selectedBefore};
        setState(() {
          _wrong.addAll(cells);
          _shakeId++;
        });
        Future<void>.delayed(const Duration(milliseconds: 450), () {
          if (mounted) setState(() => _wrong.removeAll(cells));
        });
      case MatchOutcome.selected:
        Haptics.tap();
        setState(() {});
      case MatchOutcome.ignored:
        setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: Motion.medium,
      child: switch (_phase) {
        _Phase.intro => _Intro(
          key: const ValueKey('intro'),
          records: ref.watch(matchRecordsProvider),
          deckSize: widget.deck.length,
          onStart: _start,
        ),
        _Phase.playing => _buildBoard(context),
        _Phase.finished => _Results(
          key: const ValueKey('results'),
          summary: _summary,
          confused: [
            for (final p in widget.deck)
              if (_board.confusedIds.contains(p.id)) p,
          ],
          onAgain: _start,
          onDone: () => context.pop(),
        ),
      },
    );
  }

  Widget _buildBoard(BuildContext context) {
    final theme = Theme.of(context);
    final seconds = (_remaining.inMilliseconds / 1000).ceil();
    final fraction =
        _remaining.inMilliseconds / matchRoundDuration.inMilliseconds;
    final urgent = seconds <= 10;
    final barColor = urgent ? AppColors.error : theme.colorScheme.primary;

    Widget column(MatchSide side) => Expanded(
      child: Column(
        children: [
          for (var row = 0; row < matchBoardRows; row++)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 5),
                child: _Tile(
                  key: ValueKey((side, _board.at(side, row).id)),
                  text: side == MatchSide.word
                      ? _board.at(side, row).word
                      : _board.at(side, row).meaning,
                  state: _board.cleared.contains((side, row))
                      ? _TileState.correct
                      : _wrong.contains((side, row))
                      ? _TileState.wrong
                      : _board.selected == (side, row)
                      ? _TileState.selected
                      : _TileState.idle,
                  shakeId: _wrong.contains((side, row)) ? _shakeId : 0,
                  onTap: () => _tap(side, row),
                ),
              ),
            ),
        ],
      ),
    );

    return Padding(
      key: const ValueKey('board'),
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
      child: Column(
        children: [
          Row(
            children: [
              Icon(Icons.timer_outlined, size: 20, color: barColor),
              const SizedBox(width: 6),
              Text(
                '$seconds sn',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: urgent ? AppColors.error : null,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const Spacer(),
              AnimatedSwitcher(
                duration: Motion.fast,
                transitionBuilder: (child, animation) =>
                    ScaleTransition(scale: animation, child: child),
                child: _board.multiplier > 1
                    ? Container(
                        key: ValueKey(_board.multiplier),
                        margin: const EdgeInsets.only(right: 10),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.warning,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'x${_board.multiplier}',
                          style: theme.textTheme.labelLarge?.copyWith(
                            color: AppColors.graphite900,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
              Text(
                '${_board.score}',
                key: const ValueKey('match-score'),
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w900,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              const SizedBox(width: 4),
              Text('puan', style: theme.textTheme.labelMedium),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: fraction,
              minHeight: 6,
              color: barColor,
              backgroundColor: theme.colorScheme.surfaceContainerHighest,
            ),
          ),
          const SizedBox(height: 14),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                column(MatchSide.word),
                const SizedBox(width: 12),
                column(MatchSide.meaning),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

enum _TileState { idle, selected, correct, wrong }

class _Tile extends StatelessWidget {
  const _Tile({
    super.key,
    required this.text,
    required this.state,
    required this.shakeId,
    required this.onTap,
  });

  final String text;
  final _TileState state;
  final int shakeId;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final (bg, border) = switch (state) {
      _TileState.idle => (
        theme.colorScheme.surfaceContainer,
        theme.colorScheme.outlineVariant,
      ),
      _TileState.selected => (
        theme.colorScheme.primary.withValues(alpha: 0.16),
        theme.colorScheme.primary,
      ),
      _TileState.correct => (
        AppColors.success.withValues(alpha: 0.22),
        AppColors.success,
      ),
      _TileState.wrong => (
        AppColors.error.withValues(alpha: 0.2),
        AppColors.error,
      ),
    };

    Widget tile = GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: Motion.fast,
        alignment: Alignment.center,
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: border,
            width: state == _TileState.idle ? 1 : 2,
          ),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );

    // Ekran okuyucu: metin, durum ve dokunma eylemi tek düğüm olarak.
    tile = Semantics(
      button: true,
      selected: state == _TileState.selected,
      label: switch (state) {
        _TileState.correct => '$text, doğru',
        _TileState.wrong => '$text, yanlış',
        _ => text,
      },
      onTap: onTap,
      excludeSemantics: true,
      child: tile,
    );

    // Ağaç yapısı hep aynı kalır; yalnızca yanlışta sarsıntı oynar. Yapı
    // değişseydi aşağıdaki giriş animasyonu her yanlışta yeniden oynardı.
    tile = tile
        .animate(key: ValueKey(shakeId), autoPlay: shakeId > 0)
        .shakeX(hz: 6, amount: 5, duration: 350.ms);
    // Yeni gelen çift hafifçe büyüyerek belirir.
    return tile
        .animate()
        .fadeIn(duration: Motion.fast)
        .scale(begin: const Offset(0.92, 0.92), duration: Motion.fast);
  }
}

class _Intro extends StatelessWidget {
  const _Intro({
    super.key,
    required this.records,
    required this.deckSize,
    required this.onStart,
  });

  final MatchRecords records;
  final int deckSize;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    Widget rule(IconData icon, String text) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: theme.colorScheme.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: theme.textTheme.bodyMedium)),
        ],
      ),
    );

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.bolt_rounded,
              size: 56,
              color: AppColors.warning,
            ),
          ).animate().scale(curve: Curves.elasticOut, duration: Motion.slow),
        ),
        const SizedBox(height: 20),
        Text(
          '${matchRoundDuration.inSeconds} saniyede kaç kelime?',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Destendeki $deckSize kelimeyle yarışıyorsun.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 24),
        rule(
          Icons.touch_app_outlined,
          'Soldan İngilizce kelimeye, sağdan Türkçe karşılığına dokun.',
        ),
        rule(
          Icons.local_fire_department_outlined,
          'Üst üste doğrular çarpanı artırır: 4. eşleşmeden sonra x2, '
          '7.\'den sonra x3.',
        ),
        rule(
          Icons.replay_rounded,
          'Karıştırdığın kelimeler bugünkü flash kart tekrarına eklenir.',
        ),
        const SizedBox(height: 16),
        if (records.games > 0)
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Row(
                children: [
                  _Stat(label: 'Rekor', value: '${records.bestScore}'),
                  _Stat(
                    label: 'En çok eşleşme',
                    value: '${records.bestMatches}',
                  ),
                  _Stat(label: 'Oyun', value: '${records.games}'),
                ],
              ),
            ),
          ),
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onStart,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Başla'),
        ),
      ],
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Expanded(
      child: Column(
        children: [
          Text(
            value,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
            ),
          ),
        ],
      ),
    );
  }
}

class _Results extends StatelessWidget {
  const _Results({
    super.key,
    required this.summary,
    required this.confused,
    required this.onAgain,
    required this.onDone,
  });

  /// Kayıt bitene kadar null.
  final MatchSummary? summary;
  final List<MatchPair> confused;
  final VoidCallback onAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final s = summary;
    if (s == null) return const Center(child: CircularProgressIndicator());

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 16, 24, 32),
      children: [
        Text(
          'Süre doldu!',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleMedium?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
          ),
        ),
        const SizedBox(height: 8),
        Center(
          child: CountUpText(
            value: s.score,
            style: theme.textTheme.displayMedium?.copyWith(
              fontWeight: FontWeight.w900,
              color: theme.colorScheme.primary,
            ),
          ),
        ),
        Text(
          'puan',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelLarge,
        ),
        if (s.isNewBest) ...[
          const SizedBox(height: 12),
          Center(
            child: Chip(
              avatar: const Icon(
                Icons.emoji_events_rounded,
                color: AppColors.warning,
              ),
              label: const Text('Yeni rekor!'),
            ).animate().scale(curve: Curves.elasticOut, duration: Motion.slow),
          ),
        ],
        const SizedBox(height: 20),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 14),
            child: Row(
              children: [
                _Stat(label: 'Eşleşme', value: '${s.matches}'),
                _Stat(label: 'İsabet', value: '%${s.accuracy}'),
                _Stat(label: 'En uzun seri', value: '${s.bestCombo}'),
                _Stat(label: 'XP', value: '+${s.xp}'),
              ],
            ),
          ),
        ),
        if (confused.isNotEmpty) ...[
          const SizedBox(height: 20),
          Text(
            'KARIŞTIRDIKLARIN',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Bugünkü flash kart tekrarına eklendi.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 8),
          for (final p in confused)
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              title: Text(
                p.word,
                style: const TextStyle(fontWeight: FontWeight.w700),
              ),
              trailing: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 180),
                child: Text(
                  p.meaning,
                  textAlign: TextAlign.end,
                  style: theme.textTheme.bodyMedium,
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onAgain,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Tekrar oyna'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onDone, child: const Text('Bitir')),
      ],
    );
  }
}
