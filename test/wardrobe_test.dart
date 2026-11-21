import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/mascot.dart';
import 'package:paceora/data/streak_freeze.dart';
import 'package:paceora/data/wardrobe.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late SharedPreferences prefs;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
  });

  test('başlangıçta yalnızca klasik forma var ve giyili', () {
    final s = WardrobeState.read(prefs);
    expect(s.owned, {PaceKit.classic});
    expect(s.equipped, PaceKit.classic);
  });

  test('XP yetmezse forma alınamaz', () async {
    final ok = await WardrobeState.buy(prefs, PaceKit.gold, totalXp: 100);
    expect(ok, isFalse);
    expect(WardrobeState.read(prefs).owns(PaceKit.gold), isFalse);
  });

  test('alınan forma giydirilir ve bakiye seri haklarıyla ortaktır', () async {
    final ok = await WardrobeState.buy(prefs, PaceKit.crimson, totalXp: 300);
    expect(ok, isTrue);
    final s = WardrobeState.read(prefs);
    expect(s.owns(PaceKit.crimson), isTrue);
    expect(s.equipped, PaceKit.crimson);
    // 300 - 150 = 150 kaldı; seri hakkı bu bakiyeden alınır.
    expect(FreezeState.read(prefs).balance(300), 150);
    // Aynı forma ikinci kez alınamaz.
    expect(
      await WardrobeState.buy(prefs, PaceKit.crimson, totalXp: 300),
      isFalse,
    );
  });

  test('sahip olunmayan forma giydirilemez, sahip olunan giydirilir', () async {
    expect(await WardrobeState.equip(prefs, PaceKit.ice), isFalse);
    await WardrobeState.buy(prefs, PaceKit.ice, totalXp: 1000);
    await WardrobeState.equip(prefs, PaceKit.classic);
    expect(WardrobeState.read(prefs).equipped, PaceKit.classic);
    expect(await WardrobeState.equip(prefs, PaceKit.ice), isTrue);
    expect(WardrobeState.read(prefs).equipped, PaceKit.ice);
  });

  testWidgets('renkli forma maske katmanlarını ekler', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Center(
          child: PaceMascot(kit: PaceKit.ice, animate: false),
        ),
      ),
    );
    expect(find.byType(ColorFiltered), findsNWidgets(2));

    await tester.pumpWidget(
      const MaterialApp(home: Center(child: PaceMascot(animate: false))),
    );
    expect(find.byType(ColorFiltered), findsNothing);
  });
}
