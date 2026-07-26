# FitPilot — Roadmap & Definition of Done

> Version 1.0 — July 2026 · Rule: a phase starts only when the previous phase's DoD is fully checked.

## Phase 0 — Foundation (3–4 days)
- [ ] Repo: monorepo `/app` (Flutter), `/server`, `/docs` (these files), `AGENTS.md` at root
- [ ] Flutter scaffold: folder structure per 03_Architecture.md §3, Riverpod, go_router, theme tokens from 06_UI_UX.md §2, empty 3-tab shell
- [ ] Supabase project + schema + RLS (04_Database.md §§1–2, 4)
- [ ] Express hello-world deployed on Render with /v1/health; env vars set
- [ ] Gemini API key created (AI Studio) → Render env only
- [ ] CI: GitHub Actions — flutter analyze + flutter test + server lint/test on every push; cron keep-alive jobs
- **DoD:** app runs with themed empty tabs; /v1/health live; CI green; no secrets in repo (verify with gitleaks or manual grep).

## Phase 1 — Deterministic core (Weeks 1–2)
- [ ] Onboarding + profile → Supabase; local persistence
- [ ] MET engine (pure Dart) with fixtures from 04_Database.md §3 — write tests FIRST
- [ ] Streak logic module — test-first, includes midnight/timezone cases
- [ ] Seed 50-food desi DB (YOU verify every range; AI only drafts)
- [ ] Text logging w/ local alias+fuzzy match, follow-up question UI, result sheet, Today screen v1
- **DoD:** log all your meals for 3 days text-only; 100% coverage on domain/; streak math survives midnight test.

## Phase 2 — Label scan hero (Weeks 3–4)
- [ ] ML Kit OCR integration; deterministic label parser (test-first against 20 photographed Pakistani labels in test fixtures)
- [ ] Servings multiplier UI; offline queue + sync
- **DoD:** ≥15/20 real labels parse correctly; full label flow works in airplane mode.

## Phase 3 — AI features (Weeks 5–6)
- [ ] Server: /v1/ai/photo-estimate + /v1/ai/text-parse per 05_API.md (JWT, quota, cache, zod, golden-set eval)
- [ ] Photo logging UI (range + confidence + one follow-up); quota-hit state
- [ ] Streak surfacing + local burn reminder notification
- **DoD:** real dinner photo → sane range < 10s; 4th photo of day blocked cleanly; app fully usable with server killed.

## Phase 4 — Polish & beta (Weeks 7–8)
- [ ] All empty/loading/error/offline states; onboarding polish; disclaimers ('not medical advice')
- [ ] Crashlytics + analytics events; k6 load test on API (document numbers)
- [ ] Signed release APK → 20 gym friends via WhatsApp; Google Form feedback
- **DoD:** 20 installs; ≥10 users with 3+ days of logs; crash-free > 99%.

## Phase 5 — Ship the story (Week 9)
- [ ] README: problem → architecture diagram → screenshots → REAL numbers (users, D7 retention, label accuracy, p90 latency, load test) → "what I'd do differently"
- [ ] 2-min screen-recorded demo; LinkedIn build-in-public post; CV bullet
- **CV bullet:** "Built & shipped FitPilot — Flutter + Node/PostgreSQL fitness app with on-device OCR and a deterministic MET burn engine; N beta users, X% D7 retention, $0/mo infra; quota+cache layer kept AI cost at zero across 1,000+ requests."

## v2 backlog (untouched until 20 real users)
Machine scanner (Gemini vision + curated machine DB) → Form check (MediaPipe BlazePose on-device, joint-angle rules) → Planner (gym/outdoor/calisthenics templates) → voice logging → Urdu l10n → Play Store ($25) → iOS.
