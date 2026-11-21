import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/feature_colors.dart';
import 'package:paceora/app/theme.dart';
import 'package:paceora/features/settings/settings_section.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  final hi = la > lb ? la : lb;
  final lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// Saydam [fg]'yi opak [bg] üstüne koyar (simge kutusunun gerçek zemini).
Color _over(Color fg, double alpha, Color bg) => Color.from(
  alpha: 1,
  red: fg.r * alpha + bg.r * (1 - alpha),
  green: fg.g * alpha + bg.g * (1 - alpha),
  blue: fg.b * alpha + bg.b * (1 - alpha),
);

/// sRGB → CIE Lab (D65); renk farkı için.
List<double> _lab(Color c) {
  double lin(double v) =>
      v <= 0.04045 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) as double;
  final r = lin(c.r), g = lin(c.g), b = lin(c.b);
  final x = (0.4124 * r + 0.3576 * g + 0.1805 * b) / 0.95047;
  final y = 0.2126 * r + 0.7152 * g + 0.0722 * b;
  final z = (0.0193 * r + 0.1192 * g + 0.9505 * b) / 1.08883;
  double f(double t) =>
      t > 0.008856 ? math.pow(t, 1 / 3) as double : 7.787 * t + 16 / 116;
  return [116 * f(y) - 16, 500 * (f(x) - f(y)), 200 * (f(y) - f(z))];
}

double _deltaE(Color a, Color b) {
  final la = _lab(a), lb = _lab(b);
  return math.sqrt(
    math.pow(la[0] - lb[0], 2) +
        math.pow(la[1] - lb[1], 2) +
        math.pow(la[2] - lb[2], 2),
  );
}

void main() {
  const darkCard = AppColors.graphite700;
  const lightCard = Colors.white;

  test('bölüm sırası ve başlıkları', () {
    expect(SettingsSection.values.map((s) => s.title), [
      'ÇALIŞMA',
      'GÖRÜNÜM',
      'BİLDİRİMLER',
      'VERİLERİM',
      'GELİŞMİŞ',
      'HAKKINDA',
    ]);
  });

  test('her bölüm rengi iki temada da okunur (WCAG AA 4.5:1)', () {
    for (final s in SettingsSection.values) {
      expect(
        _contrast(s.bright, darkCard),
        greaterThanOrEqualTo(4.5),
        reason: '${s.name} koyu kartta',
      );
      expect(
        _contrast(s.deep, lightCard),
        greaterThanOrEqualTo(4.5),
        reason: '${s.name} beyaz kartta',
      );
      // Simge, rengin yumuşak tonlu kutusunun üstünde durur.
      expect(
        _contrast(
          s.bright,
          _over(s.bright, SettingsSection.tintAlphaDark, darkCard),
        ),
        greaterThanOrEqualTo(4.5),
        reason: '${s.name} koyu simge kutusunda',
      );
      expect(
        _contrast(
          s.deep,
          _over(s.deep, SettingsSection.tintAlphaLight, lightCard),
        ),
        greaterThanOrEqualTo(4.5),
        reason: '${s.name} açık simge kutusunda',
      );
    }
  });

  test('bölüm renkleri birbirinden açıkça ayrılır', () {
    final sections = SettingsSection.values;
    for (var i = 0; i < sections.length; i++) {
      for (var j = i + 1; j < sections.length; j++) {
        final a = sections[i], b = sections[j];
        expect(
          _deltaE(a.bright, b.bright),
          greaterThan(15),
          reason: '${a.name}/${b.name} koyu',
        );
        expect(
          _deltaE(a.deep, b.deep),
          greaterThan(15),
          reason: '${a.name}/${b.name} açık',
        );
      }
    }
  });

  test('durum ve pratik bölümü renkleri kullanılmaz', () {
    final reserved = <Color>{
      AppColors.success,
      AppColors.successDark,
      AppColors.error,
      AppColors.errorDark,
      AppColors.warning,
      ...Feature.values.expand((f) => [f.bright, f.deep]).whereType<Color>(),
    };
    for (final s in SettingsSection.values) {
      expect(reserved, isNot(contains(s.bright)), reason: s.name);
      expect(reserved, isNot(contains(s.deep)), reason: s.name);
    }
  });
}
