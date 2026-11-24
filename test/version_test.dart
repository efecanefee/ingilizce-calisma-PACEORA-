import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/constants.dart';

void main() {
  test('Ayarlar\'daki sürüm pubspec ve değişiklik günlüğüyle aynı', () {
    final version = RegExp(
      r'^version: ([\d.]+)\+\d+',
      multiLine: true,
    ).firstMatch(File('pubspec.yaml').readAsStringSync())!.group(1);
    expect(AppConstants.appVersion, version);

    final latest = RegExp(
      r'^## ([\d.]+)',
      multiLine: true,
    ).firstMatch(File('CHANGELOG.md').readAsStringSync())!.group(1);
    expect(latest, version);
  });
}
