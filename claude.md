# FitPilot — project guide for Claude Code

## What this app is
FitPilot ("Eat it. Burn it.") — an offline-first Flutter app: log food (manual, catalog, barcode, AI photo scan, label OCR), then burn the surplus with an exercise plan. Solo final-year project by Muhammad Anees. Currently in Milestone C (fix waves O1–O5, then feature waves P1–P3).

## Stack
- Flutter 3.35.x (Dart SDK ^3.10.4), Riverpod, go_router, raw sqflite — hand-written SQL and migrations in `lib/data/local/app_database.dart`. No ORM, no Drift, no code generation anywhere in this repo. The local DB is the source of truth (offline-first).
- Supabase: auth (email+OTP, Google) + cloud sync (push/pull with a sync_queue table).
- Node/Express proxy in server/, deployed on Render free tier (cold starts up to ~60s): https://fitpilot-js0j.onrender.com — ALL Gemini AI calls go through it. The app must never call Gemini directly or contain the API key.
- Secrets come from env.json via --dart-define-from-file (SUPABASE_URL, SUPABASE_ANON_KEY, WEB_CLIENT_ID, PROXY_URL). env.json is gitignored.

## Commands (Windows PowerShell — chain with ; never &&)
- Analyze: flutter analyze
- Tests: flutter test
- Schema change: edit `lib/data/local/app_database.dart` by hand — bump the `version:` literal in BOTH `AppDatabase.instance()` and `AppDatabase.inMemory()` (currently 19), add the matching step to `_onUpgrade`, and append a line to the version-history doc comment above the class. There is no build_runner / codegen step in this project.
- Run web: flutter run -d chrome --dart-define-from-file=env.json
- Release APK: flutter build apk --release --split-per-abi --dart-define-from-file=env.json

## Layout
The project is layered first, feature-sliced only at the UI edge. Features do NOT own data/ or domain/ folders.
- `lib/core` — theme (`core/theme/app_theme.dart`), env (`core/config/env.dart`), routing (`core/navigation/app_router.dart`), shared widgets (`core/ui/`), services, utils
- `lib/domain` — pure Dart: `entities/`, `engines/` (burn_planner, target_calculator, range_calculator, streak_engine, quota_policy, reminder_scheduler), `repositories/` (interfaces)
- `lib/data` — `local/` (app_database.dart, seed_importer.dart), `repositories/` (implementations), `remote/`, `sync/`, `auth/`, `ai/`, `ocr/`, `notifications/`, `services/`
- `lib/application` — `bootstrap.dart` and `providers/` — ALL Riverpod providers live here, one file per area (today, burn, capture, profile, sync, auth, exercise, programs, progress, …). Do not declare providers inside `lib/features/`.
- `lib/features/<feature>/presentation` — screens and feature-local widgets only: today, log, plan, progress, profile, capture, exercises, programs, auth, settings, splash
- Routing: go_router in `lib/core/navigation/app_router.dart`; shell tabs /today /log /plan /progress /profile, plus top-level routes (/splash /welcome /auth /otp /profile-setup /capture /exercises /workout-hub /notifications …)
- Seed data: assets/seed/{foods,exercises,programs}.json imported by `lib/data/local/seed_importer.dart` on first run
- server/index.js — Gemini proxy endpoints (/api/health, /api/estimate-food, more coming), with a per-device daily quota
- Tests mirror lib/ under test/, plus `test/architecture/` guards

## Hard rules
- NEVER print, log, commit, or copy values from env.json or any API key. If a change would touch env.json or .gitignore, stop and ask.
- All colors and text styles come from the theme: theme.extension<AppColors>()! and theme.textTheme (h1/h2/body/caption). `test/architecture/theme_usage_test.dart` scans every file under lib/ and fails on raw color literals (`Colors.*`, `Color(0x…)`) and on `AppTheme.*` statics other than the theme getters; only app_theme.dart is exempt — never bypass, whitelist, or edit that test to make it pass. Palette "Ember Night": dark background, orange accent #FF8A4C, lime #D3F158. No blue.
- Imports use package:fitpilot/... — no relative ../ imports across features.
- Offline-first: manual/catalog food logging, burn plan, progress, profile edits must work with no network. Only genuinely online features (AI scan, auth, sync, machine scanner, coach chat) may require it.
- Energy math everywhere: kcal/min = MET × 3.5 × weightKg ÷ 200.
- Schema changes: bump the DB version and write a real `_onUpgrade` migration in app_database.dart so existing installs upgrade without data loss. Never delete-and-recreate a table that holds user data.
- Don't add new packages without stating why; prefer what's already in pubspec.yaml.

## Wave protocol
Muhammad pastes one wave prompt at a time (O1..O5, P1..P3) from the Notion build plan. Treat the prompt as the spec:
1. Give a short plan first (files you'll touch, in what order). Wait for OK.
2. Implement. If the real code contradicts a prompt assumption, say so and adapt — the acceptance criteria still stand.
3. Run flutter analyze and flutter test; fix until both are clean.
4. Print a short manual test script (Chrome + Android) for this wave.
5. git add -A; git commit -m "<wave>: <one-line summary>". Never git push unless asked.
Stay strictly inside the wave's scope — no drive-by refactors.
