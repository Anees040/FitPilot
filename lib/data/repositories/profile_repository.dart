import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/profile.dart';

/// Repository for the single-row user profile.
class ProfileRepository {
  final Database db;

  const ProfileRepository(this.db);

  /// Get the current profile, or null if none exists.
  Future<Profile?> get() async {
    final rows = await db.query('profile', where: 'id = 1');
    if (rows.isEmpty) return null;
    return _rowToProfile(rows.first);
  }

  /// Save (upsert) the profile into the single row.
  Future<void> save(Profile profile) async {
    final data = {
      'id': 1,
      'weight_kg': profile.weightKg,
      'height_cm': profile.heightCm,
      'age': profile.age,
      'gender': profile.gender.name,
      'goal': profile.goal.name,
      'activity_level': profile.activityLevel.name,
      'allowance_kcal': profile.allowanceKcal,
      'target_override': profile.targetOverride,
      'equipment': jsonEncode(profile.equipment),
      'theme_mode': profile.themeMode.name,
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
    final List<dynamic> equipmentList = jsonDecode(equipmentStr);
    
    final themeStr = map['theme_mode'] as String? ?? 'system';
    final themeMode = ThemeModePref.values.firstWhere(
      (e) => e.name == themeStr,
      orElse: () => ThemeModePref.system,
    );

    return Profile(
      weightKg: (map['weight_kg'] as num).toDouble(),
      heightCm: (map['height_cm'] as num).toInt(),
      age: (map['age'] as num).toInt(),
      gender: Gender.values.byName(map['gender'] as String? ?? 'unspecified'),
      goal: Goal.values.byName(map['goal'] as String? ?? 'maintain'),
      activityLevel: ActivityLevel.values.byName(
        map['activity_level'] as String? ?? 'light',
      ),
      allowanceKcal: map['allowance_kcal'] as int? ?? 300,
      targetOverride: map['target_override'] as int?,
      equipment: equipmentList.map((e) => e.toString()).toList(),
      themeMode: themeMode,
      updatedAt: DateTime.parse(map['updated_at'] as String),
    );
  }

  Future<void> _enqueue(String table, String rowId, String op) async {
    await db.insert('sync_queue', {
      'table_name': table,
      'row_id': rowId,
      'op': op,
      'payload': null,
      'queued_at': DateTime.now().toIso8601String(),
    });
  }
}
