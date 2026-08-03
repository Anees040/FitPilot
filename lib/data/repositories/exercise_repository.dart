import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:fitpilot/core/utils/type_readers.dart';

import '../../domain/entities/exercise.dart';

/// Repository for exercise catalog queries.
class ExerciseRepository {
  final Database db;

  const ExerciseRepository(this.db);

  /// Search exercises by name (case-insensitive substring match).
  Future<List<Exercise>> searchByName(String query) async {
    if (query.trim().isEmpty) return all();
    final rows = await db.query(
      'exercises',
      where: 'name LIKE ?',
      whereArgs: ['%${query.trim()}%'],
      orderBy: 'name',
    );
    return rows.map(_rowToExercise).toList();
  }

  /// Returns all exercises filtered by category.
  Future<List<Exercise>> byCategory(String category) async {
    final rows = await db.query(
      'exercises',
      where: 'category = ?',
      whereArgs: [category],
      orderBy: 'name',
    );
    return rows.map(_rowToExercise).toList();
  }

  /// Find an exercise by its id.
  Future<Exercise?> byId(String id) async {
    final rows = await db.query('exercises', where: 'id = ?', whereArgs: [id]);
    if (rows.isEmpty) return null;
    return _rowToExercise(rows.first);
  }

  /// Returns all exercises, optionally filtered.
  Future<List<Exercise>> all() async {
    final rows = await db.query('exercises', orderBy: 'name');
    return rows.map(_rowToExercise).toList();
  }

  /// Returns exercises matching the given filter criteria.
  /// All parameters are optional; omitted params mean "no filter".
  Future<List<Exercise>> filtered({
    String? category,
    String? paceTier,
    int? maxDifficulty,
    String? equipment,
  }) async {
    final conditions = <String>[];
    final args = <dynamic>[];

    if (category != null) {
      conditions.add('category = ?');
      args.add(category);
    }
    if (paceTier != null) {
      conditions.add('pace_tier = ?');
      args.add(paceTier);
    }
    if (maxDifficulty != null) {
      conditions.add('difficulty <= ?');
      args.add(maxDifficulty);
    }
    if (equipment != null) {
      conditions.add('equipment = ?');
      args.add(equipment);
    }

    final rows = await db.query(
      'exercises',
      where: conditions.isEmpty ? null : conditions.join(' AND '),
      whereArgs: args.isEmpty ? null : args,
      orderBy: 'name',
    );
    return rows.map(_rowToExercise).toList();
  }

  Exercise _rowToExercise(Map<String, dynamic> row) {
    return Exercise(
      id: row['id'] as String,
      name: row['name'] as String,
      category: _parseCategory(row['category'] as String?),
      subcategory: row['subcategory'] as String?,
      met: TolerantReader.readDouble(row['met']) ?? 5.0,
      equipment: row['equipment'] as String?,
      primaryMuscles: _safeDecodeStringList(row['primary_muscles']),
      secondaryMuscles: _safeDecodeStringList(row['secondary_muscles']),
      difficulty: TolerantReader.readInt(row['difficulty']) ?? 1,
      paceTier: (row['pace_tier'] as String?) ?? 'moderate',
      steps: _safeDecodeStringList(row['steps']),
      mistakes: _safeDecodeStringList(row['mistakes']),
      mediaAsset: row['media_asset'] as String?,
      videoUrl: row['video_url'] as String?,
    );
  }

  ExerciseCategory _parseCategory(String? value) {
    if (value == null) return ExerciseCategory.indoor;
    for (final cat in ExerciseCategory.values) {
      if (cat.name == value) return cat;
    }
    return ExerciseCategory.indoor;
  }

  /// Safely decodes a JSON string list, returning [] on any error.
  List<String> _safeDecodeStringList(dynamic value) {
    if (value == null) return [];
    if (value is! String) return [];
    if (value.isEmpty || value == '[]') return [];
    try {
      final decoded = json.decode(value);
      if (decoded is List) {
        return decoded.map((e) => e.toString()).toList();
      }
      return [];
    } catch (_) {
      return [];
    }
  }
}
