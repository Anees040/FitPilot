import 'package:fitpilot/domain/entities/notification_preferences.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/streak_state.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:fitpilot/domain/engines/burn_planner.dart';

class NotificationSchedule {
  final int id;
  final DateTime scheduledTime;
  final String title;
  final String body;
  final String? payload;

  const NotificationSchedule({
    required this.id,
    required this.scheduledTime,
    required this.title,
    required this.body,
    this.payload,
  });
}

class ReminderScheduler {
  final BurnPlanner _burnPlanner = const BurnPlanner();

  List<NotificationSchedule> generate({
    required DateTime now,
    required NotificationPreferences prefs,
    required DayStatus todayStatus,
    required StreakState streakState,
    required Profile profile,
    DateTime? lastLogTime,
  }) {
    if (prefs.globalMute) return [];

    final schedules = <NotificationSchedule>[];

    // 1. Meal Reminders
    if (prefs.mealRemindersEnabled) {
      for (int i = 0; i < prefs.mealTimes.length; i++) {
        final timeStr = prefs.mealTimes[i];
        final parts = timeStr.split(':');
        if (parts.length != 2) continue;
        final hour = int.tryParse(parts[0]) ?? 0;
        final minute = int.tryParse(parts[1]) ?? 0;
        
        var scheduledFor = DateTime(now.year, now.month, now.day, hour, minute);
        
        if (scheduledFor.isBefore(now)) {
           scheduledFor = scheduledFor.add(const Duration(days: 1));
        }

        bool suppress = false;
        if (lastLogTime != null && lastLogTime.isAfter(now.subtract(const Duration(hours: 1)))) {
           if (scheduledFor.difference(now).inHours < 1 && scheduledFor.day == now.day) {
             suppress = true;
           }
        }
        
        if (!suppress) {
          schedules.add(NotificationSchedule(
            id: 100 + i,
            scheduledTime: scheduledFor,
            title: 'Time to log?',
            body: 'Keep your calories tracked to reach your goal.',
          ));
        }
      }
    }

    // 2. Streak Risk Alert
    if (prefs.streakRiskEnabled && streakState.phase == StreakPhase.overPending && streakState.graceDeadline != null) {
      final alertTime = streakState.graceDeadline!.subtract(const Duration(hours: 8));
      
      if (alertTime.isAfter(now)) {
        // Need to find smallest burn option
        final options = _burnPlanner.planFor(
          kcalOver: streakState.kcalStillToBurn,
          weightKg: profile.weightKg,
          equipment: [], 
        );

        if (options.isNotEmpty) {
          final smallest = options.first; // sorted by minutes ascending
          schedules.add(NotificationSchedule(
            id: 200,
            scheduledTime: alertTime,
            title: 'Streak at risk!',
            body: 'A ${smallest.minutes}-minute ${smallest.activity.toLowerCase()} will save your streak!',
          ));
        }
      }
    }

    // 3. Milestone Celebrations
    // Simplification for stateless engine: if the user hits a multiple of 7 streak, schedule a celebration for tomorrow morning.
    if (prefs.milestonesEnabled && streakState.currentStreak > 0 && streakState.currentStreak % 7 == 0) {
        final tomorrow = DateTime(now.year, now.month, now.day + 1, 9, 0); // 9 AM tomorrow
        if (tomorrow.isAfter(now)) {
          schedules.add(NotificationSchedule(
            id: 300,
            scheduledTime: tomorrow,
            title: 'Milestone reached!',
            body: 'Amazing job maintaining your ${streakState.currentStreak}-day streak!',
          ));
        }
    }

    return schedules;
  }
}
