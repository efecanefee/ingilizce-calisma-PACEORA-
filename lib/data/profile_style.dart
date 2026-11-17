import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers.dart';
import 'rewards.dart';

/// Profilin görünümü: avatar, renk, çerçeve ve rozet vitrini.
///
/// Yalnızca süs olduğu için veritabanında değil SharedPreferences'ta durur
/// (`profile_` önekli anahtarlar; "Her şeyi sıfırla" bunları da siler).

/// Seçilebilir avatarlar.
const avatarEmojis = [
  '🦊', '🐼', '🦉', '🐯', '🐨', '🐸', '🐙', '🦁', //
  '🐧', '🐺', '🦄', '🐝', '🐬', '🐢', '🐱', '🐶',
];

/// Avatar arka plan renkleri.
const avatarColors = [
  Color(0xFFC6F432), // lime
  Color(0xFF60A5FA), // gök
  Color(0xFFA78BFA), // mor
  Color(0xFFFB923C), // turuncu
  Color(0xFFF472B6), // pembe
  Color(0xFF34D399), // yeşil
  Color(0xFFFBBF24), // kehribar
  Color(0xFF94A3B8), // gri
];

/// Avatar çerçevesi; oyuncu seviyesiyle açılır.
enum AvatarFrame {
  none('Sade', 1, []),
  bronze('Bronz', 3, [Color(0xFFE2A66B), Color(0xFF8C5A2B)]),
  silver('Gümüş', 5, [Color(0xFFF1F5F9), Color(0xFF94A3B8)]),
  gold('Altın', 7, [Color(0xFFFDE68A), Color(0xFFD97706)]);

  const AvatarFrame(this.label, this.unlockLevel, this.colors);

  final String label;

  /// Bu çerçeveyi açan oyuncu seviyesi.
  final int unlockLevel;
  final List<Color> colors;

  bool unlockedAt(int level) => level >= unlockLevel;

  /// Seviyenin açtığı en iyi çerçeve.
  static AvatarFrame bestFor(int level) =>
      values.lastWhere((f) => f.unlockedAt(level));
}

/// Vitrindeki en fazla rozet sayısı.
const showcaseSize = 3;

class ProfileStyle {
  const ProfileStyle({
    this.emoji = '🦊',
    this.colorIndex = 0,
    this.frame,
    this.showcase,
  });

  static const emojiKey = 'profile_avatar';
  static const colorKey = 'profile_color';
  static const frameKey = 'profile_frame';
  static const showcaseKey = 'profile_showcase';

  final String emoji;
  final int colorIndex;

  /// null: seviyenin açtığı en iyi çerçeve kendiliğinden kullanılır.
  final AvatarFrame? frame;

  /// Kullanıcının seçtiği rozetler; null ise hiç seçim yapılmadı.
  final List<String>? showcase;

  Color get color => avatarColors[colorIndex % avatarColors.length];

  /// Kullanılacak çerçeve: seçilen açık değilse (seviye düşmez ama veri
  /// sıfırlanmış olabilir) seviyenin en iyisine düşülür.
  AvatarFrame frameFor(int level) {
    final chosen = frame;
    if (chosen != null && chosen.unlockedAt(level)) return chosen;
    return AvatarFrame.bestFor(level);
  }

  /// Vitrinde gösterilecek rozetler; yalnızca kazanılmış olanlar.
  ///
  /// Seçim yapılmadıysa kazanılanların en zorları (listenin sonundakiler)
  /// gösterilir, böylece vitrin baştan boş kalmaz.
  List<BadgeDef> showcaseBadges(Set<String> earned) {
    final picked = showcase;
    if (picked == null) {
      final all = badges.where((b) => earned.contains(b.id)).toList();
      return all.reversed.take(showcaseSize).toList();
    }
    return [
      for (final id in picked)
        if (earned.contains(id)) ?badges.where((b) => b.id == id).firstOrNull,
    ];
  }
}

class ProfileStyleNotifier extends Notifier<ProfileStyle> {
  @override
  ProfileStyle build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final frameName = prefs.getString(ProfileStyle.frameKey);
    final emoji = prefs.getString(ProfileStyle.emojiKey);
    return ProfileStyle(
      emoji: avatarEmojis.contains(emoji) ? emoji! : avatarEmojis.first,
      colorIndex: prefs.getInt(ProfileStyle.colorKey) ?? 0,
      frame: AvatarFrame.values.where((f) => f.name == frameName).firstOrNull,
      showcase: prefs.getStringList(ProfileStyle.showcaseKey),
    );
  }

  Future<void> setEmoji(String emoji) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(ProfileStyle.emojiKey, emoji);
    ref.invalidateSelf();
  }

  Future<void> setColor(int index) async {
    await ref
        .read(sharedPreferencesProvider)
        .setInt(ProfileStyle.colorKey, index);
    ref.invalidateSelf();
  }

  Future<void> setFrame(AvatarFrame frame) async {
    await ref
        .read(sharedPreferencesProvider)
        .setString(ProfileStyle.frameKey, frame.name);
    ref.invalidateSelf();
  }

  /// Rozeti vitrine ekler ya da çıkarır. Vitrin doluysa en eski çıkar.
  ///
  /// [earned]: şu an kazanılmış rozetler; ilk seçimde otomatik vitrin
  /// kullanıcının listesine dönüştürülürken gerekir.
  Future<void> toggleShowcase(String badgeId, Set<String> earned) async {
    final current = [for (final b in state.showcaseBadges(earned)) b.id];
    final next = current.contains(badgeId)
        ? (current..remove(badgeId))
        : [...current, badgeId];
    while (next.length > showcaseSize) {
      next.removeAt(0);
    }
    await ref
        .read(sharedPreferencesProvider)
        .setStringList(ProfileStyle.showcaseKey, next);
    ref.invalidateSelf();
  }
}

final profileStyleProvider =
    NotifierProvider<ProfileStyleNotifier, ProfileStyle>(
      ProfileStyleNotifier.new,
    );
