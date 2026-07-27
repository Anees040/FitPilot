import 'package:equatable/equatable.dart';

class NotificationPreferences extends Equatable {
  final bool mealRemindersEnabled;
  final List<String> mealTimes; // e.g. ["08:00", "13:00", "19:00"]
  final bool streakRiskEnabled;
  final bool milestonesEnabled;
  final bool globalMute;

  const NotificationPreferences({
    this.mealRemindersEnabled = false,
    this.mealTimes = const ["08:00", "13:00", "19:00"],
    this.streakRiskEnabled = false,
    this.milestonesEnabled = false,
    this.globalMute = false,
  });

  @override
  List<Object?> get props => [
        mealRemindersEnabled,
        mealTimes,
        streakRiskEnabled,
        milestonesEnabled,
        globalMute,
      ];

  NotificationPreferences copyWith({
    bool? mealRemindersEnabled,
    List<String>? mealTimes,
    bool? streakRiskEnabled,
    bool? milestonesEnabled,
    bool? globalMute,
  }) {
    return NotificationPreferences(
      mealRemindersEnabled: mealRemindersEnabled ?? this.mealRemindersEnabled,
      mealTimes: mealTimes ?? this.mealTimes,
      streakRiskEnabled: streakRiskEnabled ?? this.streakRiskEnabled,
      milestonesEnabled: milestonesEnabled ?? this.milestonesEnabled,
      globalMute: globalMute ?? this.globalMute,
    );
  }
}
