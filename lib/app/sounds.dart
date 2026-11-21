import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';

/// Doğru ve yanlış cevap sesleri.
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

  /// Cihazın ses sistemini kullanır; telefon sessizdeyse ses çıkmaz, çalan
  /// müziği durdurmaz.
  static void useDevicePlayer() => _player = _DevicePlayer();

  static void correct() {
    if (enabled) _player.play(SoundEffect.correct);
  }

  static void wrong() {
    if (enabled) _player.play(SoundEffect.wrong);
  }

  /// Cevaba göre doğru ya da yanlış sesi.
  static void answer({required bool correct}) =>
      correct ? Sounds.correct() : wrong();
}

enum SoundEffect {
  correct('sounds/dogru.wav'),
  wrong('sounds/yanlis.wav');

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
  _DevicePlayer() {
    for (final player in _players.values) {
      player
        ..setPlayerMode(PlayerMode.lowLatency)
        ..setReleaseMode(ReleaseMode.stop)
        ..setAudioContext(_context).ignore();
    }
  }

  static final _context = AudioContextConfig(
    // Sessiz moda uyar, arka planda çalan müziği kesmez.
    respectSilence: true,
    focus: AudioContextConfigFocus.mixWithOthers,
  ).build();

  final _players = {
    for (final effect in SoundEffect.values) effect: AudioPlayer(),
  };

  @override
  void play(SoundEffect effect) {
    final player = _players[effect]!;
    // Ses isteğe bağlı bir geri bildirim; hata olursa sessizce geçilir.
    player
        .stop()
        .then((_) => player.play(AssetSource(effect.asset), volume: 0.6))
        .catchError((Object _) {});
  }
}
