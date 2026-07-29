# FitPilot — Software Requirements Specification (SRS)

> Version 1.0 — July 2026 · Follows IEEE 830 structure, trimmed for a solo project.

## 1. Introduction
**Purpose:** Define what FitPilot MVP must do, so every Antigravity/AI coding session works against a fixed contract.
**Scope:** Android app (Flutter) + Node/Express AI-proxy API + Supabase (Postgres/Auth).
**Definitions:** MET = Metabolic Equivalent of Task. RLS = Row-Level Security. DoD = Definition of Done.

## 2. Functional requirements

### 2.1 Accounts & profile
- **FR-1.1** Sign up / sign in with email+password and Google (Supabase Auth).
- **FR-1.2** Onboarding collects: weight (kg), height (cm), age, sex, activity level, available equipment (multi-select: none/gym/cycle/skipping rope), goal (maintain/lose).
- **FR-1.3** Profile editable later; weight change recalculates future burn plans only.

### 2.2 Food logging
- **FR-2.1 Label scan (hero):** camera → on-device OCR (ML Kit) → parse kcal/serving + serving size → user sets servings eaten → log entry. Must work offline.
- **FR-2.2 Text log:** free text in English/Roman Urdu ("2 samosay", "aik plate biryani"). Resolution order: exact alias match in local food DB → fuzzy match → server LLM fallback. Must work offline for DB hits.
- **FR-2.3 Photo log:** meal photo → server → Gemini vision → items + portion estimate + range + confidence. Max 3/day/user (quota).
- **FR-2.4** Every estimate displays a **range** (kcal_min–kcal_max) and confidence level (high/medium/low). Single-number displays are forbidden.
- **FR-2.5** When confidence = low, app asks exactly ONE follow-up question (e.g. "thin crust ya thick?"), then finalizes.
- **FR-2.6** User can edit/delete any log entry.

### 2.3 Burn Converter (deterministic core)
- **FR-3.1** Any logged kcal → ≥3 personalized burn options computed as: minutes = kcal / (MET × 3.5 × weight_kg / 200). Pure Dart, no network, no AI.
- **FR-3.2** Options filtered by user's equipment; always include walking (steps estimate) as universal fallback.
- **FR-3.3** User picks an option → burn plan created; can mark complete or partially complete (%).
- **FR-3.4** MET table stored locally, sourced from the Compendium of Physical Activities; values documented in 04_Database.md.

### 2.4 Streaks & history
- **FR-4.1** Streak survives a surplus day if the surplus is burned within 24h; breaks only on unburned surplus.
- **FR-4.2** Today screen: kcal in (range), burned, net balance, active burn plans.
- **FR-4.3** Progress screen: 7/30-day history, streak count, personal bests.

### 2.5 System behaviors
- **FR-5.1** Offline-first: label/text logging + Burn Converter fully functional offline; sync queue flushes when online.
- **FR-5.2** Quota: server rejects 4th photo-log of the day with a friendly client message.
- **FR-5.3** Local notifications only (burn reminder at +4h if plan incomplete). No push infra in MVP.

## 3. Non-functional requirements
| ID | Category | Requirement |
|---|---|---|
| NFR-1 | Performance | Label scan → result < 3s on-device; text (local) < 1s; photo < 10s p90 |
| NFR-2 | Scalability | Stateless API; DB indexed & paginated; 1,000+ users = tier upgrade, not rewrite |
| NFR-3 | Availability | Full core functionality with AI quota exhausted or server down |
| NFR-4 | Security | No secrets in APK; JWT verified server-side; RLS on all tables; per-user rate limits |
| NFR-5 | Privacy | Meal photos processed in memory, never persisted; no data sold; clear disclaimer |
| NFR-6 | Cost | Rs. 0/month infra on free tiers (see 03_Architecture.md §5) |
| NFR-7 | Accessibility | 44px touch targets, WCAG AA contrast, one-handed use |
| NFR-8 | Safety | Not medical advice; no calorie targets below safe floors; "consult a doctor" gating |
| NFR-9 | Quality | 100% unit-test coverage on MET engine, streak logic, label parser; CI green required to merge |
| NFR-10 | Localization-ready | All strings via l10n from day 1 (English now; Urdu later) |

## 4. Future requirements (v2+ backlog — architecture must not block these)
- **FF-1 Machine scanner:** photo of gym machine → Gemini vision classification against curated machine DB → usage, technique, mistakes, sets/reps by level.
- **FF-2 Form check:** record video → MediaPipe BlazePose (on-device, 33 landmarks) → joint-angle heuristics per exercise → right/wrong + corrections. No custom model training required initially.
- **FF-3 Planner:** weekly routines (gym/outdoor/calisthenics) generated from templates + user profile, adapted by logs.
- **FF-4 Voice logging** via on-device speech-to-text.

## 5. Constraints & assumptions
- Solo developer, AI-assisted, ~9 weeks part-time.
- Android-first; iOS deferred.
- Free tiers only: Supabase, Render, Gemini free tier, ML Kit (on-device), GitHub Actions.
- Play Store $25 fee deferred until beta proves demand (distribute APK directly first).
