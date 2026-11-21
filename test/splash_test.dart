import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/splash.dart';

void main() {
  Widget app({bool enabled = true}) => MaterialApp(
    home: SplashOverlay(
      enabled: enabled,
      child: const Scaffold(body: Center(child: Text('Ana ekran'))),
    ),
  );

  testWidgets('açılış ekranı süre dolunca solarak kaybolur', (tester) async {
    await tester.pumpWidget(app());
    expect(find.bySemanticsLabel('Paceora açılıyor'), findsOneWidget);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.bySemanticsLabel('Paceora açılıyor'), findsNothing);
    expect(find.text('Ana ekran'), findsOneWidget);
  });

  testWidgets('dokununca hemen geçilir', (tester) async {
    await tester.pumpWidget(app());
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tapAt(const Offset(20, 20));
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.bySemanticsLabel('Paceora açılıyor'), findsNothing);
    // Harflerin gecikmeli animasyon zamanlayıcıları bitsin.
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('kapalıyken hiç gösterilmez', (tester) async {
    await tester.pumpWidget(app(enabled: false));
    expect(find.bySemanticsLabel('Paceora açılıyor'), findsNothing);
  });

  testWidgets('hareket azaltılmışsa kısa sürer', (tester) async {
    await tester.pumpWidget(
      MediaQuery(
        data: const MediaQueryData(disableAnimations: true),
        child: app(),
      ),
    );
    for (var i = 0; i < 13; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(find.bySemanticsLabel('Paceora açılıyor'), findsNothing);
  });
}
