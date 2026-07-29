# FitPilot

**Eat it. Burn it.**

FitPilot is an honest calorie tracking app that shows honest calorie RANGES (never fake exact numbers) and converts overeating into concrete burn plans (walk X min, rope Y min). Built for physical honesty and behavioral change.

## Features

- **Kcal Ranges**: Honesty over precision. If you don't know exactly what you ate, the app provides a range rather than a single fake number.
- **Burn Plans**: When you go over your calorie limit, FitPilot translates the excess into concrete exercises to balance the scales.
- **Offline First**: fully functional without a persistent internet connection (Milestone A).
- **Streak System**: Days you log under or near your allowance build your streak. Overeating without burning it off breaks it.

## Stack
- Flutter/Dart 3.x
- Riverpod 2.x
- go_router
- SQLite

## Current Status
- **Milestone A**: 100% offline functionality. No backend code, no Supabase package, no HTTP calls.

## Documentation
- Read `docs/STATUS.md` for the current active phase.
- Read `docs/DOMAIN_RULES.md` for calorie calculation and streak rules.
- Read `docs/DESIGN_SYSTEM.md` and `docs/UI_SPEC.md` for the presentation architecture.
