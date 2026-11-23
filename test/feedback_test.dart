import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/constants.dart';
import 'package:paceora/app/error_reporting.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/feedback.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scroll_helper.dart';

Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('feedbackMailUri', () {
    test('alıcı, konu, sürüm ve platform hazır; boşluk + olmaz', () {
      final uri = feedbackMailUri(platform: 'android');
      expect(uri.scheme, 'mailto');
      expect(uri.path, AppConstants.supportEmail);
      expect(uri.toString(), isNot(contains('+')));
      final body = Uri.decodeComponent(
        uri.query.split('&').firstWhere((p) => p.startsWith('body=')).substring(5),
      );
      expect(body, contains('Sürüm: ${AppConstants.appVersion}'));
      expect(body, contains('Platform: android'));
    });

    test('uzun hata kaydı kısaltılır', () {
      final uri = feedbackMailUri(platform: 'ios', errorReport: 'x' * 5000);
      final body = Uri.decodeComponent(uri.query);
      expect('x'.allMatches(body).length, feedbackLogLimit);
    });
  });

  group('Ayarlar > Geri bildirim gönder', () {
    late AppDatabase db;
    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await Repository(db)
          .saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
    });
    tearDown(() => db.close());

    Future<List<Uri>> pumpSettings(
      WidgetTester tester, {
      bool withErrors = false,
      bool launchSucceeds = true,
    }) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      if (withErrors) {
        await ErrorLog(prefs).record(StateError('çöktü'), StackTrace.empty);
      }
      final launched = <Uri>[];
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            databaseProvider.overrideWithValue(db),
            mailLauncherProvider.overrideWithValue((uri) async {
              launched.add(uri);
              return launchSucceeds;
            }),
          ],
          child: const PaceoraApp(onboardingDone: true),
        ),
      );
      await _advance(tester);
      await tester.tap(find.text('Ayarlar'));
      await _advance(tester);
      await scrollIntoView(tester, find.text('Hakkında'));
      await tester.tap(find.text('Hakkında'));
      await _advance(tester);
      await scrollIntoView(tester, find.text('Geri bildirim gönder'));
      await tester.tap(find.text('Geri bildirim gönder'));
      await _advance(tester);
      return launched;
    }

    testWidgets('hata kaydı yoksa doğrudan e-posta açılır', (tester) async {
      final launched = await pumpSettings(tester);
      expect(launched, hasLength(1));
      expect(Uri.decodeComponent(launched.single.query), isNot(contains('çöktü')));
    });

    testWidgets('hata kaydı yalnızca işaretlenirse eklenir', (tester) async {
      final launched = await pumpSettings(tester, withErrors: true);
      expect(launched, isEmpty);
      expect(find.text('Hata kaydını ekle (1)'), findsOneWidget);
      await tester.tap(find.text('Hata kaydını ekle (1)'));
      await tester.pump();
      await tester.tap(find.text('E-postayı aç'));
      await _advance(tester);
      expect(Uri.decodeComponent(launched.single.query), contains('çöktü'));
    });

    testWidgets('e-posta uygulaması yoksa adres kopyalanır', (tester) async {
      String? copied;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String?;
          }
          return null;
        },
      );
      await pumpSettings(tester, launchSucceeds: false);
      expect(copied, AppConstants.supportEmail);
      expect(find.textContaining('Adres kopyalandı'), findsOneWidget);
    });
  });
}
