import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:paceora/app/constants.dart';
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
}

void main() {
  test('hatırlatma metni seriye göre kişiselleşir', () {
    expect(reminderContentFor(streak: 0, next: 3).body, contains('Yeni bir seri'));
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
