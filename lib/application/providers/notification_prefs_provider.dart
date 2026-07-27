import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/domain/entities/notification_preferences.dart';
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
      mealRemindersEnabled: (r['meal_reminders_enabled'] as int) == 1,
      mealTimes: List<String>.from(jsonDecode(r['meal_times'] as String)),
      streakRiskEnabled: (r['streak_risk_enabled'] as int) == 1,
      milestonesEnabled: (r['milestones_enabled'] as int) == 1,
      globalMute: (r['global_mute'] as int) == 1,
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
