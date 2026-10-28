import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/motion.dart';
import '../../app/theme.dart';
import '../../data/lesson_models.dart';

/// Kelime tanıtım kartı. Puanlanmaz; ders öncesi hazırlık.
class VocabCard extends StatelessWidget {
  const VocabCard({super.key, required this.item});

  final VocabItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              item.word,
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              item.meaning,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: theme.colorScheme.primary),
            ),
            if (item.example.isNotEmpty) ...[
              const SizedBox(height: 10),
              Text(
                item.example,
                style: theme.textTheme.bodyMedium?.copyWith(
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.75),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Çoktan seçmeli soru kartı — hem boşluk doldurma hem test adımında kullanılır.
///
/// Cevap verildikten sonra seçenekler kilitlenir; doğru cevap yeşil, kullanıcının
/// yanlış seçimi kırmızı işaretlenir ve varsa açıklama açılır.
class ChoiceQuestionCard extends StatelessWidget {
  const ChoiceQuestionCard({
    super.key,
    required this.number,
    required this.prompt,
    required this.options,
    required this.answer,
    required this.given,
    required this.onSelected,
    this.hint,
    this.explanation,
  });

  final int number;
  final String prompt;
  final List<String> options;
  final String answer;

  /// Kullanıcının seçimi; null ise soru henüz cevaplanmadı.
  final String? given;

  final ValueChanged<String> onSelected;
  final String? hint;
  final String? explanation;

  bool get _answered => given != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$number. $prompt',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600, height: 1.4),
            ),
            if (hint != null && hint!.isNotEmpty) ...[
              const SizedBox(height: 6),
              Text(
                hint!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                ),
              ),
            ],
            const SizedBox(height: 14),
            for (final option in options)
              _OptionTile(
                label: option,
                state: _stateFor(option),
                onTap: _answered ? null : () => onSelected(option),
              ),
            if (_answered &&
                explanation != null &&
                explanation!.isNotEmpty) ...[
              const SizedBox(height: 6),
              _ExplanationBox(text: explanation!),
            ],
          ],
        ),
      ),
    );
  }

  _OptionState _stateFor(String option) {
    if (!_answered) return _OptionState.idle;
    if (option == answer) return _OptionState.correct;
    if (option == given) return _OptionState.wrong;
    return _OptionState.muted;
  }
}

enum _OptionState { idle, correct, wrong, muted }

class _OptionTile extends StatelessWidget {
  const _OptionTile({
    required this.label,
    required this.state,
    required this.onTap,
  });

  final String label;
  final _OptionState state;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final (border, background, icon) = switch (state) {
      _OptionState.idle => (
          theme.colorScheme.outlineVariant,
          theme.colorScheme.surfaceContainer,
          null,
        ),
      _OptionState.correct => (
          AppColors.success,
          AppColors.success.withValues(alpha: 0.12),
          Icons.check_circle,
        ),
      _OptionState.wrong => (
          AppColors.error,
          AppColors.error.withValues(alpha: 0.12),
          Icons.cancel,
        ),
      _OptionState.muted => (
          theme.colorScheme.outlineVariant,
          Colors.transparent,
          null,
        ),
    };

    final tile = Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: onTap,
        child: AnimatedContainer(
          duration: Motion.medium,
          curve: Motion.curve,
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: background,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: border,
              width: state == _OptionState.idle ? 1 : 2,
            ),
          ),
          child: Row(
            children: [
              Expanded(
                child: AnimatedDefaultTextStyle(
                  duration: Motion.medium,
                  style: theme.textTheme.bodyLarge!.copyWith(
                    color: state == _OptionState.muted
                        ? theme.colorScheme.onSurface.withValues(alpha: 0.45)
                        : theme.colorScheme.onSurface,
                  ),
                  child: Text(label),
                ),
              ),
              if (icon != null)
                Icon(icon, size: 20, color: border)
                    .animate()
                    .scale(duration: Motion.medium, curve: Curves.elasticOut),
            ],
          ),
        ),
      ),
    );

    // Yanlış seçim hafifçe sallanır; doğru cevap kısa bir parlama alır.
    return switch (state) {
      _OptionState.wrong => tile.animate().shakeX(hz: 5, amount: 4, duration: 400.ms),
      _OptionState.correct => tile.animate().scaleXY(
          begin: 1,
          end: 1.02,
          duration: Motion.fast,
          curve: Curves.easeOut,
        ).then().scaleXY(begin: 1.02, end: 1, duration: Motion.fast),
      _ => tile,
    };
  }
}

/// Türkçeden İngilizceye çeviri kartı.
///
/// Cevap serbest metin; puanlama cihazda, modelin bildirdiği kabul edilebilir
/// varyantlara göre yapılır (bkz. [TranslateItem.isCorrect]).
class TranslateQuestionCard extends StatefulWidget {
  const TranslateQuestionCard({
    super.key,
    required this.number,
    required this.item,
    required this.given,
    required this.correct,
    required this.onSubmit,
  });

  final int number;
  final TranslateItem item;

  /// Kullanıcının yazdığı cevap; null ise henüz cevaplanmadı.
  final String? given;

  /// Cevap doğru muydu — [given] null ise anlamsız.
  final bool correct;

  final ValueChanged<String> onSubmit;

  @override
  State<TranslateQuestionCard> createState() => _TranslateQuestionCardState();
}

class _TranslateQuestionCardState extends State<TranslateQuestionCard> {
  late final TextEditingController _controller =
      TextEditingController(text: widget.given ?? '');

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  bool get _answered => widget.given != null;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.correct ? AppColors.success : AppColors.error;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.number}. ${widget.item.tr}',
              style: theme.textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600, height: 1.4),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _controller,
              enabled: !_answered,
              textInputAction: TextInputAction.done,
              onSubmitted: _answered ? null : _submit,
              decoration: InputDecoration(
                hintText: 'İngilizce çevirisini yaz',
                suffixIcon: _answered
                    ? Icon(
                        widget.correct ? Icons.check_circle : Icons.cancel,
                        color: color,
                      )
                    : null,
              ),
            ),
            const SizedBox(height: 12),
            if (!_answered)
              FilledButton.tonal(
                onPressed: () => _submit(_controller.text),
                child: const Text('Kontrol et'),
              )
            else ...[
              Text(
                widget.correct ? 'Doğru' : 'Beklenen cevap',
                style: theme.textTheme.labelLarge?.copyWith(color: color),
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.en,
                style: theme.textTheme.bodyLarge
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              if (widget.item.accepted.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  'Kabul edilen diğer çeviriler: '
                  '${widget.item.accepted.join(" · ")}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.65),
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  void _submit(String value) {
    if (value.trim().isEmpty) return;
    widget.onSubmit(value);
  }
}

class _ExplanationBox extends StatelessWidget {
  const _ExplanationBox({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.lightbulb_outline,
              size: 18, color: theme.colorScheme.primary),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
