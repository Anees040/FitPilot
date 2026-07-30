import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';

/// Loads seed data from bundled JSON assets into the database.
///
/// Idempotent: only inserts when the target table is empty.
class SeedImporter {
  final Database db;

  const SeedImporter(this.db);

  /// Imports all seed data. Safe to call multiple times.
  Future<void> importAll() async {
    await _importFoods();
    await _importExercises();
  }

  Future<void> _importFoods() async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM food_catalog'),
    );
    if (count != null && count > 0) return;

    final jsonStr = await rootBundle.loadString('assets/seed/foods.json');
    final List<dynamic> foods = json.decode(jsonStr) as List<dynamic>;

    final batch = db.batch();
    for (final food in foods) {
      final f = food as Map<String, dynamic>;
      batch.insert('food_catalog', {
        'id': f['id'] as String,
        'name': f['name'] as String,
        'name_ur': f['name_ur'] as String?,
        'portion_label': f['portion_label'] as String,
        'grams': f['grams'] as int?,
        'kcal_min': f['kcal_min'] as int,
        'kcal_max': f['kcal_max'] as int,
        'is_verified': 1,
      });
    }
    await batch.commit(noResult: true);
  }

  Future<void> _importExercises() async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM exercises'),
    );
    if (count != null && count > 0) return;

    final jsonStr = await rootBundle.loadString('assets/seed/exercises.json');
    final List<dynamic> exercises = json.decode(jsonStr) as List<dynamic>;

    final batch = db.batch();
    for (final ex in exercises) {
      final e = ex as Map<String, dynamic>;
      batch.insert('exercises', {
        'id': e['id'] as String,
        'name': e['name'] as String,
        'category': e['category'] as String,
        'subcategory': e['subcategory'] as String?,
        'met': (e['met'] as num).toDouble(),
        'equipment': e['equipment'] as String?,
        'primary_muscles': json.encode(e['primary_muscles'] ?? []),
        'secondary_muscles': json.encode(e['secondary_muscles'] ?? []),
        'difficulty': (e['difficulty'] as num).toInt(),
        'pace_tier': e['pace_tier'] as String,
        'steps': json.encode(e['steps'] ?? []),
        'mistakes': json.encode(e['mistakes'] ?? []),
        'media_asset': e['media_asset'] as String?,
        'video_url': e['video_url'] as String?,
      });
    }
    await batch.commit(noResult: true);
  }
}
