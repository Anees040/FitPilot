import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/domain/engines/reminder_scheduler.dart';
import 'package:fitpilot/domain/entities/notification_preferences.dart';
import 'package:fitpilot/domain/entities/day_status.dart';
import 'package:fitpilot/domain/entities/streak_state.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:fitpilot/domain/entities/kcal_range.dart';

void main() {
  final profile = Profile(weightKg: 70, heightCm: 175, age: 30, updatedAt: DateTime.now());
  final defaultPrefs = NotificationPreferences(
    mealRemindersEnabled: true,
    mealTimes: ['08:00', '13:00', '19:00'],
    streakRiskEnabled: true,
    milestonesEnabled: true,
    globalMute: false,
  );
  
  final dayStatus = DayStatus(
    total: KcalRange(0, 0),
    burnedKcal: 0,
    net: KcalRange(0, 0),
    remainingKcal: 2000,
    state: DayState.under,
    allowanceKcal: 2000,
  );

  test('Scheduler returns empty if globally muted', () {
    final scheduler = ReminderScheduler();
    final prefs = defaultPrefs.copyWith(globalMute: true);
    
    final schedules = scheduler.generate(
      now: DateTime(2026, 7, 27, 7, 0),
      prefs: prefs,
      todayStatus: dayStatus,
      streakState: StreakState(phase: StreakPhase.safe, currentStreak: 5),
      profile: profile,
    );
    
    expect(schedules, isEmpty);
  });

  test('Meal reminders are scheduled for today if time is in future', () {
    final scheduler = ReminderScheduler();
    
    final schedules = scheduler.generate(
      now: DateTime(2026, 7, 27, 7, 0), // 7 AM
      prefs: defaultPrefs,
      todayStatus: dayStatus,
      streakState: StreakState(phase: StreakPhase.safe, currentStreak: 5),
      profile: profile,
    );
    
    // We expect 3 meal reminders, all today.
    final mealReminders = schedules.where((s) => s.id >= 100 && s.id < 200).toList();
    expect(mealReminders.length, 3);
    expect(mealReminders[0].scheduledTime.hour, 8);
    expect(mealReminders[1].scheduledTime.hour, 13);
    expect(mealReminders[2].scheduledTime.hour, 19);
  });

  test('Streak risk alert is scheduled 8 hours before grace deadline', () {
    final scheduler = ReminderScheduler();
    final deadline = DateTime(2026, 7, 28, 0, 0); // Midnight
    
    final schedules = scheduler.generate(
      now: DateTime(2026, 7, 27, 12, 0), // Noon
      prefs: defaultPrefs,
      todayStatus: dayStatus,
      streakState: StreakState(
        phase: StreakPhase.overPending,
        currentStreak: 5,
        graceDeadline: deadline,
        kcalStillToBurn: 150,
      ),
      profile: profile,
    );
    
    final riskAlerts = schedules.where((s) => s.id == 200).toList();
    expect(riskAlerts.length, 1);
    expect(riskAlerts.first.scheduledTime, DateTime(2026, 7, 27, 16, 0)); // 4 PM (8 hours before midnight)
    expect(riskAlerts.first.body, contains('will save your streak!'));
  });
}
