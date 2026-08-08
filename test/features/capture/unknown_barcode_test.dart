import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/data/local/app_database.dart';

/// Open Food Facts barely covers Pakistani and other local brands, so a
/// "not found" scan is the common case. These tests pin the durable fix: a
/// product the user teaches the app once is stored against its barcode and
/// resolves locally — and therefore offline — on every later scan.
void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  Future<Database> freshDb() => AppDatabase.inMemory();

  test('a user-taught product is retrievable by its barcode', () async {
    final db = await freshDb();
    const barcode = '8964000203040'; // Pakistani prefix (896)

    await db.insert('food_catalog', {
      'id': barcode,
      'name': 'Peek Freans Sooper',
      'portion_label': '100g',
      'grams': 45.0,
      'kcal_min': 480,
      'kcal_max': 480,
      'is_verified': 0,
    });

    final rows = await db.query('food_catalog', where: 'id = ?', whereArgs: [barcode]);

    expect(rows, hasLength(1));
    expect(rows.first['name'], 'Peek Freans Sooper');
    expect(rows.first['kcal_min'], 480);
    expect(rows.first['grams'], 45.0);
    // is_verified 0 keeps user-supplied rows distinguishable from seed data.
    expect(rows.first['is_verified'], 0);

    await db.close();
  });

  test('re-teaching the same barcode updates rather than duplicating', () async {
    final db = await freshDb();
    const barcode = '8964000203040';

    Map<String, Object?> row(String name, int kcal) => {
      'id': barcode,
      'name': name,
      'portion_label': '100g',
      'kcal_min': kcal,
      'kcal_max': kcal,
      'is_verified': 0,
    };

    await db.insert('food_catalog', row('Typo Name', 400));
    await db.insert(
      'food_catalog',
      row('Corrected Name', 480),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );

    final rows = await db.query('food_catalog', where: 'id = ?', whereArgs: [barcode]);

    expect(rows, hasLength(1), reason: 'barcode is the primary key');
    expect(rows.first['name'], 'Corrected Name');
    expect(rows.first['kcal_min'], 480);

    await db.close();
  });

  test('a taught product does not collide with seeded catalog foods', () async {
    final db = await freshDb();

    await db.insert('food_catalog', {
      'id': '8964000203040',
      'name': 'Local Brand Juice',
      'portion_label': '100g',
      'kcal_min': 54,
      'kcal_max': 54,
      'is_verified': 0,
    });

    final taught = await db.query('food_catalog', where: 'is_verified = 0');
    expect(taught, hasLength(1));

    // Seeded rows, if any, remain verified and untouched.
    final verified = await db.query('food_catalog', where: 'is_verified = 1');
    for (final row in verified) {
      expect(row['id'], isNot('8964000203040'));
    }

    await db.close();
  });
}
