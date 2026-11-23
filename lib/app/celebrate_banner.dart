import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';

import 'celebration.dart';
import 'mascot.dart';
import 'motion.dart';

/// Başarı anlarında (gün tamamlandı, seviye atlandı) Paceora afişiyle
/// kutlama.
///
/// Uygulamanın kutlama kuyruğuna ([CelebrationHost]) girer: aynı anda
/// kazanılan rozet ya da seviye kutlamalarıyla üst üste binmez, sırayla ve
/// konfetiyle gösterilir. Hangi ekrana geçilirse geçilsin görünür.
void celebrateWithBanner(
  BuildContext context, {
  required String title,
  required String message,
}) {
  CelebrationHost.show(
    context,
    Celebration(
      title: title,
      subtitle: message,
      icon: Icons.bolt_rounded,
      color: const Color(0xFFC6F432),
      art: const CelebrateBannerArt(),
    ),
  );
}

/// Afiş görseli: hafifçe büyüyerek gelir, üstünden parıltı geçer.
class CelebrateBannerArt extends StatelessWidget {
  const CelebrateBannerArt({super.key});

  @override
  Widget build(BuildContext context) {
    Widget banner = ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: AspectRatio(
        aspectRatio: 16 / 9,
        child: Image.asset(
          paceCelebrateBanner,
          fit: BoxFit.cover,
          semanticLabel: 'Paceora: şimşekler arasında Pace',
        ),
      ),
    );
    if (!MediaQuery.disableAnimationsOf(context)) {
      banner = banner
          .animate()
          .scale(
            begin: const Offset(0.7, 0.7),
            duration: Motion.slow,
            curve: Curves.easeOutBack,
          )
          .fadeIn(duration: Motion.fast)
          .then(delay: 200.ms)
          .shimmer(
            duration: 1400.ms,
            color: const Color(0xFFC6F432).withValues(alpha: 0.35),
          );
    }
    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 320),
      child: banner,
    );
  }
}
