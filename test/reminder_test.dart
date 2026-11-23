import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/constants.dart';
import 'package:paceora/data/database.dart';
import 'package:paceora/data/providers.dart';
import 'package:paceora/data/reminder_service.dart';
import 'package:paceora/data/settings_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

class _FakeReminders implements ReminderService {
  final calls = <({ReminderContent content, bool skipToday})>[];

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleDaily(
    TimeOfDay time, {
    ReminderContent content = ReminderContent.fallback,
    bool skipToday = false,
  }) async => calls.add((content: content, skipToday: skipToday));

  @override
  Future<void> cancel() async {}

  final weekly = <({int weekday, TimeOfDay time})>[];
  final once = <({int id, DateTime at, ReminderContent content})>[];
  final cancelledIds = <int>[];

  @override
  Future<void> scheduleWeekly({
    required int id,
    required int weekday,
    required TimeOfDay time,
    required ReminderContent content,
  }) async => weekly.add((weekday: weekday, time: time));

  @override
  Future<void> scheduleAt({
    required int id,
    required DateTime at,
    required ReminderContent content,
  }) async => once.add((id: id, at: at, content: content));

  @override
  Future<void> cancelId(int id) async => cancelledIds.add(id);
}

void main() {
  test('günün kelimesi güne göre değişir, deste boşsa hazır listeden', () {
    final deck = [
      (word: 'a', meaning: '1'),
      (word: 'b', meaning: '2'),
      (word: 'c', meaning: '3'),
    ];
    final d1 = wordOfDayFor(deck, DateTime(2026, 11, 20));
    final d2 = wordOfDayFor(deck, DateTime(2026, 11, 21));
    expect(d1, isNot(d2));
    expect(wordOfDayFor(deck, DateTime(2026, 11, 20, 23)), d1);
    expect(wordOfDayFor(const [], DateTime(2026, 11, 20)).word, isNotEmpty);
  });

  test('hatırlatma önerisi: ortanca saatin yarım saat öncesi', () {
    DateTime at(int h, int m) => DateTime(2026, 11, 1, h, m);
    expect(suggestReminderTime([at(21, 0), at(21, 10)]), isNull);
    final s = suggestReminderTime([
      at(21, 0),
      at(21, 20),
      at(20, 50),
      at(22, 0),
      at(21, 10),
    ])!;
    expect((s.hour, s.minute), (20, 45));
    expect(
      suggestReminderTime(List.filled(5, at(4, 0)))!.hour,
      6,
      reason: "gece yarısından sonrası sabah 6'ya çekilir",
    );
  });

  test(
    'haftalık rapor Pazar 19:00, günün kelimesi ertesi sabah kurulur',
    () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final fake = _FakeReminders();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          reminderServiceProvider.overrideWithValue(fake),
          databaseProvider.overrideWithValue(
            AppDatabase.forTesting(NativeDatabase.memory()),
          ),
        ],
      );
      addTearDown(container.dispose);
      final notifier = container.read(extraNotificationsProvider.notifier);

      expect(await notifier.setWeekly(true), isTrue);
      expect(fake.weekly.single.weekday, DateTime.sunday);
      expect(fake.weekly.single.time, weeklyReportTime);

      await notifier.setWordOfDay(true);
      await notifier.scheduleNextWord(now: DateTime(2026, 11, 20, 10));
      final last = fake.once.last;
      expect(last.at, DateTime(2026, 11, 21, 9));
      expect(last.content.title, startsWith('Günün kelimesi:'));

      await notifier.setWeekly(false);
      expect(fake.cancelledIds, contains(NotificationIds.weeklyReport));
      expect(container.read(extraNotificationsProvider).weekly, isFalse);
    },
  );

  test('hatırlatma metni seriye göre kişiselleşir', () {
    expect(
      reminderContentFor(streak: 0, next: 3).body,
      contains('Yeni bir seri'),
    );
    expect(reminderContentFor(streak: 6, next: 7).title, contains('7 günlük'));
    expect(reminderContentFor(streak: 9, next: 14).title, contains('9 gün'));
  });

  test('bugün çalışıldıysa bildirim yarına kurulur', () {
    tzdata.initializeTimeZones();
    final now = tz.TZDateTime(tz.UTC, 2026, 11, 20, 9);
    const at = TimeOfDay(hour: 20, minute: 0);
    expect(nextInstanceOf(at, now).day, 20);
    expect(nextInstanceOf(at, now, skipToday: true).day, 21);
  });

  test('seri değişince açık hatırlatma yeni metinle yeniden kurulur', () async {
    SharedPreferences.setMockInitialValues({
      AppConstants.prefReminderEnabled: true,
    });
    final prefs = await SharedPreferences.getInstance();
    final fake = _FakeReminders();
    final container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        reminderServiceProvider.overrideWithValue(fake),
      ],
    );
    addTearDown(container.dispose);
    final notifier = container.read(reminderProvider.notifier);

    await notifier.personalize(streak: 6, nextMilestone: 7, doneToday: false);
    expect(fake.calls.last.content.title, contains('7 günlük'));
    expect(fake.calls.last.skipToday, isFalse);

    // Aynı durum tekrar gelirse boşuna yeniden kurulmaz.
    await notifier.personalize(streak: 6, nextMilestone: 7, doneToday: false);
    expect(fake.calls, hasLength(1));

    await notifier.personalize(streak: 7, nextMilestone: 14, doneToday: true);
    expect(fake.calls.last.skipToday, isTrue);
    expect(fake.calls.last.content.title, contains('7 gün'));
  });
}
