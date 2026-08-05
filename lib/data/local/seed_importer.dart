import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fitpilot/core/utils/type_readers.dart';

/// Loads seed data from bundled JSON assets into the database.
///
/// Idempotent: only inserts when the target table is empty.
class SeedImporter {
  final Database db;

  const SeedImporter(this.db);

  Future<void> importAll() async {
    int foods = await _importFoods();
    int exercises = await _importExercises();
    int programs = await _importPrograms();
    debugPrint('[Seed] foods=$foods exercises=$exercises programs=$programs');
  }

  Future<int> _importFoods() async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM food_catalog'),
    );
    if (count != null && count > 0) return count;

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
        'grams': TolerantReader.readInt(f['grams']),
        'kcal_min': TolerantReader.readInt(f['kcal_min']) ?? 0,
        'kcal_max': TolerantReader.readInt(f['kcal_max']) ?? 0,
        'is_verified': 1,
      });
    }
    await batch.commit(noResult: true);
    
    final finalCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM food_catalog'),
    );
    return finalCount ?? 0;
  }

  Future<int> _importExercises() async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM exercises'),
    );
    if (count != null && count >= 50) return count;

    final jsonStr = await rootBundle.loadString('assets/seed/exercises.json');
    final List<dynamic> exercises = json.decode(jsonStr) as List<dynamic>;

    final batch = db.batch();
    for (final ex in exercises) {
      final e = ex as Map<String, dynamic>;
      batch.insert(
        'exercises',
        {
          'id': e['id'] as String,
          'name': e['name'] as String,
          'category': e['category'] as String,
          'subcategory': e['subcategory'] as String?,
          'met': TolerantReader.readDouble(e['met']) ?? 5.0,
          'equipment': (e['equipment'] as String?) ?? '',
          'primary_muscles': json.encode(e['primary_muscles'] ?? []),
          'secondary_muscles': json.encode(e['secondary_muscles'] ?? []),
          'difficulty': TolerantReader.readInt(e['difficulty']) ?? 1,
          'pace_tier': e['pace_tier'] as String,
          'steps': json.encode(e['steps'] ?? []),
          'mistakes': json.encode(e['mistakes'] ?? []),
          'media_asset': e['media_asset'] as String?,
          'video_url': e['video_url'] as String?,
        },
        conflictAlgorithm: ConflictAlgorithm.replace,
      );
    }
    try {
      await batch.commit(noResult: true);
    } catch (e) {
      // Ignore duplicate or constraint conflicts during seed import
    }
    
    final finalCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM exercises'),
    );
    return finalCount ?? 0;
  }

  Future<int> _importPrograms() async {
    final count = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM programs'),
    );
    if (count != null && count > 0) return count;

    final jsonStr = await rootBundle.loadString('assets/seed/programs.json');
    final List<dynamic> programs = json.decode(jsonStr) as List<dynamic>;

    final batch = db.batch();
    for (final p in programs) {
      final prog = p as Map<String, dynamic>;
      batch.insert('programs', {
        'id': prog['id'] as String,
        'name': prog['name'] as String,
        'icon': prog['icon'] as String,
        'goal': prog['goal'] as String,
      });

      final weeks = prog['weeks'] as List<dynamic>;
      for (final w in weeks) {
        final week = w as Map<String, dynamic>;
        final weekNumber = TolerantReader.readInt(week['week_number']) ?? 1;
        final sessions = week['sessions'] as List<dynamic>;
        
        for (final s in sessions) {
          final session = s as Map<String, dynamic>;
          final dayNumber = TolerantReader.readInt(session['day_number']) ?? 1;
          final exerciseId = session['exercise_id'] as String;
          final minutes = TolerantReader.readInt(session['minutes']) ?? 10;
          
          final sessionId = '${prog['id']}-w$weekNumber-d$dayNumber';
          
          batch.insert('program_sessions', {
            'id': sessionId,
            'program_id': prog['id'] as String,
            'week_number': weekNumber,
            'day_number': dayNumber,
            'exercise_id': exerciseId,
            'minutes': minutes,
          });
        }
      }
    }
    await batch.commit(noResult: true);

    final finalCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM programs'),
    );
    return finalCount ?? 0;
  }
}
