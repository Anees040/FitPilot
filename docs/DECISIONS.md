# DECISIONS — append-only log (one line each, newest last)

Format: `YYYY-MM-DD — decision — why`

- 2026-07-26 — Vertical-slice milestones (A→D), not module-by-module — app stays runnable, integration risk stays low
- 2026-07-26 — Riverpod for state — compile-safe DI, derived providers, easy engine mocking
- 2026-07-26 — go_router StatefulShellRoute for 5-tab shell — preserves per-tab state
- 2026-07-26 — KcalRange value object everywhere — honest ranges are the product's core promise
- 2026-07-26 — Light theme only, single accent #D9531E — design system frozen with mockups
- 2026-07-26 — Milestone A is 100% offline (SQLite + bundled seed) — core UX must not depend on network
- 2026-07-26 — Engines take `now` as parameter — deterministic unit tests
- 2026-07-26 — Downgraded Riverpod to 2.5.1 — avoided unstable APIs in 3.0 migration
- 2026-07-26 — Used profile table query for first-launch routing check — avoids SharedPreferences dependency
- 2026-07-27 — Used `queued_at` overwrite in `sync_queue` to implement exponential backoff rather than altering DDL to add a `next_retry_at` column.
- 2026-07-27 — Barcode-before-OCR ordering: The default Capture screen mode is Barcode, requiring users to explicitly switch to OCR, steering them toward the higher-confidence API lookup path.
- 2026-07-27 — 5% Kcal range spread: When logging from barcode/OCR, an exact value is computed but logged as a range ±5% to reflect declaration tolerance.
- 2026-07-27 — Barcode caching: Open Food Facts results are cached into `food_catalog` with `is_verified = 0`, and user-defined portions for weightless OFF products are saved to a new `saved_products` table to work fully offline.
- 2026-07-29 — Neutral days (noData): Days with no logs and no burn plan completions are now assigned `DayState.noData` to pause streaks cleanly rather than breaking them.
- 2026-07-29 — SQLite for theme_mode: Persisted ThemeMode setting in `profile` table to avoid introducing a `shared_preferences` dependency.
- 2026-07-29 — Global TextScaler: Clamped typography scaling between 0.85 and 1.15 in `main.dart` to prevent system accessibility settings from destroying layout.
