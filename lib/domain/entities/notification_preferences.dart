import 'package:equatable/equatable.dart';

import 'package:fitpilot/domain/entities/app_notification.dart';

class NotificationPreferences extends Equatable {
  final bool mealRemindersEnabled;
  final List<String> mealTimes; // e.g. ["08:00", "13:00", "19:00"]
  final bool streakRiskEnabled;
  final bool milestonesEnabled;
  final bool globalMute;

  /// Nudge to work off the day's surplus, sent in the early evening.
  final bool burnRemindersEnabled;

  /// Reminder that today's training-programme session is waiting.
  final bool programRemindersEnabled;

  final bool weighInEnabled;

  /// 1 = Monday … 7 = Sunday, matching DateTime.weekday.
  final int weighInDay;
  final String weighInTime;

  final bool waterRemindersEnabled;

  /// Suppresses everything between [quietFrom] and [quietTo].
  final bool quietHoursEnabled;
  final String quietFrom;
  final String quietTo;

  const NotificationPreferences({
    this.mealRemindersEnabled = false,
    this.mealTimes = const ["08:00", "13:00", "19:00"],
    this.streakRiskEnabled = false,
    this.milestonesEnabled = false,
    this.globalMute = false,
    this.burnRemindersEnabled = false,
    this.programRemindersEnabled = false,
    this.weighInEnabled = false,
    this.weighInDay = 1,
    this.weighInTime = '08:00',
    this.waterRemindersEnabled = false,
    this.quietHoursEnabled = false,
    this.quietFrom = '22:00',
    this.quietTo = '07:00',
  });

  /// Whether [category] may be delivered at all.
  ///
  /// One place decides this, so the inbox, the scheduler and the settings
  /// screen can never disagree about whether something is muted.
  bool allows(NotificationCategory category) {
    if (globalMute) return false;
    return switch (category) {
      NotificationCategory.mealReminder => mealRemindersEnabled,
      NotificationCategory.burnReminder => burnRemindersEnabled,
      NotificationCategory.streakRisk => streakRiskEnabled,
      NotificationCategory.milestone => milestonesEnabled,
      NotificationCategory.programDay => programRemindersEnabled,
      NotificationCategory.weighIn => weighInEnabled,
      NotificationCategory.water => waterRemindersEnabled,
      // App-level messages are not individually silenceable, only globally muted.
      NotificationCategory.system => true,
    };
  }

  /// True when [time] falls inside quiet hours.
  ///
  /// Handles the overnight case (22:00 → 07:00) by treating the window as
  /// wrapping past midnight rather than as an empty range.
  bool isQuiet(DateTime time) {
    if (!quietHoursEnabled) return false;

    final from = _minutes(quietFrom);
    final to = _minutes(quietTo);
    if (from == null || to == null || from == to) return false;

    final now = time.hour * 60 + time.minute;
    if (from < to) return now >= from && now < to;
    return now >= from || now < to;
  }

  static int? _minutes(String hhmm) {
    final parts = hhmm.split(':');
    if (parts.length != 2) return null;
    final h = int.tryParse(parts[0]);
    final m = int.tryParse(parts[1]);
    if (h == null || m == null) return null;
    if (h < 0 || h > 23 || m < 0 || m > 59) return null;
    return h * 60 + m;
  }

  /// How many silenceable categories the user currently has switched on.
  int get enabledCount => NotificationCategory.values
      .where((c) => c != NotificationCategory.system)
      .where(allows)
      .length;

  @override
  List<Object?> get props => [
    mealRemindersEnabled,
    mealTimes,
    streakRiskEnabled,
    milestonesEnabled,
    globalMute,
    burnRemindersEnabled,
    programRemindersEnabled,
    weighInEnabled,
    weighInDay,
    weighInTime,
    waterRemindersEnabled,
    quietHoursEnabled,
    quietFrom,
    quietTo,
  ];

  NotificationPreferences copyWith({
    bool? mealRemindersEnabled,
    List<String>? mealTimes,
    bool? streakRiskEnabled,
    bool? milestonesEnabled,
    bool? globalMute,
    bool? burnRemindersEnabled,
    bool? programRemindersEnabled,
    bool? weighInEnabled,
    int? weighInDay,
    String? weighInTime,
    bool? waterRemindersEnabled,
    bool? quietHoursEnabled,
    String? quietFrom,
    String? quietTo,
  }) {
    return NotificationPreferences(
      mealRemindersEnabled: mealRemindersEnabled ?? this.mealRemindersEnabled,
      mealTimes: mealTimes ?? this.mealTimes,
      streakRiskEnabled: streakRiskEnabled ?? this.streakRiskEnabled,
      milestonesEnabled: milestonesEnabled ?? this.milestonesEnabled,
      globalMute: globalMute ?? this.globalMute,
      burnRemindersEnabled: burnRemindersEnabled ?? this.burnRemindersEnabled,
      programRemindersEnabled:
          programRemindersEnabled ?? this.programRemindersEnabled,
      weighInEnabled: weighInEnabled ?? this.weighInEnabled,
      weighInDay: weighInDay ?? this.weighInDay,
      weighInTime: weighInTime ?? this.weighInTime,
      waterRemindersEnabled:
          waterRemindersEnabled ?? this.waterRemindersEnabled,
      quietHoursEnabled: quietHoursEnabled ?? this.quietHoursEnabled,
      quietFrom: quietFrom ?? this.quietFrom,
      quietTo: quietTo ?? this.quietTo,
    );
  }
}
