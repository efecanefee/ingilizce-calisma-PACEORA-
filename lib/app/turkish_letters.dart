import 'package:flutter/material.dart';

import 'motion.dart';

/// Türkçe büyük harf: "i" → "İ", "ı" → "I" (String.toUpperCase "i"yi "I"
/// yapar).
String trUpper(String s) =>
    s.replaceAll('i', 'İ').replaceAll('ı', 'I').toUpperCase();

/// Klavyede olmayabilecek Türkçe harfler için küçük tuş sırası. Kelime
/// başında büyük harf ekler (Ç Ğ I İ Ö Ş Ü), kelime içinde küçük; tuşların
/// etiketi de buna göre değişir. Harf imlecin olduğu yere yazılır.
class TurkishLetterBar extends StatefulWidget {
  const TurkishLetterBar({super.key, required this.controller});

  final TextEditingController controller;

  /// Sıra: klavyelerde çoğu zaman eksik olanlar. "i" kelime başında "İ"
  /// eklemek için: İngilizce klavye büyük harfte "I" verir.
  static const letters = ['ç', 'ğ', 'ı', 'i', 'ö', 'ş', 'ü'];

  @override
  State<TurkishLetterBar> createState() => _TurkishLetterBarState();
}

class _TurkishLetterBarState extends State<TurkishLetterBar> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_changed);
  }

  @override
  void didUpdateWidget(TurkishLetterBar old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_changed);
      widget.controller.addListener(_changed);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_changed);
    super.dispose();
  }

  void _changed() => setState(() {});

  /// İmleç kelime başında mı: metnin başı ya da boşluktan sonra.
  bool get _atWordStart {
    final value = widget.controller.value;
    final text = value.text;
    final cursor = value.selection.isValid ? value.selection.start : text.length;
    return cursor == 0 || text[cursor - 1] == ' ';
  }

  String _letterFor(String base) => _atWordStart ? trUpper(base) : base;

  void _insert(String base) {
    Haptics.tap();
    final value = widget.controller.value;
    final text = value.text;
    final selection = value.selection.isValid
        ? value.selection
        : TextSelection.collapsed(offset: text.length);
    final letter = _letterFor(base);
    final next = text.replaceRange(selection.start, selection.end, letter);
    widget.controller.value = value.copyWith(
      text: next,
      selection: TextSelection.collapsed(offset: selection.start + letter.length),
      composing: TextRange.empty,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      container: true,
      label: 'Türkçe harfler',
      child: Wrap(
        spacing: 6,
        runSpacing: 6,
        children: [
          for (final base in TurkishLetterBar.letters)
            Tooltip(
              message: '${_letterFor(base)} ekle',
              excludeFromSemantics: true,
              child: Semantics(
                button: true,
                label: '${_letterFor(base)} harfini ekle',
                excludeSemantics: true,
                child: Material(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(10),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    // Odak alanda kalsın: tuşa basınca klavye kapanmasın.
                    canRequestFocus: false,
                    onTap: () => _insert(base),
                    child: SizedBox(
                      width: 44,
                      height: 44,
                      child: Center(
                        child: Text(
                          _letterFor(base),
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
