import 'package:fitpilot/application/bootstrap.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:sqflite/sqflite.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/repositories/burn_repository.dart';
import 'package:fitpilot/data/repositories/exercise_repository.dart';
import 'package:fitpilot/data/repositories/food_repository.dart';
import 'package:fitpilot/data/repositories/log_repository.dart';
import 'package:fitpilot/data/repositories/profile_repository.dart';

/// Provides the initialized Database instance.
/// It is safe to use `AppDatabase.instance()` asynchronously since it's a singleton,
/// but providing it via a FutureProvider makes it easy for other providers to await it.
final databaseProvider = FutureProvider<Database>((ref) async {
  final db = await AppDatabase.instance();
  // Ensure seed data is always loaded if missing (e.g. after migration)
  await FitPilotBootstrap.importSeedData();
  return db;
});

/// Exposes the FoodRepository.
final foodRepositoryProvider = FutureProvider<FoodRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return FoodRepository(db);
});

/// Exposes the LogRepository.
final logRepositoryProvider = FutureProvider<LogRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return LogRepository(db);
});

/// Exposes the BurnRepository.
final burnRepositoryProvider = FutureProvider<BurnRepository>((ref) async {
  final db = await ref.watch(databaseProvider.future);
  return BurnRepository(db);
});

/// Exposes the ProfileRepository.
final profileRepositoryProvider = FutureProvider<ProfileRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  return ProfileRepository(db);
});

/// Exposes the ExerciseRepository.
final exerciseRepositoryProvider = FutureProvider<ExerciseRepository>((
  ref,
) async {
  final db = await ref.watch(databaseProvider.future);
  return ExerciseRepository(db);
});
