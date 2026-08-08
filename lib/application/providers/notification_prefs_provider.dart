import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/domain/entities/notification_preferences.dart';
import 'package:fitpilot/core/utils/type_readers.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/notification_inbox_provider.dart';
import 'package:sqflite/sqflite.dart';
import 'dart:convert';

final notificationPrefsProvider = AsyncNotifierProvider<NotificationPrefsNotifier, NotificationPreferences>(
  NotificationPrefsNotifier.new,
);

class NotificationPrefsNotifier extends AsyncNotifier<NotificationPreferences> {
  @override
  Future<NotificationPreferences> build() async {
    final db = await ref.watch(databaseProvider.future);
    final rows = await db.query('notification_prefs', where: 'id = 1');
    if (rows.isEmpty) {
      // Default preferences
      return const NotificationPreferences();
    }
    
    final r = rows.first;
    return NotificationPreferences(
      mealRemindersEnabled: TolerantReader.readBool(r['meal_reminders_enabled']) ?? false,
      mealTimes: List<String>.from(jsonDecode(r['meal_times'] as String) as Iterable<dynamic>),
      streakRiskEnabled: TolerantReader.readBool(r['streak_risk_enabled']) ?? false,
      milestonesEnabled: TolerantReader.readBool(r['milestones_enabled']) ?? false,
      globalMute: TolerantReader.readBool(r['global_mute']) ?? false,
      // v23 columns. Read defensively: a row written before the migration has
      // them as NULL, which must fall back to the entity default rather than
      // crash or silently read as "on".
      burnRemindersEnabled:
          TolerantReader.readBool(r['burn_reminders_enabled']) ?? false,
      programRemindersEnabled:
          TolerantReader.readBool(r['program_reminders_enabled']) ?? false,
      weighInEnabled: TolerantReader.readBool(r['weigh_in_enabled']) ?? false,
      weighInDay: TolerantReader.readInt(r['weigh_in_day']) ?? 1,
      weighInTime: (r['weigh_in_time'] as String?) ?? '08:00',
      waterRemindersEnabled:
          TolerantReader.readBool(r['water_reminders_enabled']) ?? false,
      quietHoursEnabled:
          TolerantReader.readBool(r['quiet_hours_enabled']) ?? false,
      quietFrom: (r['quiet_from'] as String?) ?? '22:00',
      quietTo: (r['quiet_to'] as String?) ?? '07:00',
    );
  }

  Future<void> updatePrefs(NotificationPreferences newPrefs) async {
    final db = await ref.read(databaseProvider.future);
    await db.insert(
      'notification_prefs',
      {
        'id': 1,
        'meal_reminders_enabled': newPrefs.mealRemindersEnabled ? 1 : 0,
        'meal_times': jsonEncode(newPrefs.mealTimes),
        'streak_risk_enabled': newPrefs.streakRiskEnabled ? 1 : 0,
        'milestones_enabled': newPrefs.milestonesEnabled ? 1 : 0,
        'global_mute': newPrefs.globalMute ? 1 : 0,
        'burn_reminders_enabled': newPrefs.burnRemindersEnabled ? 1 : 0,
        'program_reminders_enabled': newPrefs.programRemindersEnabled ? 1 : 0,
        'weigh_in_enabled': newPrefs.weighInEnabled ? 1 : 0,
        'weigh_in_day': newPrefs.weighInDay,
        'weigh_in_time': newPrefs.weighInTime,
        'water_reminders_enabled': newPrefs.waterRemindersEnabled ? 1 : 0,
        'quiet_hours_enabled': newPrefs.quietHoursEnabled ? 1 : 0,
        'quiet_from': newPrefs.quietFrom,
        'quiet_to': newPrefs.quietTo,
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    ref.invalidateSelf();

    // Re-derive the inbox and re-register the OS alarms straight away, so a
    // toggle takes effect now rather than on the next app launch.
    ref.invalidate(notificationInboxProvider);
  }
}
