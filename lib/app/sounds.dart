import 'dart:async';

import 'package:audioplayers/audioplayers.dart';
import 'package:clock/clock.dart';
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
  static set player(SoundPlayer value) {
    _player = value;
    _last = null;
  }

  /// Cihazın ses sistemini kullanır; çalan müziği durdurmaz.
  static void useDevicePlayer() => _player = _DevicePlayer();

  static ({SoundEffect effect, DateTime at})? _last;

  /// Sesler üst üste binmez: önemli bir ses (rozet, seviye) çalarken daha
  /// önemsizi (ders bitti, doğru cevap) atlanır, aynı kutlama sesi baştan
  /// başlamaz. [force] sırası gelen kutlama içindir: kullanıcı öncekini erken
  /// kapattıysa da sesi çalar.
  static void play(SoundEffect effect, {bool force = false}) {
    if (!enabled) return;
    final now = clock.now();
    if (_last case final last? when !force) {
      final ringing = now.difference(last.at) < last.effect.length;
      final repeated = effect == last.effect && effect.priority > 0;
      if (ringing && (effect.priority < last.effect.priority || repeated)) {
        return;
      }
    }
    _last = (effect: effect, at: now);
    _player.play(effect);
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
  correct('sounds/dogru.wav', 0, Duration(milliseconds: 500)),
  wrong('sounds/yanlis.wav', 0, Duration(milliseconds: 480)),
  finished('sounds/ders_bitti.wav', 1, Duration(milliseconds: 1400)),
  badge('sounds/rozet.wav', 2, Duration(milliseconds: 950)),
  levelUp('sounds/seviye.wav', 3, Duration(milliseconds: 1600));

  const SoundEffect(this.asset, this.priority, this.length);

  /// assets/ altındaki yol (audioplayers önekini kendisi ekler).
  final String asset;

  /// Büyük olan çalarken küçük olan atlanır.
  final int priority;

  /// Dosyanın süresi.
  final Duration length;
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

  /// Her istek bir artar; beklerken yenisi gelen ses çalmaktan vazgeçer.
  var _request = 0;

  /// Bitiş sesi, son cevabın sesinin ardından gelir. Bu arada rozet
  /// kazanılırsa yerini rozet sesi alır.
  static const _finishDelay = Duration(milliseconds: 400);

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
    final request = ++_request;
    try {
      if (effect == SoundEffect.finished) {
        await Future<void>.delayed(_finishDelay);
        if (request != _request) return;
      }
      final player = await (_players[effect] ??= _create(effect));
      // Önceki ses sürüyorsa kesilir; iki ses üst üste çalmaz.
      for (final other in _players.values.toList()) {
        await (await other).stop();
      }
      if (request != _request) return;
      await player.play(AssetSource(effect.asset), volume: 0.8);
    } catch (e) {
      // Ses isteğe bağlı bir geri bildirim; sonraki seferde yeniden kurulur.
      _players.remove(effect)?.ignore();
      debugPrint('Ses çalınamadı (${effect.name}): $e');
    }
  }
}
