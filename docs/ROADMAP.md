# FitPilot — Product Roadmap & Definition of Done

> STATUS.md tracks live, day-to-day progress. This file outlines the overall build plan (Milestones A → D & Phases).

Product goal: Public, free-to-use app running entirely on free tiers (Supabase, Render, Gemini free quota).

## Milestone A — Offline Core (30% Demo) — CURRENT

Entirely offline: SQLite + bundled seed data. No auth, no network.

| Task | Delivers | Realizes | Mockup |
| --- | --- | --- | --- |
| A1 | Theme + 5-tab nav shell | UI-1..4 | — |
| A2 | KcalRange + entities + engines' skeletons, unit tests | FR-2 basis | — |
| A3 | SQLite + seed import (50+ foods, 30+ exercises) | FR-2.1 | — |
| A4 | Food search + manual log (add/edit/delete) | FR-2.2–2.9 | M5 |
| A5 | Today screen: live day range vs allowance | FR-7.1–7.3 | M4 |
| A6 | BurnPlanner + Burn Plan screen + complete-burn flow | FR-5.1–5.6 | M8 |
| A7 | StreakEngine + Progress screen (streak + calendar) | FR-7.4–7.7 | M9 |
| A8 | Local profile (weight/height/goal/allowance/equipment) | FR-1.x (local) | M3 |

**Demo test:** Airplane mode ON → full loop works: log biryani → see range → go over → get burn plan → complete it → streak preserved.

## Milestone B — Accounts & Sync (50%)

| Task | Delivers | Realizes | Mockup |
| --- | --- | --- | --- |
| B1 | Supabase project, schema, RLS | NFR-S | — |
| B2 | Auth: email+OTP, guest mode, guest→account merge | FR-1.x | M2 |
| B3 | SyncService: queue push, pull-since, LWW | SDS SD-6 | — |
| B4 | Label scan: ML Kit OCR + LabelParser + saved products | FR-4.x | M7 |
| B5 | Weight tracking + trend chart | FR-6.x | M10 |
| B6 | Local notifications (meals, grace deadline, workout) | FR-9.x | M16 |
| B7 | Welcome/onboarding flow | — | M1, M3 |

## Milestone C — AI & Proxy Services (75%)

| Task | Delivers | Realizes | Mockup |
| --- | --- | --- | --- |
| C1 | Node/Express proxy on Render: JWT check, quota RPC, cache | FR-3, NFR-S | — |
| C2 | AI photo logging + quota UI + text-parse fallback | FR-3.x | M6 |
| C3 | Exercise library + detail screens | FR-8.1–8.3 | M11, M12 |
| C4 | Weekly planner (assign exercises to days, completions) | FR-8.4–8.7 | M13 |
| C5 | Render deploy + cold-start warm-up ping | OE | — |

## Milestone D — Advanced Features & Beta Release (100%)

| Task | Delivers | Realizes | Mockup |
| --- | --- | --- | --- |
| D1 | Machine scanner (photo → use case + technique) | FR-8.x ext | M14 |
| D2 | Form check: MediaPipe pose, on-device only | FR-8.x ext | M15 |
| D3 | FCM broadcast notifications | FR-9.x | — |
| D4 | Admin web dashboard (catalog CRUD, reports, stats) | FR-10.x | M17 |
| D5 | User reports flow in app | FR-10.x | — |
| D6 | Hardening: perf pass, security checklist, release builds | NFR-P/S | — |

## Definition of Done & Rules That Keep This Shippable

1. **Definition of Done (DoD) per Task:**
   - `flutter analyze` → 0 issues.
   - `flutter test` → all green.
   - Update `docs/STATUS.md`.
   - Append one line to `docs/DECISIONS.md` ONLY if a real design decision was made.

2. **Milestone Rules:**
   - A milestone is DONE only when its demo test passes on Pixel 6 emulator + 320 px width check.
   - Never start milestone N+1 tasks while `docs/STATUS.md` shows open milestone N tasks.
   - Free-tier budget is a feature: quota values and limits live in server config.

## v2 Backlog (Post-Beta)
- Machine scanner (Gemini vision + curated machine DB)
- Form check (MediaPipe BlazePose on-device, joint-angle rules)
- Planner (gym/outdoor/calisthenics templates)
- Voice logging & Roman Urdu localization
