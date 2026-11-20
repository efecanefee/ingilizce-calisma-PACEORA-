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
}
