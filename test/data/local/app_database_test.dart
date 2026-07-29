import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:fitpilot/data/local/app_database.dart';

void main() {
  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  test('AppDatabase.inMemory() executes _repairLogs without SQL syntax errors', () async {
    // Calling AppDatabase.inMemory() triggers _onCreate and _repairLogs.
    // If _repairLogs contains invalid SQL (like double quotes for strings),
    // this will throw a DatabaseException.
    final db = await AppDatabase.inMemory();
    
    // Verify the DB is open and accessible.
    final result = await db.rawQuery('SELECT 1');
    expect(result, isNotEmpty);
    
    await db.close();
  });
}
