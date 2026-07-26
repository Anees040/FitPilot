# FitPilot — Architecture

> Version 1.0 — July 2026

## 1. System overview
```
┌────────────────────────────────────────────────────────────┐
│ Flutter app (Android)                                      │
│  ├─ UI layer (see 06_UI_UX.md)                             │
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
     └───────────────────┘    │  rate-limit · quota · cache │
                              └──────────┬──────────────────┘
                                         │
                                  Gemini Flash (free tier)
```

## 2. Key decisions (ADR summary — memorize the "why")
| # | Decision | Why |
|---|---|---|
| AD-1 | On-device ML Kit OCR for label scan | Free at any scale, offline, instant, private. Hero feature costs Rs. 0/use |
| AD-2 | MET engine & streaks in pure Dart | Zero cost/latency/hallucination; best interview talking point |
| AD-3 | All LLM calls behind Express proxy | API key never ships in APK; server enforces quotas & caching |
| AD-4 | CRUD direct Flutter→Supabase; Express only for AI | Supabase free tier = unlimited API requests; avoids Render cold-start on every screen |
| AD-5 | Desi food DB ships in the app (Drift), synced from Postgres | 80% of text logs resolve locally → no AI call, offline support |
| AD-6 | Clean architecture: ui / domain / data layers, feature-first folders | Testability + future features (FF-1..4) slot in as new features |
| AD-7 | Riverpod for state management | Compile-safe DI, testable, industry-standard in 2026 |

## 3. Flutter project structure
```
app/lib/
  core/            # theme, router, l10n, constants, error types
  domain/          # ENTITIES + pure logic: met_engine/, streaks/, label_parser/
  data/            # drift db, supabase repos, sync queue, api client
  features/
    onboarding/  auth/  log/  today/  progress/  settings/
  main.dart
app/test/          # mirrors lib/; domain/ has 100% coverage
server/
  src/ routes/ middleware/ services/ (gemini.ts, cache.ts, quota.ts)
  test/
docs/              # this folder
.github/workflows/ci.yml
AGENTS.md          # AI coding agent contract
```

## 4. AI/ML strategy — you do NOT train models for MVP
**Rule: use pretrained models behind clean interfaces; "training" is curation + prompting + evaluation.**
- **Calorie prediction (photo):** Gemini Flash vision with a strict JSON-schema prompt (items, portion, kcal_min, kcal_max, confidence, follow_up_question). Improve via prompt iteration + a golden test set of 30 desi meal photos you label yourself. That eval set IS your "training" work.
- **Calorie from label:** deterministic regex/heuristic parser over OCR text. No ML beyond OCR.
- **Text parse:** local alias/fuzzy match first; Gemini fallback with same JSON schema.
- **Exercise recommendation:** NOT ML. Deterministic MET math + equipment filter. Say this proudly in interviews.
- **v2 machine scanner (FF-1):** Gemini vision classify → match against your curated machine DB (name, usage, technique, mistakes). If accuracy is weak, then consider transfer learning with TensorFlow Lite Model Maker on photos you collect at your gym — that's the first point custom training is justified.
- **v2 form check (FF-2):** MediaPipe BlazePose runs on-device in real time (33 landmarks) → compute joint angles → per-exercise heuristic rules (e.g. squat: knee angle range, back angle). Later: small classifier on landmark sequences. Zero server cost.

## 5. Free-tier budget & limits
| Service | Free limit | Design response |
|---|---|---|
| Supabase | 500MB DB, 50k MAU, unlimited API req; pauses after 7 idle days | Weekly GitHub Actions ping |
| Render | Free web service, cold starts ~30–60s | Cron ping every 10 min; async UX with loading states |
| Gemini Flash | ~10 RPM, ~1.5k req/day | Quota 3 photo-logs/day/user; response cache; local-first text parsing |
| ML Kit | Unlimited (on-device) | — |
| GitHub Actions | Free (public repo) | CI + cron pings |

## 6. Scalability posture (1,000+ users)
- On-device + local-DB paths (label, text, MET) scale infinitely at Rs. 0.
- AI path is quota'd and cached; at ~500 photo-logs/day the free Gemini tier saturates → paid tier is a config flip, architecture unchanged.
- Stateless Express → horizontal scale trivial. Postgres: indexes + pagination from day 1. Validate claims with k6 load test before writing numbers in README.

## 7. Error handling & observability
- Typed failures (`Failure` sealed class) surface as friendly UI states; never raw exceptions to users.
- Crashlytics for crashes; analytics events: `log_created{mode}`, `burn_completed`, `streak_broken`, `quota_hit`.
- Server: pino structured logs; no PII, no photo persistence.
