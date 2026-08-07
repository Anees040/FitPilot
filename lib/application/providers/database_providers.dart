import 'package:fitpilot/application/bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/repositories/burn_repository.dart';
import 'package:fitpilot/data/repositories/exercise_repository.dart';
import 'package:fitpilot/data/repositories/food_repository.dart';
import 'package:fitpilot/data/repositories/log_repository.dart';
import 'package:fitpilot/data/repositories/profile_repository.dart';
import 'package:fitpilot/data/repositories/program_repository.dart';

import 'package:fitpilot/application/providers/auth_provider.dart';

/// Provides the initialized Database instance.
/// It is safe to use `AppDatabase.instance()` asynchronously since it's a singleton,
/// but providing it via a FutureProvider makes it easy for other providers to await it.
final databaseProvider = FutureProvider<Database>((ref) async {
  final db = await AppDatabase.instance();
  // Ensure seed data is always loaded if missing (e.g. after migration)
  try {
    await FitPilotBootstrap.importSeedData();
  } catch (e) {
    ref.read(seedStatusProvider.notifier).state = e.toString();
  }
  return db;
});

/// Exposes any error message that occurred during the last seed import.
final seedStatusProvider = StateProvider<String?>((ref) => null);

/// Exposes the FoodRepository.
final foodRepositoryProvider = FutureProvider<FoodRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  bool isGuest() => ref.read(currentUserProvider) == null;
  return FoodRepository(db, isGuest: isGuest);
});

/// Exposes the LogRepository.
final logRepositoryProvider = FutureProvider<LogRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  bool isGuest() => ref.read(currentUserProvider) == null;
  return LogRepository(db, isGuest: isGuest);
});

/// Exposes the BurnRepository.
final burnRepositoryProvider = FutureProvider<BurnRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  bool isGuest() => ref.read(currentUserProvider) == null;
  return BurnRepository(db, isGuest: isGuest);
});

/// Exposes the ProfileRepository.
final profileRepositoryProvider = FutureProvider<ProfileRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  final user = ref.watch(currentUserProvider);
  bool isGuest() => user == null;
  return ProfileRepository(db, isGuest: isGuest);
});

/// Exposes the ExerciseRepository.
final exerciseRepositoryProvider = FutureProvider<ExerciseRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  return ExerciseRepository(db);
});

/// Exposes the ProgramRepository. Takes no guest guard: every table it touches
/// is local-only, so nothing it writes is ever queued for sync.
final programRepositoryProvider = FutureProvider<ProgramRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return ProgramRepository(db);
});
