import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/feature_colors.dart';
import 'package:paceora/app/theme.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  final colored = Feature.values.where((f) => f != Feature.lesson);

  test('her bölümün rengi iki temada da okunur (WCAG AA)', () {
    for (final f in colored) {
      expect(
        _contrast(f.bright!, AppColors.graphite700),
        greaterThanOrEqualTo(4.5),
        reason: '${f.name} koyu temada',
      );
      expect(
        _contrast(f.deep!, Colors.white),
        greaterThanOrEqualTo(4.5),
        reason: '${f.name} açık temada',
      );
    }
  });

  test('bölüm renkleri birbirinden farklı', () {
    expect(colored.map((f) => f.bright).toSet(), hasLength(colored.length));
    expect(colored.map((f) => f.deep).toSet(), hasLength(colored.length));
  });

  testWidgets('ders bölümü seçilen vurguyu kullanır', (tester) async {
    late Color dark;
    late Color light;
    for (final b in Brightness.values) {
      await tester.pumpWidget(
        MaterialApp(
          theme: buildTheme(b, AppAccent.ocean),
          home: Builder(
            builder: (context) {
              if (b == Brightness.dark) {
                dark = Feature.lesson.color(context);
              } else {
                light = Feature.lesson.color(context);
              }
              return const SizedBox();
            },
          ),
        ),
      );
      // MaterialApp tema değişimini birkaç karede canlandırır.
      await tester.pumpAndSettle();
    }
    expect(dark, AppAccent.ocean.spark);
    expect(light, AppAccent.ocean.dark);
  });
}
