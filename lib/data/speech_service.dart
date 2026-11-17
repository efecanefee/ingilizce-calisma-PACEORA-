import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Sesli okuma (TTS) ve konuşma tanıma (STT).
///
/// Cihaz servislerine bağlıdır; testlerde [speechServiceProvider] sahte bir
/// uygulamayla değiştirilir.
abstract class SpeechService {
  /// İngilizce metni sesli okur; okuma bitince tamamlanır.
  Future<void> speak(String text, {bool slow = false});

  Future<void> stopSpeaking();

  /// Konuşma tanıma kullanılabilir mi? İlk çağrıda mikrofon izni istenir.
  Future<bool> initRecognition();

  /// Dinlemeye başlar. [onResult] ara sonuçlarla da çağrılır; [isFinal]
  /// true geldiğinde dinleme biter. [onDone] dinleme herhangi bir nedenle
  /// (sessizlik, zaman aşımı, hata) bittiğinde çağrılır.
  Future<void> listen(
    void Function(String words, bool isFinal) onResult, {
    void Function()? onDone,
  });

  Future<void> stopListening();
}

class DeviceSpeechService implements SpeechService {
  final _tts = FlutterTts();
  final _stt = SpeechToText();
  bool _ttsReady = false;

  Future<void> _prepareTts() async {
    if (_ttsReady) return;
    await _tts.setLanguage('en-US');
    await _tts.awaitSpeakCompletion(true);
    _ttsReady = true;
  }

  @override
  Future<void> speak(String text, {bool slow = false}) async {
    try {
      await _prepareTts();
      await _tts.setSpeechRate(slow ? 0.3 : 0.48);
      await _tts.speak(text);
    } catch (_) {
      // Ses motoru yoksa sessizce geçilir; okuma isteğe bağlı bir yardım.
    }
  }

  @override
  Future<void> stopSpeaking() async {
    try {
      await _tts.stop();
    } catch (_) {}
  }

  /// Etkin dinlemenin bitiş bildirimi; durum dinleyicisi tek kez kurulur.
  void Function()? _onDone;

  @override
  Future<bool> initRecognition() async {
    try {
      return await _stt.initialize(
        onStatus: (status) {
          if (status == SpeechToText.doneStatus ||
              status == SpeechToText.notListeningStatus) {
            final done = _onDone;
            _onDone = null;
            done?.call();
          }
        },
        onError: (_) {
          final done = _onDone;
          _onDone = null;
          done?.call();
        },
      );
    } catch (_) {
      return false;
    }
  }

  @override
  Future<void> listen(
    void Function(String words, bool isFinal) onResult, {
    void Function()? onDone,
  }) async {
    _onDone = onDone;
    await stopSpeaking();
    await _stt.listen(
      onResult: (r) => onResult(r.recognizedWords, r.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: 'en_US',
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Future<void> stopListening() => _stt.stop();
}

final speechServiceProvider = Provider<SpeechService>(
  (ref) => DeviceSpeechService(),
);
