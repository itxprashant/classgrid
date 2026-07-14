import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;

import '../core/reminder_schedule.dart';

typedef NotificationTapHandler = void Function(String? payload);

/// Local notifications for class reminders and attendance prompts.
class ClassNotificationService {
  ClassNotificationService._();

  static final ClassNotificationService instance = ClassNotificationService._();

  static const _channelId = 'class_reminders';
  static const _channelName = 'Class reminders';
  static const _attendanceChannelId = 'class_attendance_prompts';
  static const _attendanceChannelName = 'Attendance prompts';
  static const pushChannelId = 'classgrid_push';
  static const pushChannelName = 'ClassGrid updates';

  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;
  NotificationTapHandler? onNotificationTap;
  final Set<String> _scheduledAttendPromptKeys = {};

  Future<void> init({NotificationTapHandler? onTap}) async {
    if (onTap != null) onNotificationTap = onTap;
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
      onDidReceiveNotificationResponse: (response) {
        onNotificationTap?.call(response.payload);
      },
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
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        _attendanceChannelId,
        _attendanceChannelName,
        description: 'Remind you to mark attendance after class',
        importance: Importance.high,
      ),
    );
    await android?.createNotificationChannel(
      const AndroidNotificationChannel(
        pushChannelId,
        pushChannelName,
        description: 'Semester updates and announcements from ClassGrid',
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
    _scheduledAttendPromptKeys.remove(key);
  }

  NotificationDetails get attendanceDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          _attendanceChannelId,
          _attendanceChannelName,
          channelDescription: 'Remind you to mark attendance after class',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  NotificationDetails get pushDetails => const NotificationDetails(
        android: AndroidNotificationDetails(
          pushChannelId,
          pushChannelName,
          channelDescription: 'Semester updates and announcements from ClassGrid',
          importance: Importance.high,
          priority: Priority.high,
        ),
        iOS: DarwinNotificationDetails(),
      );

  /// Immediate notification for FCM broadcast messages.
  Future<void> showPushNotification({
    required String title,
    required String body,
    int? id,
  }) async {
    if (!_ready) await init();
    final notifyId = id ?? DateTime.now().millisecondsSinceEpoch.remainder(100000);
    await _plugin.show(
      id: notifyId,
      title: title,
      body: body,
      notificationDetails: pushDetails,
    );
  }

  Future<bool> scheduleAttendancePrompt({
    required String key,
    required String title,
    required String body,
    required DateTime notifyAt,
    required String payload,
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
        notificationDetails: attendanceDetails,
        androidScheduleMode: mode,
        title: title,
        body: body,
        payload: payload,
      );
      _scheduledAttendPromptKeys.add(key);
      return true;
    } catch (e) {
      debugPrint('[ClassNotificationService] attendance schedule failed: $e');
      return false;
    }
  }

  Future<void> cancelAttendPromptsExcept(Set<String> keepKeys) async {
    if (!_ready) return;
    final toCancel = _scheduledAttendPromptKeys.where((k) => !keepKeys.contains(k)).toList();
    for (final key in toCancel) {
      await _plugin.cancel(id: notificationIdForKey(key));
      _scheduledAttendPromptKeys.remove(key);
    }
  }
}
