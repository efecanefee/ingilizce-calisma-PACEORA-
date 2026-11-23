import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/translation.dart';
import 'motion.dart';

/// "Türkçesi" yardım düğmesi: İngilizce bir metnin Türkçesini açıp kapatır.
///
/// [known] verilirse (dersin kendi Türkçe alanı) doğrudan o gösterilir;
/// yoksa çeviri yapay zekadan istenir ve cihazda saklanır.
class TranslateHelp extends ConsumerStatefulWidget {
  const TranslateHelp({
    super.key,
    required this.english,
    this.known,
    this.label = 'Türkçesi',
    this.initiallyOpen = false,
  });

  final String english;
  final String? known;
  final String label;
  final bool initiallyOpen;

  @override
  ConsumerState<TranslateHelp> createState() => _TranslateHelpState();
}

class _TranslateHelpState extends ConsumerState<TranslateHelp> {
  late bool _open = widget.initiallyOpen;

  @override
  Widget build(BuildContext context) {
    final known = widget.known?.trim() ?? '';
    final Widget body;
    if (!_open) {
      body = const SizedBox(width: double.infinity);
    } else if (known.isNotEmpty) {
      body = _Box(text: known);
    } else {
      body = switch (ref.watch(turkishProvider(widget.english))) {
        AsyncData(:final value) => _Box(text: value),
        AsyncError(:final error, isLoading: false) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Box(text: '$error', error: true),
            TextButton.icon(
              onPressed: () => ref.invalidate(turkishProvider(widget.english)),
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Tekrar dene'),
            ),
          ],
        ),
        _ => const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      };
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextButton.icon(
          style: TextButton.styleFrom(
            visualDensity: VisualDensity.compact,
            padding: const EdgeInsets.symmetric(horizontal: 8),
            minimumSize: const Size(0, 40),
          ),
          onPressed: () {
            Haptics.tap();
            setState(() => _open = !_open);
          },
          icon: Icon(
            _open ? Icons.visibility_off_rounded : Icons.translate_rounded,
            size: 18,
          ),
          label: Text(_open ? 'Gizle' : widget.label),
        ),
        AnimatedSize(
          duration: Motion.fast,
          curve: Motion.curve,
          alignment: Alignment.topLeft,
          child: body,
        ),
        if (_open) const SizedBox(height: 4),
      ],
    );
  }
}

class _Box extends StatelessWidget {
  const _Box({required this.text, this.error = false});

  final String text;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        text,
        style: theme.textTheme.bodyMedium?.copyWith(
          color: error ? theme.colorScheme.error : null,
          height: 1.4,
        ),
      ),
    );
  }
}
