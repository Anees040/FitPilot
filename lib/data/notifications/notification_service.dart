import 'dart:io';

import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/domain/engines/reminder_scheduler.dart';

final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

class NotificationService {
  final FlutterLocalNotificationsPlugin _plugin = FlutterLocalNotificationsPlugin();
  bool _initialized = false;

  Future<void> initialize() async {
    if (_initialized) return;

    tz.initializeTimeZones();
    // Default location is local
    tz.setLocalLocation(tz.getLocation('UTC')); // Fallback, we could try to get local timezone if needed, or rely on system. Actually flutter_native_timezone is often used, but we can just use tz.local if set.
    // To keep it simple offline:
    // We can just schedule relative to now using zonedSchedule with DateTime components, but we need the correct timezone.
    
    const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
    const darwinInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    const initSettings = InitializationSettings(android: androidInit, iOS: darwinInit);

    await _plugin.initialize(settings: initSettings);
    _initialized = true;
  }

  Future<bool> requestPermissions() async {
    if (Platform.isIOS) {
      final iosImpl = _plugin.resolvePlatformSpecificImplementation<IOSFlutterLocalNotificationsPlugin>();
      return await iosImpl?.requestPermissions(alert: true, badge: true, sound: true) ?? false;
    } else if (Platform.isAndroid) {
      final androidImpl = _plugin.resolvePlatformSpecificImplementation<AndroidFlutterLocalNotificationsPlugin>();
      final granted = await androidImpl?.requestNotificationsPermission();
      return granted ?? false;
    }
    return false;
  }

  Future<void> syncSchedules(List<NotificationSchedule> schedules) async {
    if (!_initialized) await initialize();
    
    await _plugin.cancelAll();
    
    const androidDetails = AndroidNotificationDetails(
      'fitpilot_reminders',
      'Reminders & Alerts',
      channelDescription: 'Meal reminders and streak risk alerts',
      importance: Importance.high,
      priority: Priority.high,
    );
    const darwinDetails = DarwinNotificationDetails();
    const details = NotificationDetails(android: androidDetails, iOS: darwinDetails);
    
    // We get the local timezone offset to correctly schedule.
    // Instead of zonedSchedule which requires full TZ setup (tz.local), if we haven't loaded local timezone natively, 
    // we can calculate the duration from now and use zonedSchedule with UTC, or just use absolute time if timezone is UTC.
    // For simplicity, we just use tz.TZDateTime.from(schedule.scheduledTime, tz.local).
    for (final schedule in schedules) {
      // If we are in UTC fallback, this still works correctly because both DateTime.now() and scheduledTime are local in Dart,
      // and we convert to TZDateTime.
      final tzTime = tz.TZDateTime.from(schedule.scheduledTime, tz.local);
      
      await _plugin.zonedSchedule(
        id: schedule.id,
        title: schedule.title,
        body: schedule.body,
        scheduledDate: tzTime,
        notificationDetails: details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }
}
