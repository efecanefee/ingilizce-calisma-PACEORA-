import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import '../../app/motion.dart';
import '../../app/sounds.dart';
import '../../app/theme.dart';
import '../../app/translate_help.dart';
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
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              item.meaning,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.primary,
              ),
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
              TranslateHelp(
                english: item.example,
                known: item.exampleTr,
                label: 'Cümlenin Türkçesi',
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
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            // Soru İngilizce; Türkçesi bir dokunuşla açılır. Dersin kendi
            // Türkçe alanı varsa o, yoksa yapay zeka çevirisi gösterilir.
            TranslateHelp(english: prompt, known: hint),
            const SizedBox(height: 8),
            for (final option in options)
              _OptionTile(
                label: option,
                state: _stateFor(option),
                onTap: _answered ? null : () => _select(option),
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

  void _select(String option) {
    Sounds.answer(correct: option.toLowerCase() == answer.toLowerCase());
    onSelected(option);
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
                Icon(icon, size: 20, color: border).animate().scale(
                  duration: Motion.medium,
                  curve: Curves.elasticOut,
                ),
            ],
          ),
        ),
      ),
    );

    // Yanlış seçim hafifçe sallanır; doğru cevap kısa bir parlama alır.
    return switch (state) {
      _OptionState.wrong => tile.animate().shakeX(
        hz: 5,
        amount: 4,
        duration: 400.ms,
      ),
      _OptionState.correct =>
        tile
            .animate()
            .scaleXY(
              begin: 1,
              end: 1.02,
              duration: Motion.fast,
              curve: Curves.easeOut,
            )
            .then()
            .scaleXY(begin: 1.02, end: 1, duration: Motion.fast),
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
  late final TextEditingController _controller = TextEditingController(
    text: widget.given ?? '',
  );

  @override
  void initState() {
    super.initState();
    // Elle yazılan ya da silinen kelimeler de kutuda işaretlenir.
    _controller.addListener(_onText);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onText() {
    if (mounted && _hintLevel >= 1) setState(() {});
  }

  bool get _answered => widget.given != null;

  /// 0: yalnızca başlangıç, 1: kelime kutusu, 2: cümlenin yarısı açık.
  var _hintLevel = 0;

  /// Beklenen cevabın kelimeleri (noktalamasız).
  List<String> get _words => widget.item.en
      .split(RegExp(r'\s+'))
      .map((w) => w.replaceAll(RegExp(r'[.,!?;:"]'), ''))
      .where((w) => w.isNotEmpty)
      .toList();

  /// Kelime kutusu: karışık sırada, her açılışta aynı.
  late final List<String> _bank = () {
    final words = _words;
    final bank = [...words]..shuffle(Random(widget.number));
    // Şans eseri cümlenin kendisi çıkarsa ters çevrilir.
    return listEquals(bank, words) ? bank.reversed.toList() : bank;
  }();

  /// Kutudan eklenen kelimeler, sırayla; "Geri al" sondan başlar.
  final _added = <String>[];

  static String _bare(String w) =>
      w.replaceAll(RegExp(r'[.,!?;:"]'), '').toLowerCase();

  /// Kutuda üstü çizilecek kelimelerin sıraları: yazıda geçenler. Aynı kelime
  /// iki kez varsa yazıda geçtiği kadarı çizilir.
  Set<int> get _used {
    final left = <String, int>{};
    for (final w in _controller.text.split(RegExp(r'\s+'))) {
      final key = _bare(w);
      if (key.isNotEmpty) left[key] = (left[key] ?? 0) + 1;
    }
    final used = <int>{};
    for (final (i, w) in _bank.indexed) {
      final key = _bare(w);
      final n = left[key] ?? 0;
      if (n == 0) continue;
      left[key] = n - 1;
      used.add(i);
    }
    return used;
  }

  /// Yazıda hâlâ duran, kutudan eklenmiş son kelime.
  String? get _lastAdded {
    final words = _controller.text.split(RegExp(r'\s+')).map(_bare).toList();
    for (final word in _added.reversed) {
      if (words.contains(_bare(word))) return word;
    }
    return null;
  }

  void _hint() {
    Haptics.tap();
    setState(() => _hintLevel = min(_hintLevel + 1, 2));
  }

  /// Baştan açık verilen kelime sayısı: üçte biri, son ipucunda yarısı.
  /// Çok kısa cümlede hiçbiri; yoksa cevabın kendisi görünürdü.
  int get _shownWords {
    final n = _words.length;
    if (n < 3) return 0;
    return _hintLevel == 2 ? (n / 2).ceil() : max(1, n ~/ 3);
  }

  /// "I went ___ ___ ___ ___": verilen kısım ve kalan boşluklar. Yazı
  /// alanına dokunmaz; öğrencinin yazdığı silinmez.
  String get _scaffold => [
    for (final (i, w) in _words.indexed) i < _shownWords ? w : '___',
  ].join(' ');

  void _addWord(String word) {
    Haptics.tap();
    final text = _controller.text.trimRight();
    _controller.text = text.isEmpty ? '$word ' : '$text $word ';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
    _added.add(word);
  }

  /// Kutudan eklenen son kelimeyi yazıdan çıkarır; elle yazılanlara dokunmaz.
  void _undoWord() {
    final word = _lastAdded;
    if (word == null) return;
    Haptics.tap();
    _added.removeAt(_added.lastIndexOf(word));
    final parts = _controller.text.trim().split(RegExp(r'\s+'));
    parts.removeAt(parts.map(_bare).toList().lastIndexOf(_bare(word)));
    _controller.text = parts.isEmpty ? '' : '${parts.join(' ')} ';
    _controller.selection = TextSelection.collapsed(
      offset: _controller.text.length,
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final color = widget.correct ? AppColors.success : AppColors.error;
    final used = _used;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${widget.number}. ${widget.item.tr}',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
                height: 1.4,
              ),
            ),
            if (!_answered && _shownWords > 0) ...[
              const SizedBox(height: 10),
              Text(
                _scaffold,
                semanticsLabel:
                    'Başlangıcı: ${_words.take(_shownWords).join(' ')}, '
                    'kalan ${_words.length - _shownWords} kelime',
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: theme.colorScheme.primary,
                ),
              ),
            ],
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
            if (!_answered && _hintLevel >= 1) ...[
              const SizedBox(height: 10),
              Text(
                _hintLevel == 1
                    ? 'Bu kelimeleri kullan; dokundukça yazına eklenir:'
                    : 'Yarısını açtık; cümlenin tamamını sen yaz:',
                style: theme.textTheme.bodySmall,
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final (i, word) in _bank.indexed)
                    ActionChip(
                      label: Text(
                        word,
                        semanticsLabel: used.contains(i)
                            ? '$word, kullanıldı'
                            : word,
                        style: used.contains(i)
                            ? TextStyle(
                                decoration: TextDecoration.lineThrough,
                                decorationThickness: 2,
                                color: theme.colorScheme.onSurface.withValues(
                                  alpha: 0.55,
                                ),
                              )
                            : null,
                      ),
                      onPressed: used.contains(i) ? null : () => _addWord(word),
                    ),
                ],
              ),
              TextButton.icon(
                onPressed: _lastAdded == null ? null : _undoWord,
                icon: const Icon(Icons.undo_rounded),
                label: const Text('Geri al'),
              ),
            ],
            const SizedBox(height: 12),
            if (!_answered)
              Row(
                children: [
                  if (_hintLevel < 2)
                    TextButton.icon(
                      onPressed: _hint,
                      icon: const Icon(Icons.lightbulb_outline_rounded),
                      label: Text(
                        _hintLevel == 0 ? 'İpucu' : 'Biraz daha yardım',
                      ),
                    ),
                  const Spacer(),
                  FilledButton.tonal(
                    // Tema düğmeleri tam genişlik; satır içinde sınırlanır.
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(0, 48),
                    ),
                    onPressed: () => _submit(_controller.text),
                    child: const Text('Kontrol et'),
                  ),
                ],
              )
            else ...[
              Text(
                widget.correct ? 'Doğru' : 'Beklenen cevap',
                style: theme.textTheme.labelLarge?.copyWith(color: color),
              ),
              const SizedBox(height: 4),
              Text(
                widget.item.en,
                style: theme.textTheme.bodyLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
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
    Sounds.answer(correct: widget.item.isCorrect(value));
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
          Icon(
            Icons.lightbulb_outline,
            size: 18,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: theme.textTheme.bodySmall)),
        ],
      ),
    );
  }
}
