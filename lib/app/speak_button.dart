import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/speech_service.dart';
import 'motion.dart';

/// İngilizce metni sesli okuyan küçük düğme.
class SpeakButton extends ConsumerWidget {
  const SpeakButton({
    super.key,
    required this.text,
    this.color,
    this.tooltip = 'Sesli oku',
  });

  final String text;
  final Color? color;
  final String tooltip;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      tooltip: tooltip,
      color: color,
      icon: const Icon(Icons.volume_up_rounded),
      onPressed: () {
        Haptics.tap();
        ref.read(speechServiceProvider).speak(text);
      },
    );
  }
}
