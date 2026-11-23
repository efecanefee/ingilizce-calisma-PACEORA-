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
import 'package:paceora/app/mascot.dart';
import 'package:paceora/app/welcome_tour.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/gemini_service.dart';
import 'package:paceora/data/placement.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/reminder_service.dart';
import 'package:paceora/data/repository.dart';
import 'package:paceora/data/settings_providers.dart';
import 'package:paceora/features/settings/settings_screen.dart';
import 'package:paceora/features/settings/settings_section.dart';
import 'package:paceora/features/settings/widgets/settings_group.dart';
import 'package:paceora/features/settings/widgets/settings_tile.dart';
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
      bool tall = false,
      bool smallPhone = false,
    }) async {
      // Ayarlar listesi uzun; telefona yakın bir ekran. [tall] tüm listenin
      // aynı anda çizilmesi için çok uzun bir ekran verir.
      // [smallPhone]: 360 dp genişlik ve 1.3 yazı ölçeği.
      tester.view.physicalSize = smallPhone
          ? const Size(900, 1600)
          : Size(1080, tall ? 9000 : 2400);
      tester.view.devicePixelRatio = 2.5;
      addTearDown(tester.view.reset);
      if (smallPhone) {
        tester.platformDispatcher.textScaleFactorTestValue = 1.3;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
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

    /// Ana sayfadaki kategori kartına dokunup bölüm sayfasını açar.
    Future<void> openSection(
      WidgetTester tester,
      SettingsSection section,
    ) async {
      final card = find.byKey(ValueKey('settings-${section.name}'));
      // Önceki bölüm için aşağı kaydırılmış olabilir; listenin başına dön.
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 5000));
      await _advance(tester);
      await scrollIntoView(tester, card);
      await tester.tap(card);
      await _advance(tester);
      expect(find.byType(SettingsSectionPage), findsOneWidget);
    }

    Future<void> goBack(WidgetTester tester) async {
      Navigator.of(tester.element(find.byType(SettingsSectionPage))).pop();
      await _advance(tester);
    }

    testWidgets('bildirim izni verilmezse yol gösteren mesaj çıkar', (
      tester,
    ) async {
      final reminders = _FakeReminders(grant: false);
      await openSettings(
        tester,
        overrides: [reminderServiceProvider.overrideWithValue(reminders)],
      );
      await openSection(tester, SettingsSection.notifications);
      await tester.tap(find.byType(Switch).first);
      await _advance(tester);

      expect(find.textContaining('Bildirim izni verilmedi'), findsOneWidget);
      expect(reminders.scheduled, isEmpty);
    });

    testWidgets('API anahtarı kaydedilir ve silinir', (tester) async {
      await openSettings(tester);
      await openSection(tester, SettingsSection.advanced);
      await tester.tap(find.text('Kendi Gemini anahtarın'));
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

      await tester.tap(find.text('Kendi Gemini anahtarın'));
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
      await openSection(tester, SettingsSection.advanced);
      await tester.tap(find.text('Bağlantıyı test et'));
      await _advance(tester);

      expect(find.text('Bağlantı kurulamadı'), findsOneWidget);
      expect(find.text('Hata'), findsOneWidget);
    });

    testWidgets('sıfırlamadan vazgeçilirse hiçbir şey silinmez', (
      tester,
    ) async {
      await openSettings(tester);
      await openSection(tester, SettingsSection.data);
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
      await openSection(tester, SettingsSection.data);
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
      await openSection(tester, SettingsSection.advanced);
      expect(find.text('1 hata kaydı · yalnızca bu cihazda'), findsOneWidget);
      await tester.tap(find.text('Hata kaydı'));
      await _advance(tester);
      expect(find.textContaining('çöktü'), findsOneWidget);
      await tester.tap(find.text('Temizle'));
      await _advance(tester);

      expect(prefs.containsKey(ErrorLog.key), isFalse);
      expect(find.text('Kayıtlı hata yok'), findsOneWidget);
    });

    Finder inSettings(Finder finder) =>
        find.descendant(of: find.byType(SettingsScreen), matching: finder);

    testWidgets(
      'ana sayfa: Pace\'li profil kartı ve sırayla kategori kartları',
      (tester) async {
        await openSettings(tester, tall: true);

        expect(inSettings(find.byType(EquippedPace)), findsOneWidget);
        final tops = [
          for (final s in SettingsSection.values)
            tester.getTopLeft(find.byKey(ValueKey('settings-${s.name}'))),
        ];
        // Kartlar iki sütunlu: sol-sağ, sonra alt satır.
        expect(tops[0].dy, tops[1].dy);
        expect(tops[0].dx, lessThan(tops[1].dx));
        expect(tops[2].dy, greaterThan(tops[0].dy));
        expect(tops[4].dy, greaterThan(tops[2].dy));
        expect(tops[5].dy, greaterThan(tops[4].dy));
        // Kartlar güncel değeri özetler; uzun ayar listesi ana sayfada yok.
        expect(inSettings(find.text('10 dk · B1')), findsNothing);
        expect(inSettings(find.text('15 dk · B1')), findsOneWidget);
        expect(inSettings(find.text('Koyu tema')), findsOneWidget);
        expect(inSettings(find.text('Hatırlatma kapalı')), findsOneWidget);
        expect(inSettings(find.byType(SettingsGroup)), findsNothing);
        expect(inSettings(find.text('YAPAY ZEKA')), findsNothing);
        expect(inSettings(find.text('Hata defterim')), findsNothing);
      },
    );

    testWidgets('satırlar doğru bölüm sayfalarında', (tester) async {
      await openSettings(tester, tall: true);
      final expected = {
        SettingsSection.study: [
          'Seviye',
          'Günlük çalışma süresi',
          'Haftalık programı yenile',
        ],
        SettingsSection.appearance: [
          'Tema',
          'Vurgu rengi',
          'Titreşim',
          'Ses efektleri',
        ],
        SettingsSection.notifications: ['Her gün hatırlat'],
        SettingsSection.data: [
          'Verileri dışa aktar',
          'Yedekten geri yükle',
          'Verileri sıfırla',
        ],
        SettingsSection.advanced: [
          'Kendi Gemini anahtarın',
          'Bağlantıyı test et',
          'Hata kaydı',
        ],
        SettingsSection.about: [
          'Sürüm',
          'Gizlilik',
          'Tanıtımı yeniden izle',
          'Geri bildirim gönder',
          'Açık kaynak lisansları',
        ],
      };
      for (final MapEntry(key: section, value: titles) in expected.entries) {
        await openSection(tester, section);
        // Sayfa başlığı bölüm adı; grup başlığı tekrar yazılmaz.
        expect(
          find.descendant(
            of: find.byType(AppBar),
            matching: find.text(section.label),
          ),
          findsOneWidget,
        );
        expect(find.text(section.title), findsNothing);
        for (final title in titles) {
          expect(find.text(title), findsOneWidget, reason: section.label);
        }
        // Her satır aynı ortak görünümü kullanır.
        expect(
          find.byType(ListTile),
          findsNWidgets(tester.widgetList(find.byType(SettingsTile)).length),
        );
        await goBack(tester);
      }
    });

    for (final mode in ['dark', 'light']) {
      testWidgets('simgeler nötr, yalnızca sıfırlama hata renginde ($mode)', (
        tester,
      ) async {
        await openSettings(
          tester,
          tall: true,
          prefs: {AppConstants.prefThemeMode: mode},
        );
        final context = tester.element(find.byType(SettingsScreen));
        final scheme = Theme.of(context).colorScheme;
        expect(Theme.of(context).brightness == Brightness.dark, mode == 'dark');

        // Ana sayfadaki kart simgeleri nötr.
        for (final s in SettingsSection.values) {
          final icon = tester.widget<Icon>(inSettings(find.byIcon(s.icon)));
          expect(icon.color, scheme.onSurfaceVariant, reason: s.label);
        }

        await openSection(tester, SettingsSection.data);
        Color? iconColor(IconData icon) =>
            tester.widget<Icon>(find.byIcon(icon)).color;
        expect(iconColor(Icons.delete_forever_rounded), scheme.error);
        expect(iconColor(Icons.upload_file_rounded), scheme.onSurfaceVariant);
        expect(iconColor(Icons.restore_rounded), scheme.onSurfaceVariant);
        final errorIcons = tester
            .widgetList<Icon>(find.byType(Icon))
            .where((i) => i.color == scheme.error);
        expect(errorIcons, hasLength(1));
        await goBack(tester);

        await openSection(tester, SettingsSection.appearance);
        expect(iconColor(Icons.contrast_rounded), scheme.onSurfaceVariant);
      });
    }

    testWidgets('günlük süre seçicisi açıklamalarla seçenekleri gösterir', (
      tester,
    ) async {
      await openSettings(tester);
      await openSection(tester, SettingsSection.study);
      expect(find.text('Günde 15 dakika'), findsOneWidget);
      await tester.tap(find.text('Günlük çalışma süresi'));
      await _advance(tester);

      for (final minutes in AppConstants.dailyMinuteOptions) {
        expect(find.text('$minutes dakika'), findsOneWidget);
        expect(
          find.text(AppConstants.dailyMinuteHint(minutes)),
          findsOneWidget,
        );
      }
      await tester.tap(find.text('30 dakika'));
      await _advance(tester);

      expect((await repository.profile())!.dailyMinutes, 30);
      expect(find.text('Günde 30 dakika'), findsOneWidget);
      expect(find.text('Programı yenile'), findsOneWidget);

      // Ana sayfadaki kart da yeni süreyi gösterir.
      await tester.pump(const Duration(seconds: 5));
      await goBack(tester);
      expect(find.text('30 dk · B1'), findsOneWidget);
    });

    for (final mode in ['dark', 'light']) {
      testWidgets('360 dp ve büyük yazıda taşma yok ($mode)', (tester) async {
        await openSettings(
          tester,
          smallPhone: true,
          prefs: {
            AppConstants.prefThemeMode: mode,
            AppConstants.prefReminderEnabled: true,
          },
        );
        expect(tester.takeException(), isNull);
        for (final section in SettingsSection.values) {
          await openSection(tester, section);
          expect(tester.takeException(), isNull, reason: section.label);
          for (var i = 0; i < 6; i++) {
            await tester.drag(
              find.byType(Scrollable).last,
              const Offset(0, -300),
            );
            await _advance(tester);
            expect(tester.takeException(), isNull, reason: section.label);
          }
          await goBack(tester);
        }
        // Süre seçicisi de dar ekranda sığar.
        await openSection(tester, SettingsSection.study);
        await tester.tap(find.text('Günlük çalışma süresi'));
        await _advance(tester);
        expect(tester.takeException(), isNull, reason: 'süre seçicisi');
      });
    }

    for (final mode in ['dark', 'light']) {
      testWidgets('ana sayfa ve bölüm sayfaları erişilebilirlik yönergelerine '
          'uyar ($mode)', (tester) async {
        final handle = tester.ensureSemantics();
        await openSettings(
          tester,
          tall: true,
          prefs: {
            AppConstants.prefThemeMode: mode,
            AppConstants.prefReminderEnabled: true,
          },
        );
        Future<void> check() async {
          await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
          await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
          await expectLater(tester, meetsGuideline(textContrastGuideline));
        }

        await check();
        for (final section in SettingsSection.values) {
          await openSection(tester, section);
          if (section == SettingsSection.notifications) {
            expect(find.text('Hatırlatma saati'), findsOneWidget);
          }
          await check();
          await goBack(tester);
        }
        handle.dispose();
      });
    }

    testWidgets('API anahtarı satırı isteğe bağlı olduğunu söyler', (
      tester,
    ) async {
      await openSettings(
        tester,
        overrides: [
          geminiServiceProvider.overrideWithValue(
            GeminiService(apiKey: 'derleme-anahtari'),
          ),
        ],
      );
      await openSection(tester, SettingsSection.advanced);
      expect(find.textContaining('Genelde gerekmez'), findsOneWidget);
    });

    testWidgets('Tanıtımı yeniden izle turu başlatır', (tester) async {
      final prefs = await openSettings(tester);
      await openSection(tester, SettingsSection.about);
      await tester.tap(find.text('Tanıtımı yeniden izle'));
      await _advance(tester);
      expect(prefs.getBool(AppConstants.prefTourPending), isTrue);
      expect(find.byType(WelcomeTour), findsOneWidget);
    });
  });
}
