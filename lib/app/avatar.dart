import 'package:flutter/material.dart';

import '../data/profile_style.dart';
import 'theme.dart';

/// Oyuncu avatarı: renkli daire içinde emoji, seviyeye göre metal çerçeve.
class PlayerAvatar extends StatelessWidget {
  const PlayerAvatar({
    super.key,
    required this.emoji,
    required this.color,
    required this.frame,
    this.size = 48,
  });

  PlayerAvatar.of(
    ProfileStyle style, {
    super.key,
    required int level,
    this.size = 48,
  }) : emoji = style.emoji,
       color = style.color,
       frame = style.frameFor(level);

  final String emoji;
  final Color color;
  final AvatarFrame frame;
  final double size;

  @override
  Widget build(BuildContext context) {
    final ring = frame == AvatarFrame.none ? 0.0 : size * 0.07;

    final face = Container(
      width: size - ring * 2,
      height: size - ring * 2,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: const Alignment(-0.3, -0.4),
          colors: [
            Color.lerp(color, Colors.white, 0.25)!,
            Color.lerp(color, AppColors.graphite900, 0.15)!,
          ],
        ),
      ),
      // Emoji yazı ölçeğiyle büyümesin; daireden taşar.
      child: Text(
        emoji,
        textScaler: TextScaler.noScaling,
        style: TextStyle(fontSize: size * 0.5, height: 1.1),
      ),
    );

    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: frame == AvatarFrame.none
            ? null
            : SweepGradient(
                colors: [...frame.colors, ...frame.colors.reversed],
              ),
        boxShadow: frame == AvatarFrame.none
            ? null
            : [
                BoxShadow(
                  color: frame.colors.last.withValues(alpha: 0.45),
                  blurRadius: size * 0.2,
                ),
              ],
      ),
      child: face,
    );
  }
}
