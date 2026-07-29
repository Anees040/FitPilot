# FitPilot — Database Design & Setup

> Version 1.0 — July 2026 · Postgres (Supabase) + Drift (on-device mirror of `foods`, `met_activities`, plus offline queue)

## 1. Schema (run in Supabase SQL Editor)
```sql
-- PROFILES (1:1 with auth.users)
create table profiles (
  id uuid primary key references auth.users on delete cascade,
  weight_kg numeric(5,2) not null check (weight_kg between 25 and 300),
  height_cm numeric(5,1) check (height_cm between 100 and 250),
  sex text check (sex in ('male','female','other')),
  birth_year int,
  activity_level text default 'moderate',
  equipment text[] default '{}',
  goal text default 'maintain',
  created_at timestamptz default now()
);

-- FOODS (curated; synced read-only to app)
create table foods (
  id bigint generated always as identity primary key,
  name text not null,
  name_roman_urdu text,
  aliases text[] default '{}',
  kcal_min int not null,
  kcal_max int not null check (kcal_max >= kcal_min),
  portion_desc text not null,      -- '1 medium roti', '1 plate (350g)'
  portion_grams int,
  is_desi boolean default true,
  source text                       -- 'USDA', 'label', 'manual-verified'
);
create index foods_aliases_gin on foods using gin (aliases);

-- FOOD LOGS
create table food_logs (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  food_id bigint references foods(id),
  raw_input text,
  input_mode text not null check (input_mode in ('label','text','photo','voice')),
  kcal_min int not null,
  kcal_max int not null,
  confidence text not null check (confidence in ('high','medium','low')),
  follow_up_answered boolean default false,
  logged_at timestamptz not null default now()
);
create index food_logs_user_time on food_logs (user_id, logged_at desc);

-- BURN PLANS
create table burn_plans (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references profiles(id) on delete cascade,
  food_log_id uuid references food_logs(id) on delete cascade,
  options jsonb not null,           -- [{activity, met, minutes}]
  chosen_activity text,
  completed_pct int default 0 check (completed_pct between 0 and 100),
  completed_at timestamptz
);
create index burn_plans_user on burn_plans (user_id);

-- STREAKS
create table streaks (
  user_id uuid primary key references profiles(id) on delete cascade,
  current_streak int default 0,
  longest_streak int default 0,
  last_safe_day date
);

-- MET ACTIVITIES (reference data)
create table met_activities (
  id serial primary key,
  name text not null,
  met numeric(4,1) not null,
  equipment_required text          -- null = none
);
insert into met_activities (name, met, equipment_required) values
 ('Walking (brisk)', 4.3, null), ('Running (8 km/h)', 8.3, null),
 ('Jumping rope', 11.0, 'rope'), ('Cycling (moderate)', 7.5, 'cycle'),
 ('HIIT circuit', 8.0, null), ('Stair climbing', 4.0, null),
 ('Weight training (vigorous)', 6.0, 'gym'), ('Swimming (moderate)', 5.8, 'pool');

-- AI USAGE QUOTA
create table ai_usage (
  user_id uuid references profiles(id) on delete cascade,
  day date not null,
  photo_calls int default 0,
  primary key (user_id, day)
);
```

## 2. Row-Level Security (MANDATORY before first beta user)
```sql
alter table profiles enable row level security;
alter table food_logs enable row level security;
alter table burn_plans enable row level security;
alter table streaks enable row level security;
alter table ai_usage enable row level security;
alter table foods enable row level security;
alter table met_activities enable row level security;

create policy "own profile" on profiles for all using (auth.uid() = id);
create policy "own logs" on food_logs for all using (auth.uid() = user_id);
create policy "own plans" on burn_plans for all using (auth.uid() = user_id);
create policy "own streak" on streaks for all using (auth.uid() = user_id);
create policy "own usage read" on ai_usage for select using (auth.uid() = user_id);
create policy "foods readable" on foods for select using (true);
create policy "met readable" on met_activities for select using (true);
```
`ai_usage` writes happen only from the server using the service-role key (bypasses RLS — never put that key in the app).

## 3. Burn math (the deterministic core)
`kcal_per_min = MET × 3.5 × weight_kg / 200` → `minutes = ceil(kcal / kcal_per_min)`
Worked example (70 kg, 700 kcal pizza): cycling 7.5 MET → 9.19 kcal/min → **77 min**; HIIT 8.0 → **72 min**; brisk walk 4.3 → **149 min** (~ steps estimate: 149 × 100 steps/min ≈ 15k steps). These are the unit-test fixtures.

## 4. Supabase setup — step by step
1. supabase.com → New project → name `fitpilot`, region **Singapore** (lowest latency from PK), generate strong DB password (save in a password manager, never in repo).
2. SQL Editor → paste §1 then §2 → Run. Verify tables in Table Editor.
3. Authentication → Providers → enable Email; enable Google (create OAuth client in Google Cloud console; add the Android SHA-1 from `./gradlew signingReport`).
4. Settings → API: copy `Project URL` + `anon` key → these two go in the Flutter app via `--dart-define` (they are safe to ship; RLS is the real gate). Copy `service_role` key → Render env var ONLY.
5. Seed foods: prepare `foods_seed.csv` (50 items — you verify every kcal range yourself against packaging/USDA), import via Table Editor → Import CSV.
6. Keep-alive: GitHub Action weekly cron runs `select 1` via Supabase REST to prevent free-tier pause.

## 5. On-device (Drift) tables
Mirror of `foods` + `met_activities` (bundled JSON seed, refreshed from Supabase on app start when online) + `pending_ops` sync queue (op type, payload, created_at, retry_count) + local cache of last 30 days of logs.
