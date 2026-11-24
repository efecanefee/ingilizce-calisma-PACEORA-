import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Uygulama sesleri: cevap, ders bitişi, rozet ve seviye.
///
/// [Haptics] gibi uygulamanın her yerinden çağrılır. Testlerde ses çalınmaz:
/// gerçek oynatıcı yalnızca `main()` içinde [Sounds.useDevicePlayer] ile
/// kurulur. Ayarlar > Ses efektleri [Sounds.enabled]'ı değiştirir.
abstract class Sounds {
  static bool enabled = true;

  static SoundPlayer _player = const _SilentPlayer();

  /// Testler çalınan sesleri görmek için kendi oynatıcısını verebilir.
  @visibleForTesting
  static set player(SoundPlayer value) => _player = value;

  /// Cihazın ses sistemini kullanır; çalan müziği durdurmaz.
  static void useDevicePlayer() => _player = _DevicePlayer();

  static void play(SoundEffect effect) {
    if (enabled) _player.play(effect);
  }

  static void correct() => play(SoundEffect.correct);
  static void wrong() => play(SoundEffect.wrong);

  /// Ders, hikaye, kart oturumu gibi bir çalışma bitti.
  static void finished() => play(SoundEffect.finished);

  /// Rozet, seri hedefi, rekor, yeni forma.
  static void badge() => play(SoundEffect.badge);

  /// Oyuncu ya da İngilizce seviyesi yükseldi.
  static void levelUp() => play(SoundEffect.levelUp);

  /// Cevaba göre doğru ya da yanlış sesi.
  static void answer({required bool correct}) =>
      correct ? Sounds.correct() : wrong();
}

enum SoundEffect {
  correct('sounds/dogru.wav'),
  wrong('sounds/yanlis.wav'),
  finished('sounds/ders_bitti.wav'),
  badge('sounds/rozet.wav'),
  levelUp('sounds/seviye.wav');

  const SoundEffect(this.asset);

  /// assets/ altındaki yol (audioplayers önekini kendisi ekler).
  final String asset;
}

abstract class SoundPlayer {
  void play(SoundEffect effect);
}

class _SilentPlayer implements SoundPlayer {
  const _SilentPlayer();

  @override
  void play(SoundEffect effect) {}
}

class _DevicePlayer implements SoundPlayer {
  /// Medya kanalı: ses düzeyini medya tuşu belirler. Önceki sürüm zil sesi
  /// kanalını kullanıyordu; telefon titreşim ya da sessizdeyken hiçbir ses
  /// duyulmuyordu. Odak istenmez: arkada çalan müzik kesilmez.
  static final _context = AudioContext(
    android: const AudioContextAndroid(
      contentType: AndroidContentType.sonification,
      audioFocus: AndroidAudioFocus.none,
    ),
    iOS: AudioContextIOS(
      category: AVAudioSessionCategory.playback,
      options: const {AVAudioSessionOptions.mixWithOthers},
    ),
  );

  final _players = <SoundEffect, Future<AudioPlayer>>{};

  /// Oynatıcı ilk kullanımda kurulur; ayarlar sırayla beklenir. Kurulum
  /// bitmeden çalınan ses (önceki sürümde) kayboluyordu.
  Future<AudioPlayer> _create(SoundEffect effect) async {
    final player = AudioPlayer();
    await player.setAudioContext(_context);
    await player.setReleaseMode(ReleaseMode.stop);
    await player.setSource(AssetSource(effect.asset));
    return player;
  }

  @override
  void play(SoundEffect effect) => unawaited(_play(effect));

  Future<void> _play(SoundEffect effect) async {
    try {
      final player = await (_players[effect] ??= _create(effect));
      await player.stop();
      await player.play(AssetSource(effect.asset), volume: 0.8);
    } catch (e) {
      // Ses isteğe bağlı bir geri bildirim; sonraki seferde yeniden kurulur.
      _players.remove(effect)?.ignore();
      debugPrint('Ses çalınamadı (${effect.name}): $e');
    }
  }
}
