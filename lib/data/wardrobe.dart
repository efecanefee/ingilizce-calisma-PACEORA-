import 'package:flutter/painting.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'streak_freeze.dart';

/// Pace'in formaları: harcanabilir XP ile alınır, Profil'den giydirilir.
///
/// Forma, maskot görselindeki gri gövdeyi ve lime şeritleri yeniden
/// renklendirir; çizim aynı kalır. [classic] ücretsizdir ve görseli olduğu
/// gibi gösterir.
enum PaceKit {
  classic('Klasik', 0, null, null),
  crimson('Kırmızı Şimşek', 150, Color(0xFF2B2F35), Color(0xFFFF4D4D)),
  ice('Buz', 200, Color(0xFF1E3A5F), Color(0xFF7DD3FC)),
  night('Gece Moru', 250, Color(0xFF2E1F47), Color(0xFFC4B5FD)),
  white('Beyaz Forma', 300, Color(0xFFE9ECEF), Color(0xFFC6F432)),
  gold('Altın', 500, Color(0xFF17181B), Color(0xFFF5C542));

  const PaceKit(this.label, this.price, this.body, this.trim);

  final String label;

  /// Fiyat (harcanabilir XP).
  final int price;

  /// Forma gövdesinin rengi; null ise orijinal grafit.
  final Color? body;

  /// Şeritlerin, bilekliklerin ve şimşeğin rengi; null ise orijinal lime.
  final Color? trim;

  static PaceKit fromName(String? name) =>
      values.firstWhere((k) => k.name == name, orElse: () => PaceKit.classic);
}

class WardrobeState {
  const WardrobeState({
    this.owned = const {PaceKit.classic},
    this.equipped = PaceKit.classic,
  });

  static const ownedKey = 'wardrobe_owned';
  static const equippedKey = 'wardrobe_equipped';

  final Set<PaceKit> owned;
  final PaceKit equipped;

  bool owns(PaceKit kit) => owned.contains(kit);

  factory WardrobeState.read(SharedPreferences prefs) {
    final owned = {
      PaceKit.classic,
      for (final n in prefs.getStringList(ownedKey) ?? const <String>[])
        PaceKit.fromName(n),
    };
    final equipped = PaceKit.fromName(prefs.getString(equippedKey));
    return WardrobeState(
      owned: owned,
      equipped: owned.contains(equipped) ? equipped : PaceKit.classic,
    );
  }

  /// [kit]'i satın alır ve giydirir; alınamıyorsa false.
  ///
  /// Harcama, seri dondurma haklarıyla aynı "harcanan XP" sayacına yazılır;
  /// böylece iki mağaza aynı bakiyeyi paylaşır ve XP iki kez harcanamaz.
  static Future<bool> buy(
    SharedPreferences prefs,
    PaceKit kit, {
    required int totalXp,
  }) async {
    final s = WardrobeState.read(prefs);
    if (s.owns(kit)) return false;
    final freeze = FreezeState.read(prefs);
    if (freeze.balance(totalXp) < kit.price) return false;
    await prefs.setInt(FreezeState.spentKey, freeze.spentXp + kit.price);
    await prefs.setStringList(ownedKey, [
      for (final k in {...s.owned, kit})
        if (k != PaceKit.classic) k.name,
    ]);
    await prefs.setString(equippedKey, kit.name);
    return true;
  }

  /// Sahip olunan bir formayı giydirir.
  static Future<bool> equip(SharedPreferences prefs, PaceKit kit) async {
    if (!WardrobeState.read(prefs).owns(kit)) return false;
    await prefs.setString(equippedKey, kit.name);
    return true;
  }
}
