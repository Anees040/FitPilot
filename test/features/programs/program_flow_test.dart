import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import 'package:fitpilot/application/providers/auth_provider.dart';
import 'package:fitpilot/application/providers/database_providers.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/programs_provider.dart';
import 'package:fitpilot/data/local/app_database.dart';
import 'package:fitpilot/data/local/seed_importer.dart';
import 'package:fitpilot/data/repositories/profile_repository.dart';
import 'package:fitpilot/data/repositories/program_repository.dart';
import 'package:fitpilot/domain/entities/profile.dart';
import 'package:fitpilot/domain/entities/program.dart';

/// Drives the enrol → complete → advance → finish loop against a real database.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Database db;
  late ProviderContainer container;
  late ProgramRepository programRepo;
  late ProfileRepository profileRepo;

  setUpAll(() {
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  });

  setUp(() async {
    db = await AppDatabase.inMemory();
    await SeedImporter(db).importAll();

    programRepo = ProgramRepository(db, isGuest: () => false);
    profileRepo = ProfileRepository(db, isGuest: () => true);
    await profileRepo.save(
      Profile(
        weightKg: 70,
        heightCm: 175,
        age: 25,
        updatedAt: DateTime(2026, 8, 7),
      ),
    );

    container = ProviderContainer(
      overrides: [
        databaseProvider.overrideWith((ref) => db),
        currentUserProvider.overrideWith((ref) => null),
      ],
    );
    // Prime the async providers the controller reads synchronously.
    await container.read(programsProvider.future);
    await container.read(profileProvider.future);
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  Future<ResolvedSession> resolve(ProgramSession session) =>
      container.read(resolvedSessionProvider(session).future);

  Future<Profile> currentProfile() async {
    container.invalidate(profileProvider);
    return container.read(profileProvider.future);
  }

  Future<ProgramWithSessions> program(String id) async {
    final all = await container.read(programsProvider.future);
    return all.firstWhere((p) => p.program.id == id);
  }

  test('enrolling sets the profile pointer to week 1 day 1', () async {
    await container.read(programsControllerProvider).enroll('six-pack-30');

    final profile = await currentProfile();
    expect(profile.activeProgramId, 'six-pack-30');
    expect(profile.activeProgramWeek, 1);
    expect(profile.activeProgramDay, 1);
  });

  test('abandoning clears the pointer and the completions', () async {
    final controller = container.read(programsControllerProvider);
    await controller.enroll('six-pack-30');

    final p = await program('six-pack-30');
    await container.read(programsControllerProvider).completeSession(
          await resolve(p.sessionForDay(1)!),
        );
    expect((await programRepo.progressFor('six-pack-30')).completedCount, 1);

    await container.read(programsControllerProvider).abandon();

    final profile = await currentProfile();
    expect(profile.activeProgramId, isNull);
    expect(profile.activeProgramWeek, isNull);
    expect(profile.activeProgramDay, isNull);
    expect((await programRepo.progressFor('six-pack-30')).completedCount, 0);
  });

  test('re-enrolling wipes the previous run so ticks do not carry over', () async {
    final controller = container.read(programsControllerProvider);
    await controller.enroll('six-pack-30');

    final p = await program('six-pack-30');
    await container.read(programsControllerProvider).completeSession(
          await resolve(p.sessionForDay(1)!),
        );
    expect((await programRepo.progressFor('six-pack-30')).completedCount, 1);

    await container.read(programsControllerProvider).enroll('six-pack-30');

    expect((await programRepo.progressFor('six-pack-30')).completedCount, 0);
    final profile = await currentProfile();
    expect(profile.activeProgramDay, 1);
  });

  test('switching programs clears both sides', () async {
    final controller = container.read(programsControllerProvider);
    await controller.enroll('six-pack-30');
    final six = await program('six-pack-30');
    await container.read(programsControllerProvider).completeSession(
          await resolve(six.sessionForDay(1)!),
        );

    await container.read(programsControllerProvider).switchTo('full-body-30');

    expect((await programRepo.progressFor('six-pack-30')).completedCount, 0);
    expect((await programRepo.progressFor('full-body-30')).completedCount, 0);
    final profile = await currentProfile();
    expect(profile.activeProgramId, 'full-body-30');
    expect(profile.activeProgramDay, 1);
  });

  test('completing a workout advances the day and logs one burn', () async {
    await container.read(programsControllerProvider).enroll('six-pack-30');
    final p = await program('six-pack-30');
    final session = p.sessionForDay(1)!;
    final resolved = await resolve(session);

    final result = await container
        .read(programsControllerProvider)
        .completeSession(resolved);

    expect(result.recorded, isTrue);
    expect(result.programFinished, isFalse);
    expect(result.kcal, greaterThan(0));

    final profile = await currentProfile();
    expect(profile.activeProgramDay, 2);

    final burns = await db.query('burn_completions');
    expect(burns.length, 1, reason: 'exactly one burn entry per workout day');
    expect(burns.single['kcal'], result.kcal);
    expect(
      burns.single['activity'],
      contains('Six-Pack in 30 Days'),
      reason: 'Progress should name the program',
    );
  });

  test('a rest day advances without logging a burn', () async {
    await container.read(programsControllerProvider).enroll('six-pack-30');
    final p = await program('six-pack-30');

    // Day 3 of the six-pack plan is the first scheduled rest day.
    final restDay = p.sessions.firstWhere((s) => s.isRest);
    final result = await container
        .read(programsControllerProvider)
        .completeSession(await resolve(restDay));

    expect(result.recorded, isTrue);
    expect(result.kcal, 0);
    expect(await db.query('burn_completions'), isEmpty);

    final profile = await currentProfile();
    expect(profile.activeProgramDay, restDay.dayNumber + 1);
  });

  test('completing the same session twice is a no-op', () async {
    await container.read(programsControllerProvider).enroll('six-pack-30');
    final p = await program('six-pack-30');
    final resolved = await resolve(p.sessionForDay(1)!);

    await container.read(programsControllerProvider).completeSession(resolved);
    final dayAfterFirst = (await currentProfile()).activeProgramDay;

    final second = await container
        .read(programsControllerProvider)
        .completeSession(resolved);

    expect(second.recorded, isFalse);
    expect((await currentProfile()).activeProgramDay, dayAfterFirst);
    expect(await db.query('burn_completions'), hasLength(1));
  });

  test('the day pointer rolls into the next week', () async {
    await container.read(programsControllerProvider).enroll('six-pack-30');
    final p = await program('six-pack-30');

    // Walk to the end of week 1 (7 plan days).
    for (var day = 1; day <= 7; day++) {
      await container
          .read(programsControllerProvider)
          .completeSession(await resolve(p.sessionForDay(day)!));
    }

    final profile = await currentProfile();
    expect(profile.activeProgramDay, 8);
    expect(profile.activeProgramWeek, 2, reason: 'day 8 belongs to week 2');
  });

  test('finishing the last day reports completion and clears the pointer', () async {
    await container.read(programsControllerProvider).enroll('six-pack-30');
    final p = await program('six-pack-30');

    SessionCompletionResult? last;
    for (var day = 1; day <= p.totalDays; day++) {
      last = await container
          .read(programsControllerProvider)
          .completeSession(await resolve(p.sessionForDay(day)!));
    }

    expect(last!.programFinished, isTrue);
    expect(last.completedSessions, 30);
    expect(last.totalKcal, greaterThan(0));

    final profile = await currentProfile();
    expect(profile.activeProgramId, isNull);

    // Progress survives until the congratulations screen has read the totals.
    expect((await programRepo.progressFor('six-pack-30')).completedCount, 30);
  });

  test('todaySessionProvider tracks the pointer', () async {
    await container.read(programsControllerProvider).enroll('six-pack-30');

    final first = await container.read(todaySessionProvider.future);
    expect(first, isNotNull);
    expect(first!.session.dayNumber, 1);

    await container.read(programsControllerProvider).completeSession(first);
    container.invalidate(todaySessionProvider);

    final next = await container.read(todaySessionProvider.future);
    expect(next, isNotNull);
    expect(next!.session.dayNumber, 2);
  });
}
