import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../app/motion.dart';
import '../../app/speak_button.dart';
import '../../app/theme.dart';
import '../../data/providers.dart';
import '../../data/roleplay.dart';
import '../../data/speech_service.dart';

/// Senaryo seçimi.
class RoleplayListScreen extends ConsumerWidget {
  const RoleplayListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final records = ref.watch(roleplayRecordsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('AI ile sohbet')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
        children: [
          Text(
            'Bir durum seç, karşındaki karakterle İngilizce konuş. Her '
            'mesajından sonra küçük bir düzeltme notu alırsın.',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ).entrance(0),
          if (records.completed > 0) ...[
            const SizedBox(height: 8),
            Text(
              '${records.completed} sohbet tamamladın · '
              '${records.goalScenarios.length}/${roleplayScenarios.length} '
              'görev başarıldı',
              style: theme.textTheme.labelLarge?.copyWith(
                color: theme.colorScheme.primary,
              ),
            ).entrance(0),
          ],
          const SizedBox(height: 16),
          for (final (i, s) in roleplayScenarios.indexed)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _ScenarioCard(
                scenario: s,
                done: records.goalScenarios.contains(s.id),
                onTap: () => context.push('/roleplay/${s.id}'),
              ).entrance(i + 1),
            ),
        ],
      ),
    );
  }
}

class _ScenarioCard extends StatelessWidget {
  const _ScenarioCard({
    required this.scenario,
    required this.done,
    required this.onTap,
  });

  final RoleplayScenario scenario;
  final bool done;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return PressableScale(
      onTap: onTap,
      child: Ink(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: done
                ? AppColors.success.withValues(alpha: 0.6)
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Text(
                scenario.emoji,
                textScaler: TextScaler.noScaling,
                style: const TextStyle(fontSize: 26),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    scenario.title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    scenario.task,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(
              done ? Icons.check_circle_rounded : Icons.chevron_right_rounded,
              color: done ? AppColors.success : theme.colorScheme.outline,
            ),
          ],
        ),
      ),
    );
  }
}

/// Seçilen senaryoda sohbet.
class RoleplayChatScreen extends ConsumerStatefulWidget {
  const RoleplayChatScreen({super.key, required this.scenarioId});

  final String scenarioId;

  @override
  ConsumerState<RoleplayChatScreen> createState() => _RoleplayChatScreenState();
}

class _RoleplayChatScreenState extends ConsumerState<RoleplayChatScreen> {
  final _input = TextEditingController();
  late final SpeechService _speech = ref.read(speechServiceProvider);
  var _listening = false;

  RoleplayNotifier get _notifier =>
      ref.read(roleplayProvider(widget.scenarioId).notifier);

  @override
  void dispose() {
    _input.dispose();
    if (_listening) _speech.stopListening();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _input.text;
    if (text.trim().isEmpty) return;
    Haptics.tap();
    _input.clear();
    if (_listening) await _toggleMic();
    await _notifier.send(text);
  }

  Future<void> _toggleMic() async {
    if (_listening) {
      setState(() => _listening = false);
      await _speech.stopListening();
      return;
    }
    if (!await _speech.initRecognition()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Konuşma tanıma kullanılamıyor; mesajını yazabilirsin.',
            ),
          ),
        );
      return;
    }
    if (!mounted) return;
    setState(() => _listening = true);
    await _speech.listen(
      (words, isFinal) {
        if (!mounted) return;
        _input.value = TextEditingValue(
          text: words,
          selection: TextSelection.collapsed(offset: words.length),
        );
        if (isFinal) setState(() => _listening = false);
      },
      onDone: () {
        if (mounted) setState(() => _listening = false);
      },
    );
  }

  /// Bitirmeden çıkarken sorulur: XP ve düzeltmeler ancak bitirince kaydedilir.
  Future<void> _confirmLeave() async {
    final choice = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Sohbeti bitirelim mi?'),
        content: const Text(
          'Bitirirsen XP kazanırsın ve düzeltmeler hata defterine eklenir. '
          'Bitirmeden çıkarsan sohbet kaydedilmez.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Kaydetmeden çık'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Bitir'),
          ),
        ],
      ),
    );
    if (!mounted || choice == null) return;
    if (choice) {
      await _notifier.finish();
    } else {
      context.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(roleplayProvider(widget.scenarioId));
    final s = state.scenario;
    final needsConfirm = !state.finished && state.userMessages > 0;

    return PopScope(
      canPop: !needsConfirm,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text('${s.emoji} ${s.title}'),
          actions: [
            if (!state.finished)
              TextButton(
                onPressed: state.pending || state.userMessages == 0
                    ? null
                    : _notifier.finish,
                child: const Text('Bitir'),
              ),
          ],
        ),
        body: state.finished
            ? _Summary(
                state: state,
                onAgain: () {
                  ref.invalidate(roleplayProvider(widget.scenarioId));
                  _input.clear();
                },
                onDone: () => context.pop(),
              )
            : Column(
                children: [
                  _TaskBanner(task: s.task, reached: state.goalReached),
                  Expanded(child: _MessageList(state: state)),
                  if (state.error != null)
                    _ErrorBar(message: state.error!, onRetry: _notifier.retry),
                  _InputBar(
                    controller: _input,
                    enabled: !state.pending,
                    listening: _listening,
                    onSend: _send,
                    onMic: _toggleMic,
                  ),
                ],
              ),
      ),
    );
  }
}

class _TaskBanner extends StatelessWidget {
  const _TaskBanner({required this.task, required this.reached});

  final String task;
  final bool reached;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = reached ? AppColors.success : theme.colorScheme.primary;
    return AnimatedContainer(
      duration: Motion.medium,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            reached ? Icons.check_circle_rounded : Icons.flag_rounded,
            size: 18,
            color: color,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              reached
                  ? 'Görev tamamlandı! İstersen devam et ya da bitir.'
                  : task,
              style: theme.textTheme.bodySmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MessageList extends StatelessWidget {
  const _MessageList({required this.state});

  final RoleplayState state;

  @override
  Widget build(BuildContext context) {
    final messages = state.messages;
    // Ters liste: en yeni mesaj altta ve görünür kalır.
    final items = <Widget>[
      if (state.pending) const _TypingBubble(),
      for (var i = messages.length - 1; i >= 0; i--)
        _Bubble(
          key: ValueKey(i),
          message: messages[i],
          // Ardından cevap geldiyse mesaj değerlendirilmiştir.
          evaluated: i < messages.length - 1,
        ),
    ];
    return ListView(
      reverse: true,
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      children: items,
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({super.key, required this.message, required this.evaluated});

  final ChatMessage message;
  final bool evaluated;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final mine = message.speaker == Speaker.user;
    final correction = message.correction;
    final maxWidth = MediaQuery.sizeOf(context).width * 0.78;

    final bubble = Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      padding: EdgeInsets.fromLTRB(14, 10, mine ? 14 : 4, 10),
      decoration: BoxDecoration(
        color: mine
            ? theme.colorScheme.primary.withValues(alpha: 0.18)
            : theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.only(
          topLeft: const Radius.circular(18),
          topRight: const Radius.circular(18),
          bottomLeft: Radius.circular(mine ? 18 : 4),
          bottomRight: Radius.circular(mine ? 4 : 18),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(child: Text(message.text, style: theme.textTheme.bodyLarge)),
          if (!mine) SpeakButton(text: message.text),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: mine
            ? CrossAxisAlignment.end
            : CrossAxisAlignment.start,
        children: [
          bubble,
          if (mine && correction != null)
            _CorrectionNote(correction: correction, maxWidth: maxWidth)
          else if (mine && evaluated)
            Padding(
              padding: const EdgeInsets.only(top: 4, right: 4),
              child: Icon(
                Icons.check_rounded,
                size: 16,
                color: AppColors.success,
                semanticLabel: 'Doğru',
              ),
            ),
        ],
      ),
    ).animate().fadeIn(duration: Motion.fast).slideY(begin: 0.15);
  }
}

class _CorrectionNote extends StatelessWidget {
  const _CorrectionNote({required this.correction, required this.maxWidth});

  final Correction correction;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      constraints: BoxConstraints(maxWidth: maxWidth),
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.warning.withValues(alpha: 0.5)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.edit_rounded,
                size: 14,
                color: AppColors.warning,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  correction.corrected,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          if (correction.explanationTr.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(correction.explanationTr, style: theme.textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Align(
      alignment: Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < 3; i++)
              Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                  )
                  .animate(
                    onPlay: Motion.loop(reverse: true),
                    delay: (150 * i).ms,
                  )
                  .fadeOut(duration: 450.ms),
          ],
        ),
      ),
    );
  }
}

class _ErrorBar extends StatelessWidget {
  const _ErrorBar({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
      decoration: BoxDecoration(
        color: AppColors.error.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_off, size: 18, color: AppColors.error),
          const SizedBox(width: 10),
          Expanded(child: Text(message, style: theme.textTheme.bodySmall)),
          TextButton(onPressed: onRetry, child: const Text('Tekrar dene')),
        ],
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.enabled,
    required this.listening,
    required this.onSend,
    required this.onMic,
  });

  final TextEditingController controller;
  final bool enabled;
  final bool listening;
  final VoidCallback onSend;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 4, 8, 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textCapitalization: TextCapitalization.sentences,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? (_) => onSend() : null,
                decoration: InputDecoration(
                  hintText: listening ? 'Dinliyorum…' : 'İngilizce yaz…',
                  filled: true,
                  fillColor: theme.colorScheme.surfaceContainerHighest,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            IconButton(
              tooltip: listening ? 'Dinlemeyi durdur' : 'Sesle yaz',
              onPressed: onMic,
              icon: Icon(
                listening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                color: listening ? AppColors.error : null,
              ),
            ),
            ListenableBuilder(
              listenable: controller,
              builder: (context, _) => IconButton.filled(
                tooltip: 'Gönder',
                onPressed: enabled && controller.text.trim().isNotEmpty
                    ? onSend
                    : null,
                icon: const Icon(Icons.send_rounded),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Summary extends StatelessWidget {
  const _Summary({
    required this.state,
    required this.onAgain,
    required this.onDone,
  });

  final RoleplayState state;
  final VoidCallback onAgain;
  final VoidCallback onDone;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final xp = state.xpEarned ?? 0;
    final corrections = state.corrected;

    return ListView(
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
      children: [
        Icon(
          state.goalReached ? Icons.emoji_events_rounded : Icons.forum_rounded,
          size: 64,
          color: state.goalReached
              ? AppColors.warning
              : theme.colorScheme.primary,
        ).animate().scale(curve: Curves.elasticOut, duration: Motion.slow),
        const SizedBox(height: 12),
        Text(
          state.goalReached ? 'Görev tamamlandı!' : 'Sohbet bitti',
          textAlign: TextAlign.center,
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          xp > 0
              ? '+$xp XP · ${state.userMessages} mesaj'
              : 'XP için en az $roleplayMinMessages mesaj gerekli '
                    '(${state.userMessages} yazdın).',
          textAlign: TextAlign.center,
          style: theme.textTheme.titleSmall?.copyWith(
            color: xp > 0 ? theme.colorScheme.primary : null,
            fontWeight: FontWeight.w700,
          ),
        ),
        const SizedBox(height: 24),
        if (corrections.isEmpty)
          Text(
            'Hiç düzeltme gerekmedi — harika!',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium,
          )
        else ...[
          Text(
            'DÜZELTMELER',
            style: theme.textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: theme.colorScheme.primary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Hata defterine eklendi; sonraki derslerde tekrar karşına çıkar.',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 10),
          for (final m in corrections)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      m.text,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        decoration: TextDecoration.lineThrough,
                        color: theme.colorScheme.onSurface.withValues(
                          alpha: 0.6,
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      m.correction!.corrected,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        fontWeight: FontWeight.w700,
                        color: AppColors.success,
                      ),
                    ),
                    if (m.correction!.explanationTr.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        m.correction!.explanationTr,
                        style: theme.textTheme.bodySmall,
                      ),
                    ],
                  ],
                ),
              ),
            ),
        ],
        const SizedBox(height: 24),
        FilledButton.icon(
          onPressed: onAgain,
          style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          icon: const Icon(Icons.replay_rounded),
          label: const Text('Aynı durumu tekrar oyna'),
        ),
        const SizedBox(height: 8),
        TextButton(onPressed: onDone, child: const Text('Bitir')),
      ],
    );
  }
}
