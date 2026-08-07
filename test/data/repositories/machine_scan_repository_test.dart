import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/repositories/machine_scan_repository.dart';
import 'package:fitpilot/domain/entities/machine_analysis.dart';

MachineAnalysis _analysis(String name) => MachineAnalysis(
  isGymMachine: true,
  machineName: name,
  confidence: 0.9,
  primaryMuscles: const ['Back'],
  howToUse: const ['Sit down', 'Pull the bar'],
  suggestedExerciseKeywords: const ['lat pulldown'],
);

void main() {
  late Database db;
  late MachineScanRepository repo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await AppDatabase.inMemory();
    repo = MachineScanRepository(db);
    await repo.clear();
  });

  tearDown(() async {
    await db.close();
  });

  test('machine_scans table exists at the current schema version', () async {
    final tables = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type='table' AND name='machine_scans'",
    );
    expect(tables, hasLength(1));
  });

  test('a saved scan round-trips with its analysis intact', () async {
    await repo.save('scan-1', _analysis('Lat Pulldown Machine'));

    final scans = await repo.recent();
    expect(scans, hasLength(1));
    expect(scans.first.id, 'scan-1');
    expect(scans.first.machineName, 'Lat Pulldown Machine');
    expect(scans.first.analysis.primaryMuscles, ['Back']);
    expect(scans.first.analysis.howToUse, hasLength(2));
  });

  test('scans come back newest first', () async {
    final base = DateTime.utc(2026, 1, 1, 12);
    await repo.save('old', _analysis('Leg Press'), createdAt: base);
    await repo.save('middle', _analysis('Chest Press'),
        createdAt: base.add(const Duration(hours: 1)));
    await repo.save('newest', _analysis('Lat Pulldown'),
        createdAt: base.add(const Duration(hours: 2)));

    final scans = await repo.recent();
    expect(scans.map((s) => s.id).toList(), ['newest', 'middle', 'old']);
  });

  test('history is capped at 20 rows, dropping the oldest', () async {
    final base = DateTime.utc(2026, 1, 1);
    for (var i = 0; i < 25; i++) {
      await repo.save(
        'scan-$i',
        _analysis('Machine $i'),
        createdAt: base.add(Duration(minutes: i)),
      );
    }

    expect(await repo.count(), MachineScanRepository.maxRows);

    final scans = await repo.recent();
    expect(scans, hasLength(20));
    // The five oldest were pruned; the newest survives.
    expect(scans.first.id, 'scan-24');
    expect(scans.map((s) => s.id), isNot(contains('scan-0')));
    expect(scans.map((s) => s.id), isNot(contains('scan-4')));
    expect(scans.map((s) => s.id), contains('scan-5'));
  });

  test('re-saving the same id replaces rather than duplicates', () async {
    await repo.save('scan-1', _analysis('Wrong Name'));
    await repo.save('scan-1', _analysis('Correct Name'));

    final scans = await repo.recent();
    expect(scans, hasLength(1));
    expect(scans.first.machineName, 'Correct Name');
  });

  test('a corrupt row is skipped instead of breaking the list', () async {
    await repo.save('good', _analysis('Leg Press'));
    await db.insert('machine_scans', {
      'id': 'corrupt',
      'machine_name': 'Broken',
      'response_json': 'this is not json',
      'created_at': DateTime.now().toUtc().toIso8601String(),
    });

    final scans = await repo.recent();
    expect(scans, hasLength(1));
    expect(scans.first.id, 'good');
  });

  test('deleteById removes a single scan', () async {
    await repo.save('a', _analysis('A'));
    await repo.save('b', _analysis('B'));

    await repo.deleteById('a');

    final scans = await repo.recent();
    expect(scans.map((s) => s.id), ['b']);
  });

  test('saving never enqueues a sync row — the table is local-only', () async {
    await repo.save('scan-1', _analysis('Lat Pulldown Machine'));

    final queued = await db.query('sync_queue');
    expect(queued, isEmpty);
  });
}
