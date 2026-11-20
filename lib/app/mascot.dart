import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/providers.dart';
import '../data/wardrobe.dart';

/// Pace'in pozları. Her biri şeffaf zeminli ayrı bir görsel.
enum PaceMood {
  /// Koşarken başparmak kaldırıyor: varsayılan, "hadi başlayalım".
  run('pace_run'),

  /// Elinde alevle zıplıyor: seri, ders bitişi, kutlama.
  cheer('pace_cheer'),

  /// Kulaklık ve defterle çalışıyor: ders, seviye testi.
  study('pace_study'),

  /// Şaşırmış: seri tehlikede, hata, boş durumlar.
  surprised('pace_surprised');

  const PaceMood(this.file);

  final String file;

  String get asset => '${MascotAssets.dir}/$file.png';

  /// Formanın gri gövdesi (renklendirme maskesi).
  String get kitMask => '${MascotAssets.dir}/${file}_kit.png';

  /// Formanın lime şeritleri (renklendirme maskesi).
  String get trimMask => '${MascotAssets.dir}/${file}_trim.png';
}

abstract class MascotAssets {
  static const dir = 'assets/mascot';

  /// Lime halka içinde Pace: logo amblemi.
  static const badge = '$dir/pace_badge.png';
}

/// Paceora maskotu Pace (çita).
class PaceMascot extends StatelessWidget {
  const PaceMascot({
    super.key,
    this.mood = PaceMood.run,
    this.kit = PaceKit.classic,
    this.size = 120,
    this.animate = true,
    this.semanticLabel = 'Pace',
  });

  final PaceMood mood;

  /// Giydiği forma; [PaceKit.classic] görseli olduğu gibi gösterir.
  final PaceKit kit;

  /// Görselin yüksekliği; genişlik pozun oranına göre ayarlanır.
  final double size;

  /// Hafif nefes alma animasyonu.
  final bool animate;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget layer(String asset) => Image.asset(
      asset,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
    );

    // Maskeler gri tonlu gölgelendirme taşır; modulate ile çarpılınca
    // çizimin ışık-gölgesi korunarak forma rengine boyanır.
    Widget tinted(String asset, Color color) => Positioned.fill(
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(color, BlendMode.modulate),
        child: layer(asset),
      ),
    );

    final body = kit.body;
    final trim = kit.trim;
    Widget mascot = body == null && trim == null
        ? layer(mood.asset)
        : Stack(
            children: [
              layer(mood.asset),
              if (body != null) tinted(mood.kitMask, body),
              if (trim != null) tinted(mood.trimMask, trim),
            ],
          );

    if (animate) {
      mascot = mascot
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scaleXY(
            begin: 1,
            end: 1.03,
            duration: 1600.ms,
            curve: Curves.easeInOut,
            alignment: Alignment.bottomCenter,
          );
    }

    return Semantics(label: semanticLabel, image: true, child: mascot);
  }
}

/// Kullanıcının giydirdiği formayla Pace.
class EquippedPace extends ConsumerWidget {
  const EquippedPace({
    super.key,
    this.mood = PaceMood.run,
    this.size = 120,
    this.animate = true,
  });

  final PaceMood mood;
  final double size;
  final bool animate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final kit = ref.watch(wardrobeProvider).equipped;
    return PaceMascot(mood: mood, kit: kit, size: size, animate: animate);
  }
}
