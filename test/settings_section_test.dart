import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/theme.dart';
import 'package:paceora/features/settings/settings_section.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  test('bölüm sırası, başlıkları ve kart adları', () {
    expect(SettingsSection.values.map((s) => s.title), [
      'ÇALIŞMA',
      'GÖRÜNÜM',
      'BİLDİRİMLER',
      'VERİLERİM',
      'GELİŞMİŞ',
      'HAKKINDA',
    ]);
    expect(SettingsSection.values.map((s) => s.label), [
      'Çalışma',
      'Görünüm',
      'Bildirimler',
      'Verilerim',
      'Gelişmiş',
      'Hakkında',
    ]);
    // Her kartın kendi simgesi var.
    expect(SettingsSection.values.map((s) => s.icon).toSet(), hasLength(6));
  });

  for (final dark in [true, false]) {
    testWidgets(
      'nötr simge rengi kutusunda okunur (${dark ? 'koyu' : 'açık'})',
      (tester) async {
        late BuildContext context;
        await tester.pumpWidget(
          MaterialApp(
            theme: buildTheme(
              dark ? Brightness.dark : Brightness.light,
              AppAccent.lime,
            ),
            home: Builder(
              builder: (c) {
                context = c;
                return const SizedBox();
              },
            ),
          ),
        );
        final fg = SettingsSection.iconColor(context);
        final bg = SettingsSection.iconTint(context);
        // Simgeler için WCAG 3:1 (metin dışı öğe).
        expect(_contrast(fg, bg), greaterThanOrEqualTo(3));
        // Renksiz: doygunluğu düşük, gri bir ton.
        expect(HSLColor.fromColor(fg).saturation, lessThan(0.35));
      },
    );
  }
}
