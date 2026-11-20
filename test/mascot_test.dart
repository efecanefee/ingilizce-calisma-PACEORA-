import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/logo.dart';
import 'package:paceora/app/mascot.dart';

void main() {
  test('her pozun ve rozetin görseli depoda var', () {
    for (final mood in PaceMood.values) {
      expect(File(mood.asset).existsSync(), isTrue, reason: mood.asset);
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
      expect(find.bySemanticsLabel('Pace'), findsOneWidget);
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
