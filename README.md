# FitPilot

> **Eat it. Burn it.** — Your food's honest price tag, and your coach in the gym.

[![CI](https://github.com/Anees040/FitPilot/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/Anees040/FitPilot/actions/workflows/flutter_ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter&logoColor=white&color=555)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-555)
![Tests](https://img.shields.io/badge/tests-137%20passing-success)

---

## The Problem

FitPilot exists because of three real frustrations that existing fitness apps don't solve honestly:

1. **"I want to enjoy fast food sometimes — without losing my progress."** You shouldn't need to track every meal of every day like a full-time job. But when you *do* indulge, you deserve a straight answer: what did that actually cost, and exactly which exercise — for how many minutes, at *your* body weight — clears the bill? Most apps give you guilt and a fake-precise number. FitPilot gives you an honest calorie range and a concrete burn plan.

2. **"I'm standing in the gym and I don't know how to use this machine."** Every gym has machines people avoid because nobody taught them. Bad technique wastes months and causes injuries. FitPilot's goal: point your camera at a machine and learn what it trains, how to set it up, and the mistakes to avoid — then record a set and get rep-by-rep technique feedback, like a coach who never judges you.

3. **"I want a plan built for me — not a generic PDF."** Build muscle, lose fat, or maintain; calisthenics or weight training; beginner or advanced; 2 months or 6. Pick your answers and get a weekly plan you can actually follow.

**FitPilot is built for episodic use, not daily surveillance.** Days you don't log are neutral — they never break your streak, never turn red, never guilt you. The streak means one thing: *every time you did show up, you handled it.*

## The Three Pillars

| Pillar | What it does | Status |
| --- | --- | --- |
| 🍔 **Eat it, burn it** | Log any food (search, barcode, nutrition label) → honest kcal range → surplus converted into a personalised burn plan with a grace deadline | ✅ Built |
| 🏋️ **Gym coach** | Machine scanner (what is this, how do I use it) + AI form check with rep-by-rep technique feedback | ✅ Built |
| 📅 **Plans that fit you** | Goal + training style + level + duration → customised weekly plan; full exercise library with technique guides | ✅ Built |

## Features (current build)

### Honest food logging
- Searchable local food catalog with Urdu aliases, portion labels, and verified entries
- Custom foods and quick manual entry with validation
- **Barcode scanning** backed by the Open Food Facts database (v2 API), with kJ→kcal conversion and explicit provenance
- **Nutrition-label OCR** (on-device ML Kit) with per-field confidence flagging and full user correction before anything is saved
- Calorie *ranges* for estimated foods — a single exact number appears only when it is genuinely known (barcode or label)

### Burn planning
- Surplus converted into equivalent activity minutes using MET-based energy expenditure (kcal/min = MET × 3.5 × kg ÷ 200), personalised to the user's weight
- Multiple activity options — walking always available, no equipment required
- Grace deadline (next day 11:59 AM) to clear a surplus and keep the day counted as a win

### Progress without guilt
- Streak engine with a three-state day model: safe, over-unresolved, and **neutral no-log days**
- 35-day calendar heat map, weekly intake/burn summaries, and weight trend tracking
- Local notifications, including streak-protection reminders that name the deadline and the smallest available burn option

### Platform & reliability
- **Offline-first:** every feature that can work without a network, works without a network (SQLite on device)
- **Background sync** to Supabase (PostgreSQL) with a durable sync queue, retry with exponential backoff, and guest-to-account data merge on first sign-in
- Email/password authentication with OTP verification (Supabase Auth); Row Level Security (`auth.uid() = user_id`) on every user table
- Full light & dark themes, responsive from 320 px phones to landscape tablets, system text-scale support (clamped 0.85–1.15)

## Screenshots & UI Showcase

To keep the documentation clean and fast to load, screenshots are organized by category. Click any category below to expand and view the interface.

<details>
<summary><b>🚀 Onboarding & Authentication</b> (Click to expand)</summary>

| Welcome Screen | Login | Sign Up |
| :---: | :---: | :---: |
| <img src="docs/screenshots/auth/welcome.jpg" width="200"> | <img src="docs/screenshots/auth/login.jpg" width="200"> | <img src="docs/screenshots/auth/signup.jpg" width="200"> |

#### Profile Setup Wizard
| Step 1: Goals | Step 2: Activity | Step 3: Body Info | Step 4: Targets | Step 5: Complete |
| :---: | :---: | :---: | :---: | :---: |
| <img src="docs/screenshots/auth/wizard_1.jpg" width="200"> | <img src="docs/screenshots/auth/wizard_2.jpg" width="200"> | <img src="docs/screenshots/auth/wizard_3.jpg" width="200"> | <img src="docs/screenshots/auth/wizard_4.jpg" width="200"> | <img src="docs/screenshots/auth/wizard_5.jpg" width="200"> |

</details>

<details>
<summary><b>📊 Dashboard & Food Logging</b> (Click to expand)</summary>

| Today (Home) | Today (Detailed) | Log Screen | Barcode Scanner |
| :---: | :---: | :---: | :---: |
| <img src="docs/screenshots/log/today_1.jpg" width="200"> | <img src="docs/screenshots/log/today_2.jpg" width="200"> | <img src="docs/screenshots/log/log_screen.jpg" width="200"> | <img src="docs/screenshots/log/scanner.jpg" width="200"> |

</details>

<details>
<summary><b>📈 Progress Tracking</b> (Click to expand)</summary>

| Enter Height | Log Weight | Progress Trend 1 | Progress Trend 2 | Progress Trend 3 |
| :---: | :---: | :---: | :---: | :---: |
| <img src="docs/screenshots/progress/enter_height.jpg" width="200"> | <img src="docs/screenshots/progress/log_weight.jpg" width="200"> | <img src="docs/screenshots/progress/progress_1.jpg" width="200"> | <img src="docs/screenshots/progress/progress_2.jpg" width="200"> | <img src="docs/screenshots/progress/progress_3.jpg" width="200"> |

</details>

<details>
<summary><b>🏋️ Workout Programs & Plans</b> (Click to expand)</summary>

| Programs Hub | Program Details | Workout Hub | Exercises List | Exercise Detail |
| :---: | :---: | :---: | :---: | :---: |
| <img src="docs/screenshots/workouts/programs.jpg" width="200"> | <img src="docs/screenshots/workouts/program_detail.jpg" width="200"> | <img src="docs/screenshots/workouts/workout_hub.jpg" width="200"> | <img src="docs/screenshots/workouts/shoulders.jpg" width="200"> | <img src="docs/screenshots/workouts/exercise_detail.jpg" width="200"> |

#### Personalized Burn Plans
| Plan Screen 1 | Plan Screen 2 |
| :---: | :---: |
| <img src="docs/screenshots/workouts/plan_1.jpg" width="200"> | <img src="docs/screenshots/workouts/plan_2.jpg" width="200"> |

</details>

<details>
<summary><b>🤖 AI Gym Coach</b> (Click to expand)</summary>

| Coach Screen | Machine Scanner (AI) | Form Check (AI) |
| :---: | :---: | :---: |
| <img src="docs/screenshots/coach/coach.jpg" width="200"> | <img src="docs/screenshots/coach/machine_scanner.jpg" width="200"> | <img src="docs/screenshots/coach/form_check.jpg" width="200"> |

</details>

<details>
<summary><b>⚙️ Settings</b> (Click to expand)</summary>

| Profile Screen | Profile Settings | Account Settings | App Settings |
| :---: | :---: | :---: | :---: |
| <img src="docs/screenshots/settings/profile.jpg" width="200"> | <img src="docs/screenshots/settings/profile_setting.jpg" width="200"> | <img src="docs/screenshots/settings/account_setting.jpg" width="200"> | <img src="docs/screenshots/settings/app_settings.jpg" width="200"> |

</details>

<details>
<summary><b>🎨 Theme Customization</b> (Click to expand)</summary>

FitPilot supports system-wide Light & Dark theme toggle along with a selection of vibrant accent colors (Orange, Blue, Purple, Red) customizable in preferences.

<img src="docs/screenshots/custom/theme_customization.jpg" width="600">

</details>

## Architecture

FitPilot follows a strict layered (clean) architecture. Dependencies point inward only — the domain layer imports nothing from Flutter, the database, or the network.

```
┌──────────────────────────────────────────────────────┐
│  features/    Presentation (screens, widgets)        │
│               Flutter + Riverpod consumers           │
├──────────────────────────────────────────────────────┤
│  application/ State & orchestration (providers,      │
│               bootstrap, notifiers)                   │
├──────────────────────────────────────────────────────┤
│  data/        Repositories, SQLite, Supabase sync,   │
│               Open Food Facts client, auth            │
├──────────────────────────────────────────────────────┤
│  domain/      Pure Dart: entities, calorie/streak/   │
│               burn engines. Zero external deps        │
└──────────────────────────────────────────────────────┘
```

Key design decisions (full rationale in [`docs/DECISIONS.md`](docs/DECISIONS.md)):

| Decision | Rationale |
| --- | --- |
| Offline-first with sync queue | Target users cannot depend on constant connectivity; the app must be fully usable offline |
| Calorie ranges as a first-class type (`KcalRange`) | Prevents false precision from ever entering the domain model |
| Neutral no-log days in the streak engine | The app is designed for episodic use — skipping days is normal life, not failure |
| Day status computed from range **midpoint** | Deterministic, explainable streak decisions |
| All AI/photo features proxied server-side | API keys never ship inside the binary |
| Architecture tests in CI | A test suite enforces the design system (e.g. no hard-coded colors outside theme files) |

## Tech Stack

| Layer | Technology |
| --- | --- |
| UI | Flutter 3.x (Material 3), custom design system, Inter typeface (bundled) |
| State management | Riverpod 2.x |
| Navigation | go_router |
| Local persistence | SQLite (sqflite) with versioned migrations |
| Backend | Supabase — PostgreSQL, Auth (OTP), Row Level Security |
| Food data | Open Food Facts API v2 |
| On-device ML | Google ML Kit text recognition (label OCR), mobile_scanner (barcodes) |
| Charts | fl_chart |
| Notifications | flutter_local_notifications + timezone |
| CI | GitHub Actions (analyze + full test suite on every push) |

## Getting Started

### Prerequisites

- Flutter SDK 3.x (stable channel) — verify with `flutter doctor`
- A device or emulator running Android 5.0+ (API 21)
- A free [Supabase](https://supabase.com) project (optional — the app runs fully offline as guest without it)

### Setup

```bash
git clone https://github.com/Anees040/FitPilot.git
cd FitPilot
flutter pub get
```

Create `env.json` in the project root (see `env.example.json`):

```json
{
  "SUPABASE_URL": "https://YOUR-PROJECT.supabase.co",
  "SUPABASE_ANON_KEY": "YOUR-ANON-KEY"
}
```

> `env.json` is git-ignored. No secret is ever committed to this repository; the Supabase anon key is safe for clients only because every table enforces Row Level Security.

### Run

```bash
# Development (hot reload)
flutter run --dart-define-from-file=env.json

# Performance testing — always judge startup time & animations in release mode
flutter run --release --dart-define-from-file=env.json
```

## Testing

```bash
flutter analyze   # static analysis — 0 issues policy
flutter test      # full suite
```

The suite currently contains **137 tests** across five categories:

| Category | What it covers |
| --- | --- |
| `test/domain/` | Calorie range math, burn planner, streak engine (grace deadlines, neutral days), target calculator |
| `test/data/` | Repositories, sync queue & backoff, Open Food Facts client (including kJ conversion and malformed responses) |
| `test/application/` | Provider behaviour, seed import idempotency |
| `test/features/` | Widget tests, including layout tests at 320×640 to guarantee zero render overflows |
| `test/architecture/` | Design-system enforcement — e.g. no raw color literals outside theme files |

## Project Structure

```
lib/
├── application/     # Riverpod providers, app bootstrap
├── core/            # Theme, design tokens, shared UI components, navigation
├── data/            # SQLite, repositories, Supabase sync, OFF client, auth
├── domain/          # Pure Dart entities & engines (no Flutter imports)
└── features/        # One folder per screen: today, log, plan, progress, ...
assets/              # Fonts (Inter), line-art illustrations, seed data
docs/                # Living project documentation (see below)
test/                # Mirrors lib/ structure + architecture tests
tool/                # Development utility scripts
```

## Documentation

This project maintains living documentation designed for both humans and AI coding agents:

| Document | Purpose |
| --- | --- |
| [`docs/STATUS.md`](docs/STATUS.md) | Current phase and active work |
| [`docs/ROADMAP.md`](docs/ROADMAP.md) | Milestone plan and completion criteria |
| [`docs/ARCHITECTURE.md`](docs/ARCHITECTURE.md) | Layering rules and data flow |
| [`docs/DOMAIN_RULES.md`](docs/DOMAIN_RULES.md) | Calorie math, streak & grace rules — the source of truth |
| [`docs/DESIGN_SYSTEM.md`](docs/DESIGN_SYSTEM.md) | Brand, color tokens, typography |
| [`docs/UI_SPEC.md`](docs/UI_SPEC.md) | Pixel-level screen specifications |
| [`docs/DECISIONS.md`](docs/DECISIONS.md) | Architecture decision records |

## Roadmap

| Milestone | Scope | Pillar | Status |
| --- | --- | --- | --- |
| **A — Offline core** | Domain engines, local logging, burn plans, streaks | 🍔 | ✅ Complete |
| **B — Connected** | Supabase auth & sync, barcode, label OCR, weight, notifications | 🍔 | ✅ Complete |
| **B.5 — Fix & polish** | Device-verified UX pass, design system enforcement | — | ✅ Complete |
| **C — Plans & library** | Exercise library with technique guides, weekly planner, program templates (goal × style × level × duration), AI photo food estimation via server-side proxy | 📅 | ✅ Complete |
| **D — Gym coach** | Machine scanner, AI form check with rep-by-rep feedback, push notifications, admin dashboard | 🏋️ | ✅ Complete |

## Author

**Muhammad Anees** — BS Software Engineering, COMSATS University Islamabad.

FitPilot is a solo Final Year Project exploring disciplined, AI-assisted software engineering: specification-first development, layered architecture, and human acceptance testing over raw test counts.

---

*This repository currently has no open-source license; all rights reserved. The project is shared publicly for academic evaluation and portfolio purposes.*
