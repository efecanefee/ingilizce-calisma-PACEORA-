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
        speakWithNotice(context, ref.read(speechServiceProvider), text);
      },
    );
  }
}

/// Bu oturumda "ses yok" bilgisi gösterildi mi; her dokunuşta tekrarlanmaz.
bool _missingVoiceNoticed = false;

@visibleForTesting
void resetMissingVoiceNotice() => _missingVoiceNoticed = false;

/// Metni okur; cihazda İngilizce ses yoksa oturumda bir kez nasıl
/// yükleneceğini anlatır.
Future<void> speakWithNotice(
  BuildContext context,
  SpeechService speech,
  String text, {
  bool slow = false,
}) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  final ok = await speech.speak(text, slow: slow);
  if (ok || _missingVoiceNoticed || messenger == null) return;
  _missingVoiceNoticed = true;
  messenger.showSnackBar(
    const SnackBar(
      content: Text(
        'Telefonunda İngilizce ses yok. Telefon ayarlarındaki metin okuma '
        '(TTS) bölümünden İngilizce ses paketini yükleyebilirsin.',
      ),
      duration: Duration(seconds: 6),
    ),
  );
}
