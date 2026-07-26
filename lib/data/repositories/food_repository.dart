import 'dart:convert';

import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

import '../../domain/entities/food_item.dart';
import '../../domain/entities/kcal_range.dart';

/// Repository for food catalog CRUD and search.
class FoodRepository {
  final Database db;
  static const _uuid = Uuid();

  const FoodRepository(this.db);

  /// Case-insensitive search on name or name_ur, ordered by best match.
  Future<List<FoodItem>> search(String query, {int limit = 30}) async {
    final q = '%${query.toLowerCase()}%';
    final rows = await db.rawQuery(
      '''
      SELECT * FROM food_catalog
      WHERE LOWER(name) LIKE ? OR LOWER(COALESCE(name_ur, '')) LIKE ?
      ORDER BY
        CASE WHEN LOWER(name) = ? THEN 0
             WHEN LOWER(name) LIKE ? THEN 1
             ELSE 2
        END,
        name
      LIMIT ?
      ''',
      [q, q, query.toLowerCase(), '${query.toLowerCase()}%', limit],
    );
    return rows.map(_rowToFoodItem).toList();
  }

  /// Find a food by its id.
  Future<FoodItem?> byId(String id) async {
    final rows = await db.query(
      'food_catalog',
      where: 'id = ?',
      whereArgs: [id],
    );
    if (rows.isEmpty) return null;
    return _rowToFoodItem(rows.first);
  }

  /// Add a custom food to the catalog. Returns the generated id.
  Future<String> addCustomFood(FoodItem item) async {
    final id = item.id.isEmpty ? _uuid.v4() : item.id;
    await db.insert('food_catalog', {
      'id': id,
      'name': item.name,
      'name_ur': item.nameUr,
      'portion_label': item.portionLabel,
      'grams': item.grams,
      'kcal_min': item.kcalPerPortion.min,
      'kcal_max': item.kcalPerPortion.max,
      'is_verified': item.isVerified ? 1 : 0,
    });
    await _enqueue('food_catalog', id, 'insert', {
      'id': id,
      'name': item.name,
      'name_ur': item.nameUr,
      'portion_label': item.portionLabel,
      'grams': item.grams,
      'kcal_min': item.kcalPerPortion.min,
      'kcal_max': item.kcalPerPortion.max,
      'is_verified': item.isVerified ? 1 : 0,
    });
    return id;
  }

  FoodItem _rowToFoodItem(Map<String, dynamic> row) {
    return FoodItem(
      id: row['id'] as String,
      name: row['name'] as String,
      nameUr: row['name_ur'] as String?,
      portionLabel: row['portion_label'] as String,
      grams: row['grams'] as int?,
      kcalPerPortion: KcalRange(
        row['kcal_min'] as int,
        row['kcal_max'] as int,
      ),
      isVerified: (row['is_verified'] as int) == 1,
    );
  }

  Future<void> _enqueue(
      String table, String rowId, String op, Map<String, dynamic> payload) async {
    await db.insert('sync_queue', {
      'table_name': table,
      'row_id': rowId,
      'op': op,
      'payload': json.encode(payload),
      'queued_at': DateTime.now().toIso8601String(),
    });
  }
}
