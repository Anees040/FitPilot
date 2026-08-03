import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/domain/entities/notification_preferences.dart';
import 'package:fitpilot/core/utils/type_readers.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
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
      mealTimes: List<String>.from(jsonDecode(r['meal_times'] as String)),
      streakRiskEnabled: TolerantReader.readBool(r['streak_risk_enabled']) ?? false,
      milestonesEnabled: TolerantReader.readBool(r['milestones_enabled']) ?? false,
      globalMute: TolerantReader.readBool(r['global_mute']) ?? false,
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
      },
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    ref.invalidateSelf();
    
    // In Milestone B6, whenever prefs change, we should re-sync notifications.
    // We will do this somewhere else or directly here.
    // E.g. ref.read(notificationSyncProvider.notifier).sync();
  }
}
