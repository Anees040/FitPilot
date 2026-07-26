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
      'gender': profile.gender,
      'goal': profile.goal.name,
      'allowance_kcal': profile.allowanceKcal,
      'equipment': json.encode(profile.equipment),
      'updated_at': profile.updatedAt.toIso8601String(),
    };

    await db.insert(
      'profile',
      data,
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
    await _enqueue('profile', '1', 'upsert');
  }

  Profile _rowToProfile(Map<String, dynamic> row) {
    final equipmentJson = row['equipment'] as String? ?? '[]';
    final equipment = (json.decode(equipmentJson) as List<dynamic>)
        .map((e) => e as String)
        .toList();

    return Profile(
      weightKg: (row['weight_kg'] as num).toDouble(),
      heightCm: (row['height_cm'] as num).toInt(),
      age: (row['age'] as num).toInt(),
      gender: row['gender'] as String?,
      goal: Goal.values.byName(row['goal'] as String? ?? 'maintain'),
      allowanceKcal: (row['allowance_kcal'] as num).toInt(),
      equipment: equipment,
      updatedAt: DateTime.parse(row['updated_at'] as String),
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
