import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Günlük çalışma hatırlatması.
///
/// Arayüz olarak ayrıldı: widget testlerinde ve web'de bildirim eklentisinin
/// yerel tarafı yok, orada [NoopReminderService] kullanılır.
abstract class ReminderService {
  /// Bildirim izni ister; verildiyse true.
  Future<bool> requestPermission();

  /// Her gün [time]'da tekrarlayan hatırlatmayı kurar (öncekini değiştirir).
  Future<void> scheduleDaily(TimeOfDay time);

  Future<void> cancel();
}

class NoopReminderService implements ReminderService {
  const NoopReminderService();

  @override
  Future<bool> requestPermission() async => true;

  @override
  Future<void> scheduleDaily(TimeOfDay time) async {}

  @override
  Future<void> cancel() async {}
}

/// `flutter_local_notifications` ile yerel, sunucusuz hatırlatma.
///
/// Bildirim yerel saat diliminde zamanlanır; yaz saati değişse de aynı
/// duvar saatinde gelir. Android'de kesin alarm izni varsa tam saatinde,
/// yoksa "inexact" modda kurulur — o modda sistem bildirimi bir saate kadar
/// geciktirebildiği için izin, hatırlatma açılırken bir kez istenir.
class LocalReminderService implements ReminderService {
  LocalReminderService._(this._plugin);

  static const _notificationId = 7001;
  static const _channelId = 'daily_reminder';

  /// Tek renkli bildirim simgesi (res/drawable/ic_stat_paceora.xml).
  static const _smallIcon = 'ic_stat_paceora';

  final FlutterLocalNotificationsPlugin _plugin;

  /// Eklentiyi ve saat dilimi verisini hazırlar.
  ///
  /// Desteklenmeyen platformda ya da hata olursa sessizce [NoopReminderService]
  /// döner; hatırlatma çalışmasa da uygulama açılmalı.
  static Future<ReminderService> create() async {
    if (kIsWeb ||
        !(defaultTargetPlatform == TargetPlatform.android ||
            defaultTargetPlatform == TargetPlatform.iOS)) {
      return const NoopReminderService();
    }
    try {
      tzdata.initializeTimeZones();
      final local = await FlutterTimezone.getLocalTimezone();
      tz.setLocalLocation(tz.getLocation(local.identifier));

      final plugin = FlutterLocalNotificationsPlugin();
      await plugin.initialize(
        settings: const InitializationSettings(
          android: AndroidInitializationSettings(_smallIcon),
          // İzin, kullanıcı hatırlatmayı açtığında istenir; açılışta değil.
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      return LocalReminderService._(plugin);
    } catch (e) {
      debugPrint('Hatırlatma servisi başlatılamadı: $e');
      return const NoopReminderService();
    }
  }

  @override
  Future<bool> requestPermission() async {
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    if (android != null) {
      final allowed = await android.requestNotificationsPermission() ?? false;
      // Android 14+ kesin alarmı varsayılan olarak kapalı başlatır; izin
      // verilmezse hatırlatma yine kurulur, yalnızca gecikebilir.
      if (allowed &&
          !(await android.canScheduleExactNotifications() ?? false)) {
        await android.requestExactAlarmsPermission();
      }
      return allowed;
    }
    final ios = _plugin
        .resolvePlatformSpecificImplementation<
          IOSFlutterLocalNotificationsPlugin
        >();
    if (ios != null) {
      return await ios.requestPermissions(
            alert: true,
            badge: true,
            sound: true,
          ) ??
          false;
    }
    return false;
  }

  @override
  Future<void> scheduleDaily(TimeOfDay time) async {
    await cancel();
    final android = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final exact = await android?.canScheduleExactNotifications() ?? false;

    await _plugin.zonedSchedule(
      id: _notificationId,
      title: 'İngilizce zamanı 🔥',
      body: 'Bugünkü dersin hazır. Birkaç dakikada serini koru!',
      scheduledDate: nextInstanceOf(time, tz.TZDateTime.now(tz.local)),
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          'Günlük hatırlatma',
          channelDescription: 'Her gün seçtiğin saatte çalışma hatırlatması',
          importance: Importance.high,
          priority: Priority.high,
          icon: _smallIcon,
          color: Color(0xFF5A7414),
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: exact
          ? AndroidScheduleMode.exactAllowWhileIdle
          : AndroidScheduleMode.inexactAllowWhileIdle,
      // Yalnızca saat/dakika eşleşir: her gün tekrarlar.
      matchDateTimeComponents: DateTimeComponents.time,
    );
  }

  @override
  Future<void> cancel() => _plugin.cancel(id: _notificationId);
}

/// [now]'dan sonraki ilk [time] anı — bugün geçtiyse yarın.
tz.TZDateTime nextInstanceOf(TimeOfDay time, tz.TZDateTime now) {
  var scheduled = tz.TZDateTime(
    now.location,
    now.year,
    now.month,
    now.day,
    time.hour,
    time.minute,
  );
  if (!scheduled.isAfter(now)) {
    scheduled = tz.TZDateTime(
      now.location,
      now.year,
      now.month,
      now.day + 1,
      time.hour,
      time.minute,
    );
  }
  return scheduled;
}
