import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/logo.dart';
import 'package:paceora/app/mascot.dart';

void main() {
  test('her pozun ve rozetin görseli depoda var', () {
    for (final mood in PaceMood.values) {
      for (final asset in [mood.asset, mood.kitMask, mood.trimMask]) {
        expect(File(asset).existsSync(), isTrue, reason: asset);
      }
    }
    expect(File(MascotAssets.badge).existsSync(), isTrue);
  });

  testWidgets('PaceMascot seçilen pozun görselini çizer', (tester) async {
    for (final mood in PaceMood.values) {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: PaceMascot(mood: mood, animate: false)),
        ),
      );
      final image = tester.widget<Image>(find.byType(Image));
      expect((image.image as AssetImage).assetName, mood.asset);
      expect(find.bySemanticsLabel(mood.label), findsOneWidget);
    }
  });

  testWidgets('animasyonları azalt açıkken Pace hareket etmez', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: Center(child: PaceMascot()),
        ),
      ),
    );
    expect(find.byType(Animate), findsNothing);

    await tester.pumpWidget(
      const MaterialApp(home: Center(child: PaceMascot())),
    );
    expect(find.byType(Animate), findsOneWidget);
    // Döngüdeki animasyonun zamanlayıcısı test bitmeden kapansın.
    await tester.pumpWidget(const SizedBox());
    await tester.pump(const Duration(seconds: 2));
  });

  test('her görselin 1x, 2x ve 3x sürümü var', () {
    for (final asset in MascotAssets.all) {
      final name = asset.split('/').last;
      for (final dir in ['', '2.0x/', '3.0x/']) {
        final path = '${MascotAssets.dir}/$dir$name';
        expect(File(path).existsSync(), isTrue, reason: path);
      }
    }
  });

  testWidgets('logo kilidi rozet ve PACEORA yazısını gösterir', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: Center(child: PaceoraLockup())),
    );
    expect(find.byType(PaceoraMark), findsOneWidget);
    expect(find.text(LogoAssets.slogan), findsOneWidget);
  });
}
