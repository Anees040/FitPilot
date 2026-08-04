import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:fitpilot/core/utils/type_readers.dart';

import '../../domain/entities/profile.dart';

/// Repository for the single-row user profile.
class ProfileRepository {
  final Database db;
  final bool Function() isGuest;

  const ProfileRepository(this.db, {required this.isGuest});

  /// Loads the single profile row, or creates a default one if empty.
  Future<Profile?> get() async {
    final rows = await db.query('profile', where: 'id = 1');
    if (rows.isEmpty) return null;
    return _rowToProfile(rows.first);
  }

  /// Save (upsert) the profile into the single row.
  Future<void> save(Profile profile) async {
    final data = {
      'id': 1,
      'name': profile.name,
      'weight_kg': profile.weightKg,
      'goal_weight_kg': profile.goalWeightKg,
      'height_cm': profile.heightCm,
      'age': profile.age,
      'gender': profile.gender.name,
      'goal': profile.goal.name,
      'activity_level': profile.activityLevel.name,
      'allowance_kcal': profile.allowanceKcal,
      'target_override': profile.targetOverride,
      'equipment': jsonEncode(profile.equipment),
      'theme_mode': profile.themeMode.name,
      'theme_color': profile.themeColor,
      'plan_category_pref': profile.planCategoryPref,
      'plan_pace_pref': profile.planPacePref,
      'unit_kg_lb': profile.unitKgLb,
      'week_starts_mon': profile.weekStartsMon ? 1 : 0,
      'haptics_on': profile.hapticsOn ? 1 : 0,
      'active_program_id': profile.activeProgramId,
      'active_program_week': profile.activeProgramWeek,
      'active_program_day': profile.activeProgramDay,
      'updated_at': DateTime.now().toUtc().toIso8601String(),
    };

    await db.insert(
      'profile',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _enqueue('profile', '1', 'upsert');
  }

  Profile _rowToProfile(Map<String, dynamic> map) {
    final equipmentStr = map['equipment'] as String? ?? '[]';
    final List<dynamic> equipmentList = jsonDecode(equipmentStr) as List<dynamic>;
    
    final themeStr = map['theme_mode'] as String? ?? 'system';
    final themeMode = ThemeModePref.values.firstWhere(
      (e) => e.name == themeStr,
      orElse: () => ThemeModePref.system,
    );

    return Profile(
      name: map['name'] as String?,
      weightKg: TolerantReader.readDouble(map['weight_kg']) ?? 70.0,
      goalWeightKg: TolerantReader.readDouble(map['goal_weight_kg']),
      heightCm: TolerantReader.readInt(map['height_cm']) ?? 170,
      age: TolerantReader.readInt(map['age']) ?? 30,
      gender: Gender.values.byName(map['gender'] as String? ?? 'unspecified'),
      goal: Goal.values.byName(map['goal'] as String? ?? 'maintain'),
      activityLevel: ActivityLevel.values.byName(
        map['activity_level'] as String? ?? 'light',
      ),
      allowanceKcal: TolerantReader.readInt(map['allowance_kcal']) ?? 300,
      targetOverride: TolerantReader.readInt(map['target_override']),
      equipment: equipmentList.map((e) => e.toString()).toList(),
      themeMode: themeMode,
      themeColor: map['theme_color'] as String? ?? 'orange',
      planCategoryPref: map['plan_category_pref'] as String? ?? 'recommended',
      planPacePref: map['plan_pace_pref'] as String? ?? 'any',
      unitKgLb: map['unit_kg_lb'] as String? ?? 'kg',
      weekStartsMon: TolerantReader.readBool(map['week_starts_mon']) ?? true,
      hapticsOn: TolerantReader.readBool(map['haptics_on']) ?? true,
      activeProgramId: map['active_program_id'] as String?,
      activeProgramWeek: TolerantReader.readInt(map['active_program_week']),
      activeProgramDay: TolerantReader.readInt(map['active_program_day']),
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Future<void> _enqueue(String table, String rowId, String op) async {
    if (isGuest()) return; // Guest Mode Shield
    await db.insert('sync_queue', {
      'table_name': table,
      'row_id': rowId,
      'op': op,
      'payload': null,
      'queued_at': DateTime.now().toIso8601String(),
    });
  }
}
