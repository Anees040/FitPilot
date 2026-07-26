import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import '../../domain/entities/exercise.dart';

/// Repository for exercise catalog queries.
class ExerciseRepository {
  final Database db;

  const ExerciseRepository(this.db);

  /// Returns all exercises, optionally filtered by category.
  Future<List<Exercise>> all({ExerciseCategory? category}) async {
    final rows = category != null
        ? await db.query(
            'exercises',
            where: 'category = ?',
            whereArgs: [category.name],
            orderBy: 'name',
          )
        : await db.query('exercises', orderBy: 'name');
    return rows.map(_rowToExercise).toList();
  }

  /// Find an exercise by its id.
  Future<Exercise?> byId(String id) async {
    final rows = await db.query(
      'exercises',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _rowToExercise(rows.first);
  }

  Exercise _rowToExercise(Map<String, dynamic> row) {
    return Exercise(
      id: row['id'] as String,
      name: row['name'] as String,
      category:
          ExerciseCategory.values.byName(row['category'] as String),
      equipment: _decodeStringList(row['equipment'] as String),
      difficulty: row['difficulty'] as int,
      muscles: _decodeStringList(row['muscles'] as String),
      steps: _decodeStringList(row['steps'] as String),
      mistakes: _decodeStringList(row['mistakes'] as String),
      met: (row['met'] as num).toDouble(),
    );
  }

  List<String> _decodeStringList(String jsonStr) {
    return (json.decode(jsonStr) as List<dynamic>)
        .map((e) => e as String)
        .toList();
  }
}
