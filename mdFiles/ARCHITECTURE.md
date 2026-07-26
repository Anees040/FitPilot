# ARCHITECTURE — where code lives and what may import what

## Layers (dependency arrows point DOWN only)

| Layer | Path | Contains | May import |
| --- | --- | --- | --- |
| Presentation | `lib/features/<feature>/` | screens, widgets | Application, Domain |
| Application | `lib/features/<feature>/providers/` | Riverpod providers/controllers | Domain, Data (interfaces) |
| Domain | `lib/domain/` | entities, engines (pure Dart) | NOTHING (no Flutter, no IO) |
| Data | `lib/data/` | repositories, SQLite datasource, seed loader | Domain |
| Core | `lib/core/` | theme, router, constants, utils | — |

Screens NEVER touch the database or repositories directly — always through providers.

## Folder map

```
lib/
  core/        theme/, router/, constants/
  domain/      entities/ (KcalRange, FoodItem, FoodLog, Profile, BurnOption,
               DayStatus, StreakState)
               engines/  (RangeCalculator, BurnPlanner, StreakEngine,
               QuotaPolicy, LabelParser)
  data/        local/ (sqlite datasource, seed import), repositories/
  features/    today/, log/, plan/, progress/, profile/
test/          mirrors lib/ structure
assets/        seed/foods.json, seed/exercises.json, icon/
```

## Key design facts

- Offline-first: every write hits local SQLite first. (Sync/auth arrive in
  Milestone B — do not scaffold them early.)
- Derived state (day totals, streaks) is RECOMPUTED by pure engines via
  derived providers — never stored, so it can never disagree with the data.
- IDs are client-generated UUIDs (safe for later sync).
- Engines get `DateTime now` as a PARAMETER (testability); never call
  DateTime.now() inside domain code.
