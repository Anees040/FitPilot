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

## Last completed

- F7 — Chrome/web correctness fixes
(Included SQLite web fix, BurnPlanner UI filters, Profile synchronization fixes, and Splash animation)

## Known issues / debt

(none)

## Notes for next session

- Polish pass is complete.
- Milestone C starts with adding the Supabase backend features, replacing mock data, and integrating the Node/Express AI proxy (Gemini) for food analysis.
