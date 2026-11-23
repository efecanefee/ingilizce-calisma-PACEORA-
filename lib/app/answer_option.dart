import 'package:flutter/material.dart';

import 'theme.dart';

/// Cevap seçeneğinin görünümü: seçilmeden önce, doğru, yanlış seçilen ya da
/// cevaplandıktan sonra soluklaşan diğer seçenekler.
enum AnswerState { idle, correct, wrong, muted }

/// [picked] seçildiyse her seçeneğin durumunu verir; doğru seçenek her zaman
/// yeşil gösterilir, yanlış seçilen kırmızı olur.
AnswerState answerStateFor({
  required int option,
  required int correct,
  required int? picked,
}) {
  if (picked == null) return AnswerState.idle;
  if (option == correct) return AnswerState.correct;
  if (option == picked) return AnswerState.wrong;
  return AnswerState.muted;
}

/// Seviye testi ve kısa kontrollerdeki seçenek düğmesi. Cevap verilince
/// doğruyu yeşil, yanlış seçileni kırmızı gösterir.
class AnswerOption extends StatelessWidget {
  const AnswerOption({
    super.key,
    required this.label,
    required this.state,
    required this.onPressed,
    this.expand = true,
  });

  final String label;
  final AnswerState state;

  /// Cevap verildikten sonra null: seçenekler kilitlenir.
  final VoidCallback? onPressed;

  /// Tam genişlik (liste) ya da yalnızca metin kadar (yan yana seçenekler).
  final bool expand;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final (
      Color? fill,
      Color border,
      Color text,
      IconData? icon,
    ) = switch (state) {
      AnswerState.idle => (null, scheme.outline, scheme.onSurface, null),
      AnswerState.correct => (
        AppColors.success.withValues(alpha: 0.16),
        AppColors.success,
        scheme.onSurface,
        Icons.check_circle_rounded,
      ),
      AnswerState.wrong => (
        AppColors.error.withValues(alpha: 0.14),
        AppColors.error,
        scheme.onSurface,
        Icons.cancel_rounded,
      ),
      AnswerState.muted => (
        null,
        scheme.outline.withValues(alpha: 0.4),
        scheme.onSurface.withValues(alpha: 0.5),
        null,
      ),
    };

    final content = Row(
      mainAxisSize: expand ? MainAxisSize.max : MainAxisSize.min,
      children: [
        Flexible(
          fit: expand ? FlexFit.tight : FlexFit.loose,
          child: Text(label, style: TextStyle(color: text)),
        ),
        if (icon != null) ...[
          const SizedBox(width: 8),
          Icon(icon, size: 20, color: border),
        ],
      ],
    );

    return Semantics(
      button: true,
      label: switch (state) {
        AnswerState.correct => '$label, doğru',
        AnswerState.wrong => '$label, yanlış',
        _ => null,
      },
      excludeSemantics:
          state == AnswerState.correct || state == AnswerState.wrong,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        decoration: BoxDecoration(
          color: fill,
          border: Border.all(
            color: border,
            width: state == AnswerState.idle ? 1 : 2,
          ),
          borderRadius: BorderRadius.circular(14),
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: onPressed,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 48),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 12,
                ),
                child: Align(
                  alignment: Alignment.centerLeft,
                  widthFactor: expand ? null : 1,
                  child: content,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
