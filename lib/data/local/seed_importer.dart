import 'dart:convert';
import 'package:flutter/foundation.dart';

import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fitpilot/core/utils/food_image_resolver.dart';
import 'package:fitpilot/core/utils/type_readers.dart';

/// Loads seed data from bundled JSON assets into the database.
///
/// Idempotent: only inserts when the target table is empty.
class SeedImporter {
  final Database db;

  /// Every id in `foods_cheat.json` carries this prefix, so the importer can
  /// tell how many of that file's rows are already present without needing a
  /// version table.
  static const _cheatIdPrefix = 'cheat-';

  const SeedImporter(this.db);

  Future<void> importAll() async {
    int foods = await _importFoods();
    int cheats = await _importCheatFoods();
    int exercises = await _importExercises();
    int programs = await _importPrograms();
    debugPrint(
      '[Seed] foods=$foods (cheat=$cheats) '
      'exercises=$exercises programs=$programs',
    );
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
      final name = f['name'] as String;
      batch.insert('food_catalog', {
        'id': f['id'] as String,
        'name': name,
        'name_ur': f['name_ur'] as String?,
        'portion_label': f['portion_label'] as String,
        'grams': TolerantReader.readInt(f['grams']),
        'kcal_min': TolerantReader.readInt(f['kcal_min']) ?? 0,
        'kcal_max': TolerantReader.readInt(f['kcal_max']) ?? 0,
        'image_key': resolveImageKey(name),
        'is_verified': 1,
      });
    }
    await batch.commit(noResult: true);

    final finalCount = Sqflite.firstIntValue(
      await db.rawQuery('SELECT COUNT(*) FROM food_catalog'),
    );
    return finalCount ?? 0;
  }

  /// Imports the high-regret catalog — packaged snacks, cold drinks, fast food
  /// and desi cheat meals — the foods a gym-goer actually wants a burn plan for.
  ///
  /// Runs on existing installs too, unlike [_importFoods], which stops as soon
  /// as the catalog is non-empty. The guard compares how many `cheat-` rows are
  /// present against the asset, so adding items to the file later ships them to
  /// users who already have the earlier ones. Inserts use `ignore` and stable
  /// ids, so a re-run never duplicates and never overwrites a user's edits.
  ///
  /// Writes through a raw batch, which deliberately bypasses `sync_queue`:
  /// seed rows are bundled with the app and must not be pushed to Supabase.
  Future<int> _importCheatFoods() async {
    final jsonStr = await rootBundle.loadString('assets/seed/foods_cheat.json');
    final List<dynamic> foods = json.decode(jsonStr) as List<dynamic>;

    final present =
        Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM food_catalog WHERE id LIKE ?',
            ['$_cheatIdPrefix%'],
          ),
        ) ??
        0;
    if (present >= foods.length) return present;

    final batch = db.batch();
    for (final food in foods) {
      final f = food as Map<String, dynamic>;
      final name = f['name'] as String;
      batch.insert(
        'food_catalog',
        {
          'id': f['id'] as String,
          'name': name,
          'name_ur': f['name_ur'] as String?,
          'portion_label': f['portion_label'] as String,
          'grams': TolerantReader.readInt(f['grams']),
          'kcal_min': TolerantReader.readInt(f['kcal_min']) ?? 0,
          'kcal_max': TolerantReader.readInt(f['kcal_max']) ?? 0,
          'image_key': resolveImageKey(name),
          'is_verified': 1,
        },
        conflictAlgorithm: ConflictAlgorithm.ignore,
      );
    }
    await batch.commit(noResult: true);

    return Sqflite.firstIntValue(
          await db.rawQuery(
            'SELECT COUNT(*) FROM food_catalog WHERE id LIKE ?',
            ['$_cheatIdPrefix%'],
          ),
        ) ??
        0;
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
