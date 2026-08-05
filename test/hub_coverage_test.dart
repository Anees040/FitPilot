import 'package:flutter_test/flutter_test.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/local/seed_importer.dart';
import 'package:fitpilot/data/repositories/exercise_repository.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fitpilot/application/providers/exercise_provider.dart';
import 'package:fitpilot/application/providers/database_providers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  test('Every visible tile on the hub must return > 0 exercises', () async {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
    final db = await AppDatabase.inMemory();
    
    // Seed the database
    await SeedImporter(db).importAll();
    
    final container = ProviderContainer(
      overrides: [
        exerciseRepositoryProvider.overrideWith((ref) => ExerciseRepository(db)),
      ],
    );
    
    // Test muscle tiles
    final muscles = ['chest', 'back', 'shoulders', 'arms', 'core', 'legs'];
    for (final m in muscles) {
      final exercises = await container.read(hubMuscleExercisesProvider(m).future);
      expect(exercises, isNotEmpty, reason: 'Muscle tile "$m" should return > 0 exercises');
    }
    
    // Test category tiles visible on the hub or all_categories_screen
    // The prompt says: chest, back, shoulders, arms, core, legs, upper_body, lower_body, plus any other ids the hub renders
    // We will test upper_body and lower_body
    final categories = ['upper_body', 'lower_body'];
    for (final c in categories) {
      final exercises = await container.read(hubCategoryExercisesProvider(c).future);
      expect(exercises, isNotEmpty, reason: 'Category tile "$c" should return > 0 exercises');
    }
  });
}
