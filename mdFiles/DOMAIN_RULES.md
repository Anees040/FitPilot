# DOMAIN RULES — business logic the code must implement exactly

## KcalRange

- Immutable `min`/`max` ints, invariant `0 <= min <= max`.
- Logging requires a custom name OR a valid food catalog ID.
- Exact quantities (like 250g) are always stored in the log as `quantity = 1` and the pre-computed total is mapped into a `KcalRange`.
- **Scanner/OCR Rule**: When extracting a point-value energy reading from Open Food Facts or an OCR label, the app applies a **±5% spread** around the computed value to form the `KcalRange`. This reflects standard legal declaration tolerances on packaged nutrition facts.
- **Basis Conversions**: Energy provided only in kilojoules (kJ) is converted to kilocalories (kcal) by dividing by 4.184.
- `plus(other)` adds both ends; `times(qty)` scales both; `midpoint` = (min+max)/2.
- Day total = sum of all log ranges − burn credits (subtract from BOTH ends,
  clamp at 0). Status compares MIDPOINT to allowance, UI shows full range.

## Allowance

- `allowance_kcal`: daily cheat allowance, default 300, valid 0–2000.
- Status: under (midpoint ≤ allowance), near (> 80% of allowance), over.

## Burn planning (MET)

- kcal/min = MET × 3.5 × weight_kg ÷ 200
- minutes = kcalOver × 200 ÷ (MET × 3.5 × weight_kg), round UP to 5-min steps.
- METs: walking 3.5 · jump rope 11 · running 9.8 · cycling 7.5 · burpees 8.
- Output ≤ 4 options sorted by minutes ascending; walking ALWAYS included,
  with steps ≈ minutes × 100, rounded to nearest 500.
- Filter by user's owned equipment (walking needs none).

## Streaks (state machine — pure function of logs, burns, allowance, now)

- NEUTRAL: no logs today yet.
- SAFE: day ended within allowance.
- OVER_PENDING: over allowance; grace deadline = next day 11:59 AM local.
- CLEARED: enough burn completed inside grace → streak preserved.
- BROKEN: grace expired without enough burn.
- Streak count = consecutive SAFE/CLEARED days ending today/yesterday.

## AI photo quota (Milestone C — for reference only)

- 3 photos/user/day, server-enforced (atomic RPC); client only mirrors count.
- Images ≤ 2 MB. Quota denied → offer text-parse fallback.

## Seed data

- `assets/seed/foods.json`: 50+ desi foods, fields: name, name_ur,
  portion_label, grams?, kcal_min, kcal_max. Imported into SQLite on first run.
- `assets/seed/exercises.json`: 30+ exercises with category, equipment,
  difficulty 1–3, muscles, steps, mistakes, met.
