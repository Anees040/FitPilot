import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:fitpilot/application/providers/burn_provider.dart';
import 'package:fitpilot/application/providers/capture_provider.dart';
import 'package:fitpilot/application/providers/exercise_provider.dart';
import 'package:fitpilot/application/providers/food_search_provider.dart';
import 'package:fitpilot/application/providers/notification_prefs_provider.dart';
import 'package:fitpilot/application/providers/profile_edit_provider.dart';
import 'package:fitpilot/application/providers/profile_provider.dart';
import 'package:fitpilot/application/providers/programs_provider.dart';
import 'package:fitpilot/application/providers/progress_provider.dart';
import 'package:fitpilot/application/providers/sync_provider.dart';
import 'package:fitpilot/application/providers/theme_provider.dart';
import 'package:fitpilot/application/providers/today_provider.dart';

/// Rebuilds every provider, repository cache, and in-memory state.
/// This guarantees no stale guest objects remain in memory after login,
/// and no stale authenticated objects remain after sign out.
void resetApplicationState(WidgetRef ref) {
  // Invalidate all providers (Riverpod will recreate them on next read)
  ref.invalidate(burnPlanProvider);
  ref.invalidate(captureProvider);
  ref.invalidate(exerciseListProvider);
  ref.invalidate(foodSearchProvider);
  ref.invalidate(notificationPrefsProvider);
  ref.invalidate(profileEditProvider);
  ref.invalidate(profileProvider);
  ref.invalidate(activeProgramProvider);
  ref.invalidate(progressProvider);
  ref.invalidate(syncStatusProvider);
  ref.invalidate(themeModeProvider);
  ref.invalidate(themeColorProvider);
  ref.invalidate(todayProvider);
  ref.invalidate(programsProvider);
}
