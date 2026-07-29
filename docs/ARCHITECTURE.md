# FitPilot — Architecture & Project Structure

> Version 1.0 — July 2026

## 1. Layers & Dependency Rules

Dependency arrows point **DOWN** only.

| Layer | Path | Contains | May import |
| --- | --- | --- | --- |
| Presentation | `lib/features/<feature>/` | screens, widgets | Application, Domain |
| Application | `lib/features/<feature>/providers/` | Riverpod providers/controllers | Domain, Data (interfaces) |
| Domain | `lib/domain/` | entities, engines (pure Dart) | NOTHING (no Flutter, no IO) |
| Data | `lib/data/` | repositories, SQLite datasource, seed loader | Domain |
| Core | `lib/core/` | theme, router, constants, utils | — |

*Screens NEVER touch the database or repositories directly — always through providers.*

## 2. Folder Structure

```
lib/
  core/        # theme, router, constants, utils
  domain/      # entities (KcalRange, FoodItem, FoodLog, Profile, BurnOption, DayStatus, StreakState)
               # engines (RangeCalculator, BurnPlanner, StreakEngine, QuotaPolicy, LabelParser)
  data/        # local (sqlite datasource, seed import), repositories
  features/    # today/, log/, plan/, progress/, profile/, onboarding/, auth/
main.dart
test/          # mirrors lib/ structure; domain has 100% coverage
assets/        # seed/foods.json, seed/exercises.json, icon/
server/        # Node.js + Express proxy (src/, routes/, middleware/, services/)
docs/       # project documentation
```

## 3. System Overview

```
┌────────────────────────────────────────────────────────────┐
│ Flutter app (Android)                                      │
│  ├─ UI layer                                               │
│  ├─ Domain layer: MET engine · streak logic · label parser │  ← deterministic, 100% tested
│  ├─ Data layer: Drift (SQLite) offline cache + sync queue  │
│  ├─ ML Kit Text Recognition (on-device OCR)                │
│  └─ supabase_flutter (Auth + Postgres CRUD, RLS-guarded)   │
└──────────────┬─────────────────────────┬───────────────────┘
               │ JWT                     │ JWT
     ┌─────────▼─────────┐    ┌──────────▼──────────────────┐
     │ Supabase (free)   │    │ Node.js + Express on Render │
     │  Postgres + RLS   │    │  POST /v1/ai/photo-estimate │
     │  Auth (email,     │    │  POST /v1/ai/text-parse     │
     │  Google OAuth)    │    │  Gemini key lives HERE only │
     │                   │    │  rate-limit · quota · cache │
     └───────────────────┘    └──────────┬──────────────────┘
                                         │
                                  Gemini Flash (free tier)
```

## 4. Key Architectural Decisions & Design Facts

### ADR Summary
| # | Decision | Why |
|---|---|---|
| AD-1 | On-device ML Kit OCR for label scan | Free at any scale, offline, instant, private. Hero feature costs Rs. 0/use |
| AD-2 | MET engine & streaks in pure Dart | Zero cost/latency/hallucination; best interview talking point |
| AD-3 | All LLM calls behind Express proxy | API key never ships in APK; server enforces quotas & caching |
| AD-4 | CRUD direct Flutter→Supabase; Express only for AI | Supabase free tier = unlimited API requests; avoids Render cold-start on every screen |
| AD-5 | Desi food DB ships in the app (Drift), synced from Postgres | 80% of text logs resolve locally → no AI call, offline support |
| AD-6 | Clean architecture: ui / domain / data layers, feature-first folders | Testability + future features slot in cleanly |
| AD-7 | Riverpod for state management | Compile-safe DI, testable, industry-standard in 2026 |

### Core Design Rules
- **Offline-first:** Every write hits local SQLite first. (Sync/auth arrive in Milestone B).
- **Derived state:** Derived state (day totals, streaks) is RECOMPUTED by pure engines via derived providers — never stored, so it can never disagree with the data.
- **UUIDs:** IDs are client-generated UUIDs (safe for later sync).
- **Deterministic Testing:** Engines get `DateTime now` as a PARAMETER (testability); never call `DateTime.now()` inside domain code.

## 5. AI/ML Strategy
- **Calorie prediction (photo):** Gemini Flash vision with a strict JSON-schema prompt (items, portion, kcal_min, kcal_max, confidence, follow_up_question). Prompt iteration + golden eval set of 30 desi meal photos.
- **Calorie from label:** Deterministic regex/heuristic parser over OCR text. No ML beyond OCR.
- **Text parse:** Local alias/fuzzy match first; Gemini fallback with same JSON schema.
- **Exercise recommendation:** Deterministic MET math + equipment filter.
- **v2 Machine scanner:** Gemini vision classify → match against curated machine DB.
- **v2 Form check:** MediaPipe BlazePose runs on-device in real time (33 landmarks) → joint-angle rules.

## 6. Free-Tier Budget & Scalability
| Service | Free limit | Design response |
|---|---|---|
| Supabase | 500MB DB, 50k MAU, unlimited API req; pauses after 7 idle days | Weekly GitHub Actions ping |
| Render | Free web service, cold starts ~30–60s | Cron ping every 10 min; async UX with loading states |
| Gemini Flash | ~10 RPM, ~1.5k req/day | Quota 3 photo-logs/day/user; response cache; local-first text parsing |
| ML Kit | Unlimited (on-device) | — |
| GitHub Actions | Free (public repo) | CI + cron pings |

- On-device + local-DB paths (label, text, MET) scale infinitely at Rs. 0.
- AI path is quota'd and cached; stateless Express → horizontal scale trivial.

## 7. Error Handling & Observability
- Typed failures (`Failure` sealed class) surface as friendly UI states; never raw exceptions.
- Crashlytics for crashes; analytics events: `log_created{mode}`, `burn_completed`, `streak_broken`, `quota_hit`.
- Server: pino structured logs; no PII, no photo persistence.
