import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';

/// Sesli okuma (TTS) ve konuşma tanıma (STT).
///
/// Cihaz servislerine bağlıdır; testlerde [speechServiceProvider] sahte bir
/// uygulamayla değiştirilir.
abstract class SpeechService {
  /// İngilizce metni sesli okur; okuma bitince tamamlanır. Cihazda İngilizce
  /// ses yoksa ya da ses motoru çalışmazsa false döner.
  Future<bool> speak(String text, {bool slow = false});

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

/// Yavaş okuma metni: her iki kelimede bir kısa durak.
///
/// Bazı telefonların ses motoru hız ayarını yok sayıyor; duraklar o
/// telefonlarda da cümleyi yavaşlatır.
String slowReading(String text) {
  final words = text.trim().split(RegExp(r'\s+'));
  if (words.length < 4) return text;
  final b = StringBuffer();
  for (final (i, w) in words.indexed) {
    b.write(w);
    if (i == words.length - 1) break;
    final pause = i.isOdd && !RegExp(r'[.,!?;:]$').hasMatch(w);
    b.write(pause ? ', ' : ' ');
  }
  return b.toString();
}

class DeviceSpeechService implements SpeechService {
  final _tts = FlutterTts();
  final _stt = SpeechToText();

  /// İngilizce ses hazır mı; ilk okumada bir kez sorulur.
  bool? _ttsReady;

  Future<bool> _prepareTts() async {
    final ready = _ttsReady;
    if (ready != null) return ready;
    // Ses paketi yüklü değilse motor sessizce hiçbir şey okumaz.
    final available = await _tts.isLanguageAvailable('en-US');
    if (available == false) return _ttsReady = false;
    await _tts.setLanguage('en-US');
    await _tts.awaitSpeakCompletion(true);
    return _ttsReady = true;
  }

  @override
  Future<bool> speak(String text, {bool slow = false}) async {
    try {
      if (!await _prepareTts()) return false;
      // Android'de eklenti hızı 2 ile çarpar: 0.48 ≈ normal, 0.22 ≈ yarı hız.
      await _tts.stop();
      await _tts.setSpeechRate(slow ? 0.22 : 0.48);
      await _tts.speak(slow ? slowReading(text) : text);
      return true;
    } catch (_) {
      // Ses motoru yoksa okuma isteğe bağlı bir yardım; çağıran bilgilendirir.
      return false;
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
