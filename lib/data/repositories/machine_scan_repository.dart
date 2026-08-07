import 'dart:convert';

import 'package:sqflite/sqflite.dart';

import 'package:fitpilot/domain/entities/machine_analysis.dart';
import 'package:fitpilot/domain/entities/machine_scan.dart';

/// Reads and writes the gym machine scanner history.
///
/// The table is LOCAL-ONLY — it caches AI answers so a scan stays readable with
/// no network — so this repository never enqueues anything to `sync_queue`.
/// History is capped at [maxRows]; the oldest rows are deleted on insert.
class MachineScanRepository {
  final Database db;

  const MachineScanRepository(this.db);

  /// How many scans to keep. Older ones are pruned on each save.
  static const int maxRows = 20;

  /// Newest scans first. Rows whose JSON can no longer be decoded are skipped
  /// rather than throwing, so one bad row can't break the history list.
  Future<List<MachineScan>> recent({int limit = maxRows}) async {
    final rows = await db.query(
      'machine_scans',
      orderBy: 'created_at DESC',
      limit: limit,
    );

    final scans = <MachineScan>[];
    for (final row in rows) {
      final scan = _rowToScan(row);
      if (scan != null) scans.add(scan);
    }
    return scans;
  }

  /// Saves a successful scan, then prunes anything past [maxRows].
  Future<void> save(String id, MachineAnalysis analysis, {DateTime? createdAt}) async {
    final timestamp = (createdAt ?? DateTime.now()).toUtc().toIso8601String();

    await db.insert('machine_scans', {
      'id': id,
      'machine_name': analysis.machineName,
      'response_json': jsonEncode(analysis.toJson()),
      'created_at': timestamp,
    }, conflictAlgorithm: ConflictAlgorithm.replace);

    await _prune();
  }

  Future<void> deleteById(String id) async {
    await db.delete('machine_scans', where: 'id = ?', whereArgs: [id]);
  }

  Future<void> clear() async {
    await db.delete('machine_scans');
  }

  Future<int> count() async {
    final result = await db.rawQuery('SELECT COUNT(*) AS c FROM machine_scans');
    if (result.isEmpty) return 0;
    final value = result.first['c'];
    return value is int ? value : 0;
  }

  /// Keeps only the [maxRows] newest rows.
  Future<void> _prune() async {
    await db.rawDelete(
      '''
      DELETE FROM machine_scans
      WHERE id NOT IN (
        SELECT id FROM machine_scans ORDER BY created_at DESC LIMIT ?
      )
      ''',
      [maxRows],
    );
  }

  MachineScan? _rowToScan(Map<String, Object?> row) {
    final id = row['id'];
    final rawJson = row['response_json'];
    if (id is! String || rawJson is! String) return null;

    final analysis = MachineAnalysis.tryDecode(rawJson);
    if (analysis == null) return null;

    final createdAtRaw = row['created_at'];
    final createdAt = createdAtRaw is String
        ? DateTime.tryParse(createdAtRaw)?.toLocal()
        : null;

    return MachineScan(
      id: id,
      machineName: (row['machine_name'] as String?) ?? analysis.machineName,
      analysis: analysis,
      createdAt: createdAt ?? DateTime.now(),
    );
  }
}
