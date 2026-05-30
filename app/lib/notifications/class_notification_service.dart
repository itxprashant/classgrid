import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/reminder_schedule.dart';

/// Local notifications for class reminders.
class ClassNotificationService {
  ClassNotificationService._();

  static final ClassNotificationService instance = ClassNotificationService._();

  static const _channelId = 'class_reminders';
  static const _channelName = 'Class reminders';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;

    tz_data.initializeTimeZones();
    final local = await FlutterTimezone.getLocalTimezone();
    tz.setLocalLocation(tz.getLocation(local.identifier));

    if (defaultTargetPlatform == TargetPlatform.linux) {
      await _plugin.initialize(
        settings: const InitializationSettings(
          linux: LinuxInitializationSettings(defaultActionName: 'Open'),
        ),
      );
      _ready = true;
      return;
    }

    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );
    await _plugin.initialize(
      settings: const InitializationSettings(
        android: androidInit,
        iOS: darwinInit,
        macOS: darwinInit,
      ),
    );

    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _channelId,
        _channelName,
        description: 'Reminders before your planned classes',
        importance: Importance.high,
      ),
    );
    await android?.requestNotificationsPermission();
    await android?.requestExactAlarmsPermission();

    await _plugin.cancel(id: 9001);
    await _plugin.cancel(id: 9002);

    _ready = true;
  }

  NotificationDetails get details => const NotificationDetails(
        android: AndroidNotificationDetails(
          _channelId,
          _channelName,
          channelDescription: 'Reminders before your planned classes',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  tz.TZDateTime localTzDateTime(DateTime when) {
    return tz.TZDateTime(
      tz.local,
      when.year,
      when.month,
      when.day,
      when.hour,
      when.minute,
      when.second,
    );
  }

  /// Schedule a one-shot local notification at [notifyAt].
  Future<bool> scheduleReminder({
    required String key,
    required String title,
    required String body,
    required DateTime notifyAt,
  }) async {
    if (!_ready) await init();
    if (!notifyAt.isAfter(DateTime.now())) return false;

    final id = notificationIdForKey(key);
    try {
      var mode = AndroidScheduleMode.inexactAllowWhileIdle;
      if (defaultTargetPlatform == TargetPlatform.android) {
        final android = _plugin.resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>();
        if (await android?.canScheduleExactNotifications() ?? false) {
          mode = AndroidScheduleMode.exactAllowWhileIdle;
        }
      }

      await _plugin.zonedSchedule(
        id: id,
        scheduledDate: localTzDateTime(notifyAt),
        notificationDetails: details,
        androidScheduleMode: mode,
        title: title,
        body: body,
      );
      return true;
    } catch (e) {
      debugPrint('[ClassNotificationService] schedule failed: $e');
      return false;
    }
  }

  Future<void> cancelReminder(String key) async {
    if (!_ready) return;
    await _plugin.cancel(id: notificationIdForKey(key));
  }
}
