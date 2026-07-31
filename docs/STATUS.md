# STATUS — single source of truth for project state

> Agent: update this file at the end of EVERY successful task.
> Human: glance here before every new prompt.

## Current milestone: A — offline core (30% demo)

## Task board

- [x] A1 — Theme + 5-tab navigation shell
- [x] A2 — Domain entities + KcalRange (unit tested)
- [x] A3 — Local SQLite DB + seed food catalog (50+ desi foods)
- [x] A4 — Food search + manual log flow (M5)
- [x] A5 — Today screen with live day range (M4)
- [x] A6 — BurnPlanner engine + Burn Plan screen (M8)
- [x] A7 — StreakEngine + Progress screen (M9)
- [x] A8 — Local profile + settings (M3, local only)
- [x] B1 — Supabase init + env secrets
- [x] B2 — Auth UI + Guest data merge
- [x] B3 — Background sync service
- [x] B0+B4 — Barcode, Open Food Facts, and label OCR
- [x] F1 — Correctness and dead features
- [x] F2 — Foundation: launch, type, dark theme, adaptivity
- [x] F3 — Final Screen Redesign & Interaction Prompt
- [x] F4 — First impression: onboarding, illustration, empty states
- [x] F5 — Correctness + UX drop
- [x] F7 — Chrome/web correctness fixes
- [x] C1 — Exercise library and Burn Plan v2
- [x] C3 — Library & Capture UX polish
- [x] G2 — Critical bug fixes (camera permission, barcode lag, overflow, chip scroll, plan nav, offline images)
- [x] G3 — Auth UX (inline validation, password live checklist, OTP behavior, error mapping)
- [x] G4 — Google Sign-in (Auth UI, Supabase integration, routing)
- [x] G5 — Welcome UX (Native splash, flame animations, auto-carousel)

## Last completed

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
