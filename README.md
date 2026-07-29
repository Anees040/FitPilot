# FitPilot

> **Eat it. Burn it.** — An honest calorie companion that never pretends to know what it cannot know.

[![CI](https://github.com/Anees040/FitPilot/actions/workflows/flutter_ci.yml/badge.svg)](https://github.com/Anees040/FitPilot/actions/workflows/flutter_ci.yml)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue?logo=flutter&logoColor=white&color=555)
![Platform](https://img.shields.io/badge/platform-Android%20%7C%20iOS-555)
![Tests](https://img.shields.io/badge/tests-137%20passing-success)

FitPilot is an offline-first calorie tracking application built around a single principle: **honesty over false precision.** Where other apps display "Chicken Biryani — 485 kcal" as if it were a laboratory measurement, FitPilot shows an honest range (480–700 kcal) — and when you exceed your daily target, it converts the surplus into a concrete, personalised burn plan: *walk 25 minutes, or skip rope for 8.*

---

## Table of Contents

- [Philosophy](#philosophy)
- [Features](#features)
- [Architecture](#architecture)
- [Tech Stack](#tech-stack)
- [Getting Started](#getting-started)
- [Testing](#testing)
- [Project Structure](#project-structure)
- [Documentation](#documentation)
- [Roadmap](#roadmap)
- [Author](#author)

---

## Philosophy

Three rules shape every feature in this application:

1. **Honest ranges, never fake precision.** Estimated foods always display a calorie *range*. A single exact number is shown only when the value is genuinely known — from a barcode lookup or a nutrition label scanned by the user.
2. **A surplus is a task, not a failure.** Going over your target does not produce guilt messaging; it produces a burn plan sized to your body weight, with a grace deadline to complete it.
3. **No data, no judgement.** Days you do not log are neutral — they neither extend nor break your streak. The app never fabricates a green day it did not witness.

## Features

### Food logging
- Searchable local food catalog with Urdu aliases, portion labels, and verified entries
- Custom foods and quick manual entry with validation
- **Barcode scanning** backed by the Open Food Facts database (v2 API), with kJ→kcal conversion and explicit provenance
- **Nutrition-label OCR** (on-device ML Kit) with per-field confidence flagging and full user correction before anything is saved

### Daily burn planning
- Surplus converted into equivalent activity minutes using MET-based energy expenditure (kcal/min = MET × 3.5 × kg ÷ 200), personalised to the user's weight
- Multiple activity options (walking always available — no equipment required)
- Grace deadline (next day 11:59 AM) to clear a surplus and protect the streak

### Progress & motivation
- Streak engine with three-state day model: safe, over-unresolved, and **neutral no-log days**
- 35-day calendar heat map, weekly intake/burn summaries, and weight trend tracking
- Local notifications, including streak-protection reminders that name the deadline and the smallest available burn option

### Platform & reliability
- **Offline-first:** every feature that can work without a network, works without a network (SQLite on device)
- **Background sync** to Supabase (PostgreSQL) with a durable sync queue, retry with exponential backoff, and guest-to-account data merge on first sign-in
- Email/password authentication with OTP verification (Supabase Auth); Row Level Security (`auth.uid() = user_id`) on every user table
- Full light & dark themes, responsive from 320 px phones to landscape tablets, system text-scale support (clamped 0.85–1.15)

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

| Milestone | Scope | Status |
| --- | --- | --- |
| **A — Offline core** | Domain engines, local logging, burn plans, streaks | ✅ Complete |
| **B — Connected** | Supabase auth & sync, barcode, label OCR, weight, notifications | ✅ Complete |
| **B.5 — Fix & polish** | Device-verified UX pass, design system enforcement | 🔄 In progress |
| **C — Intelligence** | Server-side AI proxy, photo food estimation, exercise library, weekly planner | ⏳ Planned |
| **D — Advanced** | Machine scanner, AI form check, push notifications, admin dashboard | ⏳ Planned |

## Author

**Muhammad Anees** — BS Software Engineering, COMSATS University Islamabad.

FitPilot is a solo Final Year Project exploring disciplined, AI-assisted software engineering: specification-first development, layered architecture, and human acceptance testing over raw test counts.

---

*This repository currently has no open-source license; all rights reserved. The project is shared publicly for academic evaluation and portfolio purposes.*
