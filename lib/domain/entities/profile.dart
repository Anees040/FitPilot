import 'package:equatable/equatable.dart';
import '../engines/target_calculator.dart';

/// User's fitness goal.
enum Goal { lose, maintain, build }

/// User's gender for BMR calculation.
enum Gender { male, female, unspecified }

/// User's activity level for TDEE calculation.
enum ActivityLevel { sedentary, light, moderate, active }

/// User's theme preference.
enum ThemeModePref { system, light, dark }

/// User profile — single-row entity.
class Profile extends Equatable {
  final String? name;
  final String? avatarUrl;
  final double weightKg;
  final double? goalWeightKg;
  final int heightCm;
  final int age;
  final Gender gender;
  final Goal goal;
  final ActivityLevel activityLevel;
  final int allowanceKcal;
  final int? targetOverride;
  final List<String> equipment;
  final ThemeModePref themeMode;
  final String themeColor;
  final String planCategoryPref;
  final String planPacePref;
  final String unitKgLb;
  final bool weekStartsMon;
  final bool hapticsOn;
  final bool onboardingComplete;
  final String? activeProgramId;
  final int? activeProgramWeek;
  final int? activeProgramDay;
  /// The user's own daily protein goal in grams, overriding the weight-based
  /// recommendation. Null means "use the recommendation".
  ///
  /// LOCAL-ONLY: absent from the Supabase schema, never pushed or pulled.
  final double? proteinGoalG;

  final DateTime updatedAt;

  static const int defaultAllowanceKcal = 300;

  Profile({
    this.name,
    this.avatarUrl,
    required this.weightKg,
    this.goalWeightKg,
    required this.heightCm,
    required this.age,
    this.gender = Gender.unspecified,
    this.goal = Goal.maintain,
    this.activityLevel = ActivityLevel.light,
    this.allowanceKcal = defaultAllowanceKcal,
    this.targetOverride,
    this.equipment = const [],
    this.themeMode = ThemeModePref.system,
    this.themeColor = 'orange',
    this.planCategoryPref = 'recommended',
    this.planPacePref = 'any',
    this.unitKgLb = 'kg',
    this.weekStartsMon = true,
    this.hapticsOn = true,
    this.onboardingComplete = false,
    this.activeProgramId,
    this.activeProgramWeek,
    this.activeProgramDay,
    this.proteinGoalG,
    required this.updatedAt,
  }) {
    if (weightKg < 25 || weightKg > 300) {
      throw ArgumentError('weightKg must be 25–300, got $weightKg');
    }
    if (goalWeightKg != null && (goalWeightKg! < 25 || goalWeightKg! > 300)) {
      throw ArgumentError('goalWeightKg must be 25–300, got $goalWeightKg');
    }
    if (heightCm < 100 || heightCm > 250) {
      throw ArgumentError('heightCm must be 100–250, got $heightCm');
    }
    if (age < 13 || age > 100) {
      throw ArgumentError('age must be 13–100, got $age');
    }
    if (allowanceKcal < 0 || allowanceKcal > 2000) {
      throw ArgumentError('allowanceKcal must be 0–2000, got $allowanceKcal');
    }
    if (targetOverride != null &&
        (targetOverride! < 1000 || targetOverride! > 5000)) {
      throw ArgumentError(
        'targetOverride must be 1000–5000, got $targetOverride',
      );
    }
  }

  int get effectiveDailyTarget {
    if (targetOverride != null) return targetOverride!;
    const calc = TargetCalculator();
    final bmr = calc.bmr(
      weightKg: weightKg,
      heightCm: heightCm.toDouble(),
      age: age,
      gender: gender,
    );
    final tdee = calc.tdee(bmr, activityLevel);
    return calc.dailyTarget(tdeeValue: tdee, goal: goal, gender: gender);
  }

  int get tdee {
    const calc = TargetCalculator();
    final bmr = calc.bmr(
      weightKg: weightKg,
      heightCm: heightCm.toDouble(),
      age: age,
      gender: gender,
    );
    return calc.tdee(bmr, activityLevel).toInt();
  }

  int get effectiveDailyLimit => effectiveDailyTarget + allowanceKcal;

  Profile copyWith({
    String? name,
    String? avatarUrl,
    double? weightKg,
    double? goalWeightKg,
    int? heightCm,
    int? age,
    Gender? gender,
    Goal? goal,
    ActivityLevel? activityLevel,
    int? allowanceKcal,
    int? targetOverride,
    List<String>? equipment,
    ThemeModePref? themeMode,
    String? themeColor,
    String? planCategoryPref,
    String? planPacePref,
    String? unitKgLb,
    bool? weekStartsMon,
    bool? hapticsOn,
    bool? onboardingComplete,
    String? activeProgramId,
    int? activeProgramWeek,
    int? activeProgramDay,
    double? proteinGoalG,
    bool clearProgram = false,
    /// copyWith cannot pass null to mean "unset", so clearing the protein goal
    /// (back to the weight-based recommendation) needs its own flag.
    bool clearProteinGoal = false,
    DateTime? updatedAt,
    bool clearOverride = false,
  }) {
    return Profile(
      name: name ?? this.name,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      weightKg: weightKg ?? this.weightKg,
      goalWeightKg: goalWeightKg ?? this.goalWeightKg,
      heightCm: heightCm ?? this.heightCm,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      goal: goal ?? this.goal,
      activityLevel: activityLevel ?? this.activityLevel,
      allowanceKcal: allowanceKcal ?? this.allowanceKcal,
      targetOverride: clearOverride ? null : (targetOverride ?? this.targetOverride),
      equipment: equipment ?? this.equipment,
      themeMode: themeMode ?? this.themeMode,
      themeColor: themeColor ?? this.themeColor,
      planCategoryPref: planCategoryPref ?? this.planCategoryPref,
      planPacePref: planPacePref ?? this.planPacePref,
      proteinGoalG: clearProteinGoal ? null : (proteinGoalG ?? this.proteinGoalG),
      unitKgLb: unitKgLb ?? this.unitKgLb,
      weekStartsMon: weekStartsMon ?? this.weekStartsMon,
      hapticsOn: hapticsOn ?? this.hapticsOn,
      onboardingComplete: onboardingComplete ?? this.onboardingComplete,
      activeProgramId: clearProgram ? null : (activeProgramId ?? this.activeProgramId),
      activeProgramWeek: clearProgram ? null : (activeProgramWeek ?? this.activeProgramWeek),
      activeProgramDay: clearProgram ? null : (activeProgramDay ?? this.activeProgramDay),
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => [
        name,
        avatarUrl,
        weightKg,
        goalWeightKg,
        heightCm,
        age,
        gender,
        goal,
        activityLevel,
        allowanceKcal,
    targetOverride,
    equipment,
    themeMode,
    themeColor,
    planCategoryPref,
    planPacePref,
    unitKgLb,
    weekStartsMon,
    hapticsOn,
    onboardingComplete,
    activeProgramId,
    activeProgramWeek,
    activeProgramDay,
    proteinGoalG,
    updatedAt,
  ];

  @override
  String toString() =>
      'Profile(${weightKg}kg, ${heightCm}cm, age=$age, limit=$effectiveDailyLimit)';
}
