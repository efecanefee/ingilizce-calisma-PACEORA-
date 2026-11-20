import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/constants.dart';
import 'package:paceora/app/theme.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('bilinmeyen ya da boş ad lime vurguya düşer', () {
    expect(AppAccent.fromName(null), AppAccent.lime);
    expect(AppAccent.fromName('yok'), AppAccent.lime);
    expect(AppAccent.fromName('ocean'), AppAccent.ocean);
  });

  test('vurgu seçimi kaydedilir ve geri okunur', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    );
    addTearDown(container.dispose);

    expect(container.read(accentProvider), AppAccent.lime);
    await container.read(accentProvider.notifier).save(AppAccent.lavender);
    expect(container.read(accentProvider), AppAccent.lavender);
    expect(prefs.getString(AppConstants.prefAccent), 'lavender');
  });

  test('tema seçilen vurguyu birincil renk yapar', () {
    for (final accent in AppAccent.values) {
      expect(
        colorSchemeFor(Brightness.dark, accent).primary,
        accent.spark,
      );
      expect(
        colorSchemeFor(Brightness.light, accent).primary,
        accent.dark,
      );
    }
  });

  test('her vurguda düğme yazısı okunabilir (WCAG AA, 4.5:1)', () {
    double ratio(Color a, Color b) {
      final la = a.computeLuminance();
      final lb = b.computeLuminance();
      final hi = la > lb ? la : lb;
      final lo = la > lb ? lb : la;
      return (hi + 0.05) / (lo + 0.05);
    }

    for (final accent in AppAccent.values) {
      final dark = colorSchemeFor(Brightness.dark, accent);
      final light = colorSchemeFor(Brightness.light, accent);
      expect(
        ratio(dark.primary, dark.onPrimary),
        greaterThanOrEqualTo(4.5),
        reason: '${accent.name} koyu',
      );
      expect(
        ratio(light.primary, light.onPrimary),
        greaterThanOrEqualTo(4.5),
        reason: '${accent.name} açık',
      );
      // Açık zeminde vurgulu metin (accentDark) arka plana karşı.
      expect(
        ratio(accent.dark, light.surface),
        greaterThanOrEqualTo(4.5),
        reason: '${accent.name} açık metin',
      );
    }
  });

  testWidgets('tema uzantısı seçili vurguyu taşır', (tester) async {
    late PaceColors colors;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildTheme(Brightness.dark, AppAccent.rose),
        home: Builder(
          builder: (context) {
            colors = context.pace;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(colors.accent, AppAccent.rose.spark);
    expect(colors.accentDark, AppAccent.rose.dark);
  });
}
