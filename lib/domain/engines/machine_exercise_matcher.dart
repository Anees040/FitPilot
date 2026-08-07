import 'package:fitpilot/domain/engines/muscle_synonyms.dart';
import 'package:fitpilot/domain/entities/exercise.dart';
import 'package:fitpilot/domain/entities/machine_analysis.dart';

/// Picks catalog exercises that relate to a scanned gym machine.
///
/// Two passes, strongest signal first:
///  1. Name match against `suggestedExerciseKeywords` and the machine name —
///     "lat pulldown" finds the seeded *Lat pulldown* exactly.
///  2. Muscle match through [MuscleSynonyms] — a machine the catalog doesn't
///     carry (pec deck, leg extension) still surfaces useful chest or leg work.
///
/// Pass 1 results always rank above pass 2, and results are de-duplicated by
/// exercise id so a keyword and a muscle hit can't list the same row twice.
class MachineExerciseMatcher {
  const MachineExerciseMatcher._();

  /// Words too generic to identify an exercise on their own. Without this,
  /// "machine" or "press" would match almost the entire catalog.
  static const Set<String> _stopWords = {
    'machine',
    'gym',
    'exercise',
    'equipment',
    'trainer',
    'weight',
    'weights',
    'bar',
    'cable',
    'seated',
    'standing',
    'the',
    'a',
    'an',
    'and',
    'or',
    'with',
    'for',
    'of',
    'on',
    'in',
  };

  /// Up to [limit] exercises related to [analysis], best match first.
  static List<Exercise> match(
    MachineAnalysis analysis,
    List<Exercise> catalog, {
    int limit = 5,
  }) {
    if (!analysis.isGymMachine || catalog.isEmpty || limit <= 0) return const [];

    final seen = <String>{};
    final results = <Exercise>[];

    void add(Exercise exercise) {
      if (results.length >= limit) return;
      if (seen.add(exercise.id)) results.add(exercise);
    }

    // Pass 1 — name matches, keywords before the machine name itself.
    final phrases = <String>[
      ...analysis.suggestedExerciseKeywords,
      analysis.machineName,
    ];
    for (final phrase in phrases) {
      if (results.length >= limit) break;
      for (final exercise in _byName(phrase, catalog)) {
        add(exercise);
      }
    }

    // Pass 2 — muscle matches, primary muscles before secondary.
    for (final muscle in [...analysis.primaryMuscles, ...analysis.secondaryMuscles]) {
      if (results.length >= limit) break;
      for (final exercise in _byMuscle(muscle, catalog)) {
        add(exercise);
      }
    }

    return results;
  }

  /// Exercises whose name relates to [phrase].
  ///
  /// Scored so a tighter match wins: full phrase containment beats sharing
  /// individual significant words.
  static List<Exercise> _byName(String phrase, List<Exercise> catalog) {
    final needle = _normalize(phrase);
    if (needle.isEmpty) return const [];

    final needleWords = _significantWords(needle);
    final scored = <_Scored>[];

    for (final exercise in catalog) {
      final haystack = _normalize(exercise.name);
      if (haystack.isEmpty) continue;

      var score = 0;
      if (haystack == needle) {
        score = 100;
      } else if (haystack.contains(needle) || needle.contains(haystack)) {
        score = 60;
      } else if (needleWords.isNotEmpty) {
        final haystackWords = _significantWords(haystack);
        final shared = needleWords.intersection(haystackWords);
        // Two shared significant words ("lat", "pulldown") is a real match;
        // one on its own is too loose to trust.
        if (shared.length >= 2) score = 30 + shared.length;
      }

      if (score > 0) scored.add(_Scored(exercise, score));
    }

    scored.sort((a, b) => b.score.compareTo(a.score));
    return scored.map((s) => s.exercise).toList();
  }

  /// Exercises training [muscle], resolved through the central synonym map so
  /// an AI answer of "Lats" matches the seed's "Back".
  static List<Exercise> _byMuscle(String muscle, List<Exercise> catalog) {
    final group = MuscleSynonyms.normalize(muscle);
    if (group.isEmpty || group == 'full body') return const [];

    final primary = <Exercise>[];
    final secondary = <Exercise>[];

    for (final exercise in catalog) {
      // includeFullBody: false — a generic full-body entry is not a useful
      // "related exercise" for one specific machine.
      if (MuscleSynonyms.matches(exercise.primaryMuscles, group, includeFullBody: false)) {
        primary.add(exercise);
      } else if (MuscleSynonyms.matches(
        exercise.secondaryMuscles,
        group,
        includeFullBody: false,
      )) {
        secondary.add(exercise);
      }
    }

    // Gym-category exercises first: someone standing at a machine wants gym
    // work suggested before a bodyweight alternative.
    int gymFirst(Exercise a, Exercise b) {
      final aGym = a.category == ExerciseCategory.gym ? 0 : 1;
      final bGym = b.category == ExerciseCategory.gym ? 0 : 1;
      if (aGym != bGym) return aGym.compareTo(bGym);
      return a.name.compareTo(b.name);
    }

    primary.sort(gymFirst);
    secondary.sort(gymFirst);
    return [...primary, ...secondary];
  }

  static String _normalize(String value) {
    return value
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  static Set<String> _significantWords(String normalized) {
    return normalized
        .split(' ')
        .where((w) => w.length > 2 && !_stopWords.contains(w))
        .toSet();
  }
}

class _Scored {
  final Exercise exercise;
  final int score;

  const _Scored(this.exercise, this.score);
}
