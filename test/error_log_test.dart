import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/error_reporting.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('hatalar en yeni başta, en fazla 20 kayıt tutulur', () async {
    SharedPreferences.setMockInitialValues({});
    final log = ErrorLog(await SharedPreferences.getInstance());

    for (var i = 0; i < 25; i++) {
      await log.record(StateError('hata $i'), StackTrace.current);
    }
    final entries = log.entries;
    expect(entries, hasLength(ErrorLog.capacity));
    expect(entries.first.message, contains('hata 24'));
    expect(entries.first.stack.split('\n').length, lessThanOrEqualTo(8));

    final report = log.report(appVersion: '1.2.0');
    expect(report, startsWith('Paceora 1.2.0 hata kaydı'));
    expect(report, contains('hata 24'));

    await log.clear();
    expect(log.entries, isEmpty);
  });

  test('bozuk kayıt satırı atlanır', () async {
    SharedPreferences.setMockInitialValues({
      ErrorLog.key: ['bozuk', '{"t":"2026-11-20T10:00:00.000","m":"x","s":""}'],
    });
    final log = ErrorLog(await SharedPreferences.getInstance());
    expect(log.entries.single.message, 'x');
  });
}
