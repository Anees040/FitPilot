# DECISIONS — append-only log (one line each, newest last)

Format: `YYYY-MM-DD — decision — why`

- 2026-07-26 — Vertical-slice milestones (A→D), not module-by-module — app stays runnable, integration risk stays low
- 2026-07-26 — Riverpod for state — compile-safe DI, derived providers, easy engine mocking
- 2026-07-26 — go_router StatefulShellRoute for 5-tab shell — preserves per-tab state
- 2026-07-26 — KcalRange value object everywhere — honest ranges are the product's core promise
- 2026-07-26 — Light theme only, single accent #D9531E — design system frozen with mockups
- 2026-07-26 — Milestone A is 100% offline (SQLite + bundled seed) — core UX must not depend on network
- 2026-07-26 — Engines take `now` as parameter — deterministic unit tests
