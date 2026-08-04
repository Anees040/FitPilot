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

## Last completed

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
