# STATUS â€” single source of truth for project state

> Agent: update this file at the end of EVERY successful task.
> Human: glance here before every new prompt.

## Current milestone: A â€” offline core (30% demo)

## Task board

- [x] A1 â€” Theme + 5-tab navigation shell
- [x] A2 â€” Domain entities + KcalRange (unit tested)
- [x] A3 â€” Local SQLite DB + seed food catalog (50+ desi foods)
- [x] A4 â€” Food search + manual log flow (M5)
- [x] A5 â€” Today screen with live day range (M4)
- [x] A6 â€” BurnPlanner engine + Burn Plan screen (M8)
- [x] A7 â€” StreakEngine + Progress screen (M9)
- [x] A8 â€” Local profile + settings (M3, local only)
- [x] B1 â€” Supabase init + env secrets
- [x] B2 â€” Auth UI + Guest data merge
- [x] B3 â€” Background sync service
- [x] B0+B4 â€” Barcode, Open Food Facts, and label OCR
- [x] F1 â€” Correctness and dead features
- [x] F2 â€” Foundation: launch, type, dark theme, adaptivity
- [x] F3 â€” Final Screen Redesign & Interaction Prompt
- [x] F4 â€” First impression: onboarding, illustration, empty states
- [x] F5 â€” Correctness + UX drop
- [x] F7 â€” Chrome/web correctness fixes
- [x] C1 â€” Exercise library and Burn Plan v2
- [x] C3 â€” Library & Capture UX polish
- [x] G2 â€” Critical bug fixes (camera permission, barcode lag, overflow, chip scroll, plan nav, offline images)
- [x] G3 â€” Auth UX (inline validation, password live checklist, OTP behavior, error mapping)
- [x] G4 â€” Google Sign-in (Auth UI, Supabase integration, routing)
- [x] G5
- [x] G6 — Dark theme overhaul
- [x] G8 — Profile & Settings refactor
- [x] J1 — Meal-first logic pivot and Welcome Screen Polish
- [x] J2 — Profile, Auth, and Splash Screen Redesign
- [x] J3 — Splash & Welcome Screen Redesign (mockup-based)
- [x] J4 — Theming, Progress & Workout Hub UI Polish
- [x] J5 — Sign-out sequence, Password flow, and Workout Hub taxonomy fixes
- [x] J6 — Chrome Debug Run & UI Exception Fixes (hero overflow, dropdowns, keys, step 5 riverpod, progress slivers, auth guest loophole, food log detail sheet)
- [x] J7 — Release Crash Fixes, Password Flow Polish, Snackbar & UI Refactor
- [x] J8 — Burn Plan Empty Fix, UNDO Disposed Ref Fix, Offline Sign-Out & Auth Isolation
- [x] J9 — Real Scanner Operational Guarantee, Device Exercise Seed Repair & Guest Profile Sync
- [x] J10 — Web & Riverpod Runtime Stability (v16 DB migration, gemini-2.0-flash, Google auth metadata, Riverpod ref order, Web notification guard, SliverList layout, StatefulShellRoute keys)

## Last completed

- J10 — Web & Riverpod Runtime Stability
  - Fixed `v16` SQLite migration in `app_database.dart` (`if (oldVersion < 16)`) to drop non-null equipment constraints and seed all 60 exercises.
  - Updated Render proxy server (`server/index.js`) to use `gemini-2.0-flash` AI model to fix 404 API model deprecation.
  - Enforced Google Sign-In vs Sign-Up separation: first-time users clicking "Log In" via Google are prompted to use "Sign Up".
  - Extracted Google user metadata (`full_name`, `avatar_url`) into profile and updated `ProfileScreen` to display user's Google profile picture and name.
  - Fixed Riverpod `!_didChangeDependency` assertion in `profile_setup_screen.dart` and `progress_provider.dart` by hoisting database writes and `ref.read` calls before `ref.invalidate`.
  - Added `kIsWeb` guards to `NotificationService` (`init`, `showBurnReminder`, `scheduleBurnReminder`) to prevent Chrome `zonedSchedule()` crash.
  - Fixed `sliver_list.dart:315` assertion crash on Progress screen by replacing `ListView` with `SingleChildScrollView(child: Column(...))`.
  - Fixed `Duplicate GlobalKey` exception on shell navigation by converting `StatefulShellRoute` to `StatefulShellRoute.indexedStack` with explicit `navigatorKey`s (`shellNavigatorTodayKey`, `shellNavigatorLogKey`, etc.).
  - Replaced non-existent asset illustration paths with valid existing assets across `exercise_library_screen.dart`, `programs_screen.dart`, `update_password_screen.dart`, and `change_password_screen.dart`.
  - Removed all silent fallback mock data (`'Scanned Meal / Desi Portion (330 kcal)'`) from `capture_screen.dart`. Real Gemini AI results are displayed when valid, and explicit network/connection error notices appear if unreachable.
  - Added OCR validation in `_runOcrOnFile` requiring actual Nutrition Facts numbers (`kcal`, `servingSizeGrams`) to be recognized before presenting the review sheet.
  - Updated `SeedImporter._importExercises()` in `seed_importer.dart` to automatically populate the 60 exercise catalog if existing DB contains < 50 exercises, resolving empty Burn Plan cards on physical devices.
  - Fixed `_ProfileScreenState._initForm()` in `profile_screen.dart` to re-sync all form controllers and chips reactively when signing out to guest mode or logging into an account.
  - Fixed empty Burn Plan options list (Image 1) by repairing equipment JSON array parsing in `burn_provider.dart` and adding fallback candidate selection in `burn_planner.dart`.
  - Fixed UNDO meal deletion crash (`Cannot use "ref" after widget was disposed`) in `today_screen.dart` by capturing `todayProvider.notifier` prior to element unmounting.
  - Suppressed raw technical cancellation error (`GoogleSignInException.canceled`) in `auth_screen.dart` when users dismiss the Google account picker.
  - Made `profileProvider` and `profileRepositoryProvider` reactive to `currentUserProvider` so profile screen updates immediately upon login or sign-out without showing stale guest data.
  - Simplified Change Password validation and removed duplicate error messages while ensuring field visibility.
  - Enhanced `deleteAccount()` in `supabase_auth_repository.dart` to wipe user rows (`profiles`, `food_logs`, `weight_entries`, `burn_completions`) from Supabase Cloud.
  - Made `signOut()` resilient to offline socket exceptions so sign-out always completes locally (clearing local database and resetting state).
  - Made Age field in `profile_screen.dart` fully editable without keystroke reset by introducing `_ageFocusNode`.
  - Stripped `onboarding_complete` and guarded null `weight_kg` in `sync_service.dart` to eliminate Postgres schema cache and NOT NULL constraint log errors.
  - Handled AI photo scanning network/server errors with explicit snackbar notices instead of silent dummy fallback injection.
  - Fixed Progress screen `ExpansionTile` crash (`type 'double' is not a subtype of type 'bool?'`) by replacing `ExpansionTile` with custom `_CollapsibleHistoryCard` and `_WeekTileCard` stateful widgets, eliminating `PageStorage` type pollution.
  - Fixed seed importer `exercises.equipment NOT NULL` constraint failure on Android release device.
  - Updated `FoodLog` domain entity invariant (`quantity <= 0`) enabling fractional portions like `0.5` and `0.25` without runtime exceptions.
  - Redesigned `AppSnackbar` (24px bottom margin, 3s duration) and updated `TodayNotifier` with `restoreLog` for instant, seamless UNDO functionality.
  - Enhanced `ChangePasswordScreen` with `Form` validation, live complexity chips, real-time match status, and explicit error messages.
  - Redesigned Metabolic Reference display in `ProfileScreen` and added **Theme Mode** (`System`, `Light`, `Dark`) selector dropdown.
  - Ensured equipment-free/bodyweight exercises are always available in `burn_provider.dart` when surplus calories occur.
  - Increased `_CategoryTile` opacity to 0.75 and softened gradient overlays in `workout_hub_screen.dart`.
  - Added smart offline fallbacks for AI photo capture in `capture_screen.dart`.
  - Added portion/weight basis field and privacy note to `ManualEntrySheet`.
  - Fixed `_HeroSection` Column overflow in `workout_hub_screen.dart:290:24` inside 156px container.
  - Resolved `dropdown.dart:1402` assertion by eliminating un-valued divider `DropdownMenuItem` and guarding value parameters in `plan_screen.dart` and `profile_screen.dart`.
  - Fixed `Duplicate GlobalKey` and `_dependents.isEmpty` assertion on Plan tab by removing top-level `GlobalKey`s from `StatefulShellBranch` in `app_router.dart`.
  - Fixed profile wizard step 5 Riverpod `!_didChangeDependency` assertion by hoisting `ref.read` calls before `await` and adding `mounted` guards.
  - Fixed `sliver_list.dart:315` scroll flood in `progress_screen.dart` by assigning stable `ValueKey`s to children.
  - Added `onboarding_complete` flag to `Profile` model and SQLite schema (v15) with `_onUpgrade` guard. Updated Auth screen to hide 'Continue as Guest' when called from Profile screen and route directly to `/today` if onboarded.
  - Updated Today screen logged food tap handler to present read-only `_FoodLogDetailSheet` with portion edit and delete actions instead of reopening the search/add flow.

- J5 — Targeted Engineering & Sync Fixes
  - Fixed map type downcasts and explicit casts for `strict-casts: true` compliance (`flutter analyze` -> 0 issues).
  - Updated Sign-out sequence: pauses sync background triggers, clears user data, signs out, resets Riverpod app state, and navigates to `/today`.
  - Created `ChangePasswordScreen` at `/change-password` with current password re-auth, complexity validation, and updated `app_router.dart`.
  - Fixed Workout Hub taxonomy matching in `muscle_detail_screen.dart` (case-insensitive and muscle group aliases like arms, legs, back).

- J4.3 — Sync Architecture Fixes (Data integrity & Guest mode shield)
  - Unified SQLite type reading using a new `TolerantReader` utility to prevent integer vs double/bool TypeErrors across all repositories.
  - Re-wrote `SyncService._pullPhase` to explicitly map columns with `toSqliteValue`, mitigating the risk of raw JSON dynamic spread.
  - Implemented the Guest Mode Shield in `SyncService` (via `syncNow`) and repository `_enqueue` methods, completely preventing guest session writes to the push queue.
  - Fixed push queue batch duplicate bug: `_processPushBatch` now deduplicates rows using their specific conflict keys (e.g. `user_id_for_date` for weights) and ignores pushes if the cloud row is newer (`updated_at` last-write-wins).
  - Designed an auth state machine in `auth_screen.dart` to handle retry loops for `forcePullAll` during account takeover, ensuring users are never stuck with an empty local DB.

- J4.2 — Sync Fixes & UI Enhancements
  - Fixed sync queue crash by deduplicating batch rows by ID.
  - Handled `weight_one_per_day` constraint correctly in `GuestMergeService` and `SyncService` by adding `onConflict` logic.
  - Fixed `fl_chart` web compiler type error by ensuring integer variables are passed as explicitly typed doubles.
  - Overhauled Today screen cards to display images professionally with gradient overlays.
  - Realigned All Categories screen images to display properly without clipping.
  - Added pulse animation to Workout Hub banner and made category tiles slightly opaque.
- J4.1 — Progress Screen & UI Fixes
  - Fixed `fl_chart` crash (grey screen) when only 1 weight is logged.
  - Made the current weight label always use the latest date's weight.
  - Formatted the weight chart, goal weight line, and weight summary UI properly using the user's unit settings (kg vs lbs).
  - Fixed the UI scroll jump bug on the progress screen when saving a new weight by enabling `skipLoadingOnReload: true`.
  - Fixed ruler picker jumping issues in both `ProfileSetupScreen` and `WeightTrendSection` by assigning `ValueKey`s.
- J4 — Theming, Progress & Workout Hub UI Polish
  - Restored dynamic theme seed generation and added Theme Color selector to `ProfileScreen`.
  - Removed Weight/Height fields from Profile, keeping them isolated to Progress history.
  - Fixed weight trend graph logic and added day numbers to heatmap.
  - Redesigned Workout Hub to use large, sleek vertical list cards instead of stretched grid items, integrating generated real-world imagery with gradient text overlays.
  - Re-styled All Categories cards with sleek gradients and removed borders/alpha transparency.
  - Replaced machine scanner vector image with a generated photo-realistic image (equip_gym).
  - Created new Notification screen and linked the top app bar icon.
- J3 — Splash & Welcome Screen Redesign (mockup-based)
  - Redesigned SplashScreen: dark background with custom-painted runner silhouette, orange light trail arc, centered logo, and new motto "Eat Better. Burn Smarter. Live Stronger".
  - Rewrote WelcomeScreen as 4-page flow: Welcome page (Create Account / Continue as Guest / Login), "Log meals honestly" (phone scan + kcal range), "Burn smarter" (activity icons + runner), "Protect your streak" (flame + 18-day counter).
  - All graphics built with Flutter CustomPaint and Icons (no new image assets required).
  - Navigation: Back/Next between pages, Skip to /today, "Let's Start" on final page.
- J1 — Meal-first logic pivot & Welcome Screen
  - Shifted from calorie allowance model to a "debt" model where users only log guilt meals.
  - Updated TodayScreen, ProfileScreen, and StreakEngine to use `toBurn` instead of `remainingKcal`.
  - Fixed WelcomeScreen rendering bug and redesigned it to look more premium with animations and a larger logo.
  - All tests passing including ui_test overflow fixes.
- G4 — Google sign-in via Supabase
  - Added Google button on Login & Signup screens.
  - Supabase integration with `google_sign_in` plugin.
  - Implemented unit tests for routing and mocked auth.
  - Fixed hardcoded colors in `buttons.dart`.
- G5 — Splash + Welcome screen animations
  - Configured native splash using `flutter_native_splash`.
  - Implemented 1s scale + 1.5s fade-in motto animation on Splash.
  - Built auto-advancing (4s interval) carousel WelcomeScreen with parallax illustrations.
- Post-G3 Follow-up
  - Fixed "Unknown" meal bug (gracefully fallback to catalog name when sync API omits food_name)
  - Fixed "No burn plan" bug (seed data now guaranteed to load even if SplashScreen is skipped)

## Known issues / debt

- G1 (media re-conversion) is a manual step requiring original GIF source folder

## Notes for next session

- Run `flutter run` on device to verify G2.1 camera permission flow end-to-end
- G1 can be done anytime with: `python tool/convert_media.py <gif_folder> --out assets/exercise_media --fps 20 --max-side 320 --quality 75`
