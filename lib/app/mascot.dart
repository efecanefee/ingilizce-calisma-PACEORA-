import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

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
    this.size = 120,
    this.animate = true,
    this.semanticLabel = 'Pace',
  });

  final PaceMood mood;

  /// Görselin yüksekliği; genişlik pozun oranına göre ayarlanır.
  final double size;

  /// Hafif nefes alma animasyonu.
  final bool animate;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    Widget mascot = Image.asset(
      mood.asset,
      height: size,
      fit: BoxFit.contain,
      filterQuality: FilterQuality.medium,
      excludeFromSemantics: true,
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
