import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:paceora/app/constants.dart';
import 'package:paceora/app/error_reporting.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/gemini_service.dart';
import 'package:paceora/data/placement.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/reminder_service.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/data/settings_providers.dart';
import 'package:paceora/main.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'scroll_helper.dart';

/// İzin cevabı ayarlanabilen, çağrıları kaydeden sahte hatırlatma servisi.
class _FakeReminders implements ReminderService {
  _FakeReminders({this.grant = true});

  bool grant;
  final scheduled = <TimeOfDay>[];
  var cancels = 0;

  @override
  Future<bool> requestPermission() async => grant;

  @override
  Future<void> scheduleDaily(
    TimeOfDay time, {
    ReminderContent content = ReminderContent.fallback,
    bool skipToday = false,
  }) async => scheduled.add(time);

  @override
  Future<void> cancel() async => cancels++;
}

Future<void> _advance(WidgetTester tester) async {
  for (var i = 0; i < 15; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

void main() {
  group('ReminderNotifier', () {
    late _FakeReminders reminders;
    late ProviderContainer container;
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      reminders = _FakeReminders();
      container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          reminderServiceProvider.overrideWithValue(reminders),
        ],
      );
    });
    tearDown(() => container.dispose());

    test('izin verilmezse kapalı kalır, hiçbir şey kurulmaz', () async {
      reminders.grant = false;
      final ok = await container
          .read(reminderProvider.notifier)
          .setEnabled(true);
      expect(ok, isFalse);
      expect(container.read(reminderProvider).enabled, isFalse);
      expect(reminders.scheduled, isEmpty);
      expect(prefs.getBool(AppConstants.prefReminderEnabled), isNull);
    });

    test(
      'açılınca kurulur, saat değişince yeniden kurulur, kapanınca iptal',
      () async {
        final notifier = container.read(reminderProvider.notifier);
        expect(await notifier.setEnabled(true), isTrue);
        expect(reminders.scheduled, hasLength(1));
        expect(prefs.getBool(AppConstants.prefReminderEnabled), isTrue);

        await notifier.setTime(const TimeOfDay(hour: 8, minute: 30));
        expect(reminders.scheduled.last, const TimeOfDay(hour: 8, minute: 30));
        expect(prefs.getInt(AppConstants.prefReminderMinutes), 8 * 60 + 30);

        await notifier.setEnabled(false);
        expect(reminders.cancels, 1);
        expect(container.read(reminderProvider).enabled, isFalse);
      },
    );

    test('kapalıyken saat değişirse yalnızca kaydedilir', () async {
      await container
          .read(reminderProvider.notifier)
          .setTime(const TimeOfDay(hour: 21, minute: 0));
      expect(reminders.scheduled, isEmpty);
      expect(container.read(reminderProvider).time.hour, 21);
    });
  });

  group('Ayarlar ekranı', () {
    late AppDatabase db;
    late Repository repository;

    setUp(() async {
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = Repository(db);
      await repository.saveProfile(name: 'Efe', level: 'B1', dailyMinutes: 10);
      FlutterSecureStorage.setMockInitialValues({});
    });
    tearDown(() => db.close());

    Future<SharedPreferences> openSettings(
      WidgetTester tester, {
      Map<String, Object> prefs = const {},
      List<Override> overrides = const [],
    }) async {
      // Ayarlar listesi uzun; telefona yakın bir ekran.
      tester.view.physicalSize = const Size(1080, 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      SharedPreferences.setMockInitialValues(prefs);
      final instance = await SharedPreferences.getInstance();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(instance),
            databaseProvider.overrideWithValue(db),
            ...overrides,
          ],
          child: const PaceoraApp(onboardingDone: true),
        ),
      );
      await _advance(tester);
      await tester.tap(find.text('Ayarlar'));
      await _advance(tester);
      return instance;
    }

    testWidgets('bildirim izni verilmezse yol gösteren mesaj çıkar', (
      tester,
    ) async {
      final reminders = _FakeReminders(grant: false);
      await openSettings(
        tester,
        overrides: [reminderServiceProvider.overrideWithValue(reminders)],
      );
      await scrollIntoView(tester, find.text('Her gün hatırlat'));
      await tester.tap(find.byType(Switch).first);
      await _advance(tester);

      expect(find.textContaining('Bildirim izni verilmedi'), findsOneWidget);
      expect(reminders.scheduled, isEmpty);
    });

    testWidgets('API anahtarı kaydedilir ve silinir', (tester) async {
      await openSettings(tester);
      await scrollIntoView(tester, find.text('Gemini API anahtarı'));
      await tester.tap(find.text('Gemini API anahtarı'));
      await _advance(tester);

      await tester.enterText(find.byType(TextField), 'AIza-test');
      await tester.tap(find.widgetWithText(FilledButton, 'Kaydet'));
      await _advance(tester);
      expect(find.text('Anahtar kaydedildi.'), findsOneWidget);
      const storage = FlutterSecureStorage();
      expect(await storage.read(key: apiKeyStorageKey), 'AIza-test');
      // Mesaj kaybolsun; yoksa sayfanın düğmelerinin üstünde durur.
      await tester.pump(const Duration(seconds: 5));
      await _advance(tester);

      await tester.tap(find.text('Gemini API anahtarı'));
      await _advance(tester);
      await tester.tap(find.widgetWithText(OutlinedButton, 'Sil'));
      await _advance(tester);
      expect(find.textContaining('Kendi anahtarın silindi'), findsOneWidget);
      expect(await storage.read(key: apiKeyStorageKey), isNull);
    });

    testWidgets('bağlantı testi geçersiz anahtarı anlaşılır gösterir', (
      tester,
    ) async {
      final client = MockClient(
        (request) async => http.Response.bytes(
          utf8.encode(
            jsonEncode({
              'error': {'code': 400, 'message': 'API key not valid.'},
            }),
          ),
          400,
        ),
      );
      await openSettings(
        tester,
        overrides: [
          geminiServiceProvider.overrideWithValue(
            GeminiService(client: client, apiKey: 'yanlis'),
          ),
        ],
      );
      await scrollIntoView(tester, find.text('Bağlantıyı test et'));
      await tester.tap(find.text('Bağlantıyı test et'));
      await _advance(tester);

      expect(find.text('Bağlantı kurulamadı'), findsOneWidget);
      expect(find.text('Hata'), findsOneWidget);
    });

    testWidgets('sıfırlamadan vazgeçilirse hiçbir şey silinmez', (
      tester,
    ) async {
      await openSettings(tester);
      await scrollIntoView(tester, find.text('Verileri sıfırla'));
      await tester.tap(find.text('Verileri sıfırla'));
      await _advance(tester);
      await tester.tap(find.text('Vazgeç'));
      await _advance(tester);

      expect(await repository.profile(), isNotNull);
    });

    testWidgets('sıfırlama verileri ve ilerleme anahtarlarını siler', (
      tester,
    ) async {
      final prefs = await openSettings(
        tester,
        prefs: {
          AppConstants.prefOnboardingDone: true,
          PlacementRecord.levelKey: 'B1',
          'streak_seen_milestone': 7,
          'wardrobe_owned': ['crimson'],
          'seen_badges': ['ilk_ders'],
          AppConstants.prefThemeMode: 'dark',
        },
      );
      await scrollIntoView(tester, find.text('Verileri sıfırla'));
      await tester.tap(find.text('Verileri sıfırla'));
      await _advance(tester);
      await tester.tap(find.widgetWithText(FilledButton, 'Sil'));
      await _advance(tester);

      expect(await repository.profile(), isNull);
      expect(prefs.getBool(AppConstants.prefOnboardingDone), isFalse);
      for (final key in [
        PlacementRecord.levelKey,
        'streak_seen_milestone',
        'wardrobe_owned',
      ]) {
        expect(prefs.containsKey(key), isFalse, reason: key);
      }
      // Kutlama sistemi yeni profil için boş bir başlangıç kaydeder.
      expect(
        prefs.getStringList('seen_badges') ?? [],
        isNot(contains('ilk_ders')),
      );
      // Cihaz tercihleri (tema) kalır.
      expect(prefs.getString(AppConstants.prefThemeMode), 'dark');
      expect(find.text('Merhaba! Sana nasıl hitap edelim?'), findsOneWidget);
    });

    testWidgets('hata kaydı temizlenebilir', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final seed = await SharedPreferences.getInstance();
      await ErrorLog(seed).record(StateError('çöktü'), StackTrace.empty);
      final prefs = await openSettings(
        tester,
        prefs: {ErrorLog.key: seed.getStringList(ErrorLog.key)!},
      );
      await scrollIntoView(tester, find.text('Hata kaydı'));
      expect(find.text('1 hata kaydı · yalnızca bu cihazda'), findsOneWidget);
      await tester.tap(find.text('Hata kaydı'));
      await _advance(tester);
      expect(find.textContaining('çöktü'), findsOneWidget);
      await tester.tap(find.text('Temizle'));
      await _advance(tester);

      expect(prefs.containsKey(ErrorLog.key), isFalse);
      expect(find.text('Kayıtlı hata yok'), findsOneWidget);
    });
  });
}
