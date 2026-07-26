# FitPilot — Agent Context (read me first)

Always read this file, then `docs/STATUS.md` (current state + current task).
Read other docs ONLY when relevant to the task:
- `docs/ARCHITECTURE.md` — before creating/moving any file or class
- `docs/DESIGN_SYSTEM.md` — before writing any UI
- `docs/DOMAIN_RULES.md` — before writing any calorie/streak/burn logic
- `docs/DECISIONS.md` — only if you think a past decision blocks you

## What this app is

FitPilot — calorie tracking app that shows honest calorie RANGES (never fake
exact numbers) and converts overeating into concrete burn plans (walk X min,
rope Y min). Motto: "Eat it. Burn it." Solo final-year project (COMSATS),
target users in Pakistan (desi food catalog, offline-friendly).

Stack: Flutter/Dart 3.x, Riverpod 2.x, go_router, SQLite. Milestone B adds
Supabase (auth + Postgres + RLS); C adds a Node/Express AI proxy (Gemini).
**Current phase: Milestone A — 100% offline. No backend code, no supabase
package, no HTTP calls of any kind.**

## Non-negotiable rules

1. Do EXACTLY the prompted task. No extra features, packages, files, or
   refactors. If something seems missing, say so instead of building it.
2. Layered architecture (docs/ARCHITECTURE.md). `lib/domain/` is pure Dart:
   no Flutter, no IO, no package imports except collection/equatable.
3. Every calorie value is a `KcalRange` (min–max). Never a single int.
4. UI uses ONLY the tokens in docs/DESIGN_SYSTEM.md. No blue, no gradients,
   no dark theme, no new colors.
5. Every screen: `SafeArea`, works at 320 px width, zero overflow banners.
6. No secrets/keys in code or config — ever.
7. New logic ships WITH its tests in the same task.

## Definition of done (every task)

1. `flutter analyze` → 0 issues
2. `flutter test` → all green
3. Update `docs/STATUS.md` (move task to Done, set Next, note any issues)
4. Append one line to `docs/DECISIONS.md` ONLY if a real design decision was made

## Commands

- `flutter analyze` · `flutter test` · `flutter run` (Pixel 6 emulator)
