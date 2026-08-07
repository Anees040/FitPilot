import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/data/repositories/machine_scan_repository.dart';
import 'package:fitpilot/domain/engines/machine_exercise_matcher.dart';
import 'package:fitpilot/domain/entities/exercise.dart';
import 'package:fitpilot/domain/entities/machine_analysis.dart';
import 'package:fitpilot/domain/entities/machine_scan.dart';

/// Exposes the MachineScanRepository. Takes no guest guard: `machine_scans` is
/// local-only, so nothing it writes is ever queued for sync.
final machineScanRepositoryProvider = FutureProvider<MachineScanRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return MachineScanRepository(db);
});

/// Saved scans, newest first. Readable with no network.
final recentMachineScansProvider = FutureProvider<List<MachineScan>>((ref) async {
  final repo = await ref.watch(machineScanRepositoryProvider.future);
  return repo.recent();
});

/// Catalog exercises related to a scanned machine, capped at five rows.
final relatedExercisesProvider = FutureProvider.autoDispose
    .family<List<Exercise>, MachineAnalysis>((ref, analysis) async {
      final repo = await ref.watch(exerciseRepositoryProvider.future);
      final catalog = await repo.all();
      return MachineExerciseMatcher.match(analysis, catalog);
    });
