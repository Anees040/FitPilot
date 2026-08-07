/// Central mapping between the muscle vocabulary the UI speaks (hub tile ids,
/// AI-returned muscle names) and the muscle names actually stored on seeded
/// exercises.
///
/// This map used to be copy-pasted inside `exercise_provider.dart` — once for
/// the muscle tiles and again for the category tiles — so a fix to one copy
/// silently missed the other. Every caller now resolves through here.
///
/// The seed's `primary_muscles` vocabulary is exactly:
/// Back, Balance, Biceps, Chest, Core, Full body, Glutes, Grip, Hams,
/// Hip flexors, Legs, Lower back, Quads, Shoulders, Traps, Triceps.
library;

class MuscleSynonyms {
  const MuscleSynonyms._();

  /// Hub tile id -> the seed muscle names that tile should collect.
  static const Map<String, Set<String>> _groups = {
    'chest': {'chest'},
    'back': {'back', 'lower back', 'traps'},
    'shoulders': {'shoulders'},
    'arms': {'biceps', 'triceps', 'grip'},
    'core': {'core'},
    'legs': {'legs', 'quads', 'hams', 'glutes', 'hip flexors'},
  };

  /// Everyday / anatomical words -> the hub group they belong to.
  ///
  /// The AI names muscles the way a coach would ("lats", "pecs", "quadriceps"),
  /// which is not the seed's vocabulary. Anything unrecognised falls through
  /// unchanged so an unknown muscle can still match a seed name directly.
  static const Map<String, String> _aliases = {
    // Chest
    'chest': 'chest',
    'pecs': 'chest',
    'pectorals': 'chest',
    'pectoral': 'chest',
    'pectoralis major': 'chest',
    'pectoralis': 'chest',
    // Back
    'back': 'back',
    'lats': 'back',
    'latissimus dorsi': 'back',
    'latissimus': 'back',
    'upper back': 'back',
    'lower back': 'back',
    'mid back': 'back',
    'middle back': 'back',
    'traps': 'back',
    'trapezius': 'back',
    'rhomboids': 'back',
    'erector spinae': 'back',
    'spinal erectors': 'back',
    // Shoulders
    'shoulders': 'shoulders',
    'shoulder': 'shoulders',
    'delts': 'shoulders',
    'deltoids': 'shoulders',
    'deltoid': 'shoulders',
    'rear delts': 'shoulders',
    'front delts': 'shoulders',
    'side delts': 'shoulders',
    'rotator cuff': 'shoulders',
    // Arms
    'arms': 'arms',
    'biceps': 'arms',
    'bicep': 'arms',
    'biceps brachii': 'arms',
    'triceps': 'arms',
    'tricep': 'arms',
    'triceps brachii': 'arms',
    'forearms': 'arms',
    'forearm': 'arms',
    'grip': 'arms',
    'brachialis': 'arms',
    // Core
    'core': 'core',
    'abs': 'core',
    'abdominals': 'core',
    'abdominal': 'core',
    'abdominals and core': 'core',
    'rectus abdominis': 'core',
    'obliques': 'core',
    'transverse abdominis': 'core',
    // Legs
    'legs': 'legs',
    'leg': 'legs',
    'quads': 'legs',
    'quadriceps': 'legs',
    'quadricep': 'legs',
    'hams': 'legs',
    'hamstrings': 'legs',
    'hamstring': 'legs',
    'glutes': 'legs',
    'glute': 'legs',
    'gluteus maximus': 'legs',
    'gluteus': 'legs',
    'calves': 'legs',
    'calf': 'legs',
    'gastrocnemius': 'legs',
    'soleus': 'legs',
    'hip flexors': 'legs',
    'hip flexor': 'legs',
    'adductors': 'legs',
    'abductors': 'legs',
    // Whole body
    'full body': 'full body',
    'total body': 'full body',
    'cardio': 'full body',
    'cardiovascular': 'full body',
  };

  /// Hub groups that a "Full body" exercise legitimately belongs to.
  static const Set<String> fullBodyGroups = {
    'chest',
    'back',
    'shoulders',
    'core',
    'legs',
  };

  /// Seed muscle names for the muscle group [id] (e.g. `arms` -> biceps,
  /// triceps, grip). Unknown ids resolve to themselves so a direct seed-name
  /// lookup still works.
  static Set<String> expand(String id) {
    final key = id.trim().toLowerCase();
    return _groups[key] ?? {key};
  }

  /// Normalises a free-form muscle name to a hub group id.
  ///
  /// `"Lats"` -> `back`, `"Quadriceps"` -> `legs`. Unrecognised names are
  /// returned lowercased and trimmed rather than dropped.
  static String normalize(String muscle) {
    final key = muscle.trim().toLowerCase();
    return _aliases[key] ?? key;
  }

  /// Every seed muscle name implied by a free-form muscle name.
  ///
  /// `"Lats"` -> {back, lower back, traps}, so an AI answer matches seeded
  /// exercises even though the seed never uses the word "lats".
  static Set<String> seedNamesFor(String muscle) => expand(normalize(muscle));

  /// True when an exercise's muscle list covers the muscle group [id].
  ///
  /// [includeFullBody] mirrors the long-standing hub rule: a "Full body"
  /// exercise counts for the major groups, so compound work still shows under
  /// Chest, Back and Legs and no tile is ever empty. The machine scanner passes
  /// false — next to a scanned lat pulldown it has only five slots, and a
  /// generic full-body entry there is noise rather than a related exercise.
  static bool matches(
    Iterable<String> exerciseMuscles,
    String id, {
    bool includeFullBody = true,
  }) {
    final target = id.trim().toLowerCase();
    final wanted = expand(target);
    var isFullBody = false;
    for (final muscle in exerciseMuscles) {
      final name = muscle.trim().toLowerCase();
      if (wanted.contains(name)) return true;
      if (name == 'full body') isFullBody = true;
    }
    if (!includeFullBody) return false;
    return isFullBody && fullBodyGroups.contains(target);
  }
}
