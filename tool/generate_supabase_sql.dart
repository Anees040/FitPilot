// Generates the Supabase DDL from lib/data/sync/sync_tables.dart.
//
// Run:  dart run tool/generate_supabase_sql.dart > docs/supabase_migration.sql
//
// The point is that the schema is derived, not transcribed. Hand-written SQL
// drifted from the app's real needs for months — the push kept trying to
// upload columns Postgres did not have, PostgREST rejected the whole row, and
// the failure was invisible because the queue just retried forever.
import 'package:fitpilot/data/sync/sync_tables.dart';

/// Repairs columns that already exist with the wrong type.
///
/// ADD COLUMN IF NOT EXISTS is a no-op when the column is present, so it
/// cannot fix a type mismatch — and the very first schema shipped
/// `food_logs.food_id` as `bigint references foods(id)` while the app sends
/// catalog ids like 'biryani-chicken-1'. Every food-log push was rejected by
/// Postgres, silently, for as long as that mismatch stood. An ALTER TYPE
/// repairs it in place, which is the non-destructive answer to the DROP TABLE
/// the earlier hand-written migration reached for.
String _coerceTypes(SyncTableSpec spec) {
  final t = spec.remote;

  // Arrays are handled separately, below. Keeping them out of the loop means
  // the loop's format() string contains no quoted literals at all, which is
  // what keeps its escaping readable and correct.
  final scalar = [
    for (final c in spec.columns)
      if (c.pgType != 'text[]') "    ('${c.name}', '${c.pgType}')",
    // Legacy scripts created this as `text NOT NULL DEFAULT now()::text`.
    // Postgres renders that as '2026-08-11 14:23:45+00' — a space, not a 'T'.
    // The pull compares with .gt(), which on a text column is a string
    // comparison, and ' ' sorts before 'T': rows would be skipped by the very
    // cursor meant to find them. As timestamptz the comparison is temporal.
    "    ('updated_at', 'timestamp with time zone')",
  ].join(',\n');

  final buffer = StringBuffer('''
-- Coerce legacy column types in place (data is preserved).
DO \$do\$
DECLARE
  want record;
  have text;
BEGIN
  FOR want IN SELECT * FROM (VALUES
$scalar
  ) AS t(col, typ) LOOP
    SELECT format_type(a.atttypid, a.atttypmod) INTO have
    FROM pg_attribute a
    WHERE a.attrelid = '$t'::regclass
      AND a.attname = want.col AND a.attnum > 0 AND NOT a.attisdropped;
    CONTINUE WHEN have IS NULL OR have = want.typ;
    BEGIN
      EXECUTE format(
        'ALTER TABLE $t ALTER COLUMN %I TYPE %s USING %I::text::%s',
        want.col, want.typ, want.col, want.typ);
      RAISE NOTICE '$t.%: % -> %', want.col, have, want.typ;
    EXCEPTION WHEN others THEN
      -- Reported, not fatal. One stubborn column must not abort the migration
      -- for every table after it.
      RAISE WARNING '$t.% could not become % (currently %): %',
        want.col, want.typ, have, SQLERRM;
    END;
  END LOOP;
END \$do\$;
''');

  // A JSON string has to be unpacked into an array, not cast to one, so these
  // get literal DDL rather than a format() template.
  for (final c in spec.columns.where((c) => c.pgType == 'text[]')) {
    buffer.write('''
DO \$do\$
DECLARE have text;
BEGIN
  SELECT format_type(a.atttypid, a.atttypmod) INTO have
  FROM pg_attribute a
  WHERE a.attrelid = '$t'::regclass AND a.attname = '${c.name}'
    AND a.attnum > 0 AND NOT a.attisdropped;
  IF have IS NOT NULL AND have <> 'text[]' THEN
    ALTER TABLE $t ALTER COLUMN ${c.name} TYPE text[]
      USING CASE
        WHEN ${c.name} IS NULL
          OR btrim(${c.name}::text) IN ('', '[]') THEN '{}'::text[]
        ELSE translate(${c.name}::text, '[]"', '')::text[]
      END;
    RAISE NOTICE '$t.${c.name}: % -> text[]', have;
  END IF;
END \$do\$;
''');
  }

  return buffer.toString();
}

/// Removes foreign keys that force an insert order the sync cannot honour.
///
/// The original schema pointed every table at `profiles(id)`, so a food log
/// could not be inserted before its profile row existed. The push uploads
/// tables in queue order, not dependency order, so that constraint turns a
/// perfectly valid batch into a rejected one. The `auth.users` reference is
/// kept — that is what makes account deletion cascade.
String _dropLegacyForeignKeys(String t) => '''
-- Drop legacy FKs that impose an insert order the sync cannot guarantee.
DO \$do\$
DECLARE fk record;
BEGIN
  FOR fk IN
    SELECT conname, confrelid::regclass::text AS target
    FROM pg_constraint
    WHERE conrelid = '$t'::regclass AND contype = 'f'
  LOOP
    CONTINUE WHEN fk.target IN ('users', 'auth.users');
    EXECUTE format('ALTER TABLE $t DROP CONSTRAINT %I', fk.conname);
    RAISE NOTICE '$t: dropped FK % -> %', fk.conname, fk.target;
  END LOOP;
END \$do\$;
''';

/// Reads the live schema back and reports anything that does not match the
/// registry.
///
/// The migration reports failed casts with RAISE WARNING, and the Supabase SQL
/// Editor does not display those — so a column that refused to convert looks
/// exactly like one that converted fine. This turns that difference into rows:
/// a healthy database returns none.
String _verifyScript() {
  final expected = <String>[];
  for (final spec in kSyncTables) {
    for (final c in spec.columns) {
      expected.add("  ('${spec.remote}', '${c.name}', '${c.pgType}')");
    }
    expected.add("  ('${spec.remote}', 'user_id', 'uuid')");
    expected.add("  ('${spec.remote}', 'deleted', 'boolean')");
    expected.add(
      "  ('${spec.remote}', 'updated_at', 'timestamp with time zone')",
    );
  }

  return '''
-- FitPilot — schema drift report
-- GENERATED by: dart run tool/generate_supabase_sql.dart --verify
--
-- Every row is a problem. No rows means the schema matches what the app
-- pushes. Run this after supabase_migration.sql: the migration downgrades a
-- failed column cast to a warning so one bad column cannot abort the rest,
-- and the SQL Editor does not show warnings.
WITH expected(tbl, col, typ) AS (VALUES
${expected.join(',\n')}
),
actual AS (
  SELECT
    table_name,
    column_name,
    -- information_schema reports arrays as 'ARRAY' with the element type in
    -- udt_name ('_text'), which would never match the 'text[]' the registry
    -- declares. Normalise it back to the form the app thinks in.
    CASE
      WHEN data_type = 'ARRAY'
        THEN replace(udt_name, '_', '') || '[]'
      ELSE data_type
    END AS typ
  FROM information_schema.columns
  WHERE table_schema = 'public'
)
SELECT
  e.tbl        AS table_name,
  e.col        AS column_name,
  e.typ        AS expected_type,
  COALESCE(a.typ, '** MISSING **') AS actual_type
FROM expected e
LEFT JOIN actual a ON a.table_name = e.tbl AND a.column_name = e.col
WHERE a.typ IS DISTINCT FROM e.typ
ORDER BY e.tbl, e.col;
''';
}

void main(List<String> args) {
  // The migration reports cast failures with RAISE WARNING, which the Supabase
  // SQL Editor does not surface. `--verify` emits a query that reads the live
  // schema back and reports drift as rows, so a silent failure becomes visible.
  if (args.contains('--verify')) {
    // ignore: avoid_print
    print(_verifyScript());
    return;
  }

  final b = StringBuffer();

  b.writeln('-- FitPilot — Supabase schema');
  b.writeln('-- GENERATED by tool/generate_supabase_sql.dart. Do not hand-edit:');
  b.writeln('-- regenerate after changing lib/data/sync/sync_tables.dart.');
  b.writeln('--');
  b.writeln('-- Safe to re-run. Creates what is missing, adds columns that are');
  b.writeln('-- absent, and never drops a table or a column that holds data.');
  b.writeln();

  for (final spec in kSyncTables) {
    final t = spec.remote;
    final rule = '-- ${'=' * 66}';
    b.writeln(rule);
    b.writeln('-- $t');
    b.writeln(rule);
    b.writeln();

    // CREATE with only the structural columns, then ALTER the rest in. That
    // way a table that already exists (with an older shape) is upgraded by the
    // same script that creates a new one — no DROP, no data loss.
    b.writeln('CREATE TABLE IF NOT EXISTS $t (');
    if (spec.singleton) {
      // One row per account, so the user's uuid IS the primary key.
      b.writeln('  id uuid PRIMARY KEY REFERENCES auth.users ON DELETE CASCADE,');
      b.writeln('  user_id uuid,');
    } else {
      b.writeln('  id text PRIMARY KEY,');
      b.writeln(
        '  user_id uuid NOT NULL REFERENCES auth.users ON DELETE CASCADE,',
      );
    }
    b.writeln('  updated_at timestamptz NOT NULL DEFAULT now()');
    b.writeln(');');
    b.writeln();

    // Columns, each guarded so re-running is a no-op.
    b.writeln('DO \$\$ BEGIN');
    for (final c in spec.columns) {
      b.writeln(
        '  BEGIN ALTER TABLE $t ADD COLUMN ${c.name} ${c.pgType}; '
        'EXCEPTION WHEN duplicate_column THEN NULL; END;',
      );
    }
    // `deleted` is how a push tombstones a row. The pull reads it to delete
    // locally, so every synced table needs it even though no spec lists it.
    b.writeln(
      '  BEGIN ALTER TABLE $t ADD COLUMN deleted boolean NOT NULL DEFAULT false; '
      'EXCEPTION WHEN duplicate_column THEN NULL; END;',
    );
    // user_id and updated_at come from the CREATE above — but only when this
    // run actually created the table. A table left over from an older schema
    // skips the CREATE entirely (IF NOT EXISTS), so these have to be added
    // here too. Without it the index below fails with 42703: column
    // "user_id" does not exist, which is exactly what happened on the first
    // attempt at this migration.
    b.writeln(
      '  BEGIN ALTER TABLE $t ADD COLUMN user_id uuid; '
      'EXCEPTION WHEN duplicate_column THEN NULL; END;',
    );
    b.writeln(
      '  BEGIN ALTER TABLE $t ADD COLUMN updated_at timestamptz '
      'NOT NULL DEFAULT now(); '
      'EXCEPTION WHEN duplicate_column THEN NULL; END;',
    );
    b.writeln('END \$\$;');
    b.writeln();

    // Backfill user_id on rows that predate the column, then make it usable.
    // A legacy row with a NULL owner is invisible under RLS, so it would look
    // like the user's data had vanished.
    if (spec.singleton) {
      b.writeln('-- A singleton row is keyed by the owner, so id IS user_id.');
      b.writeln('UPDATE $t SET user_id = id WHERE user_id IS NULL;');
      b.writeln();
    }

    b.writeln(_coerceTypes(spec));
    b.writeln(_dropLegacyForeignKeys(t));

    // The app writes rows during onboarding with most fields still empty, so
    // any legacy NOT NULL has to come off or the upsert is rejected.
    b.writeln('-- Drop legacy NOT NULLs: the app saves partial rows during');
    b.writeln('-- onboarding and would otherwise be rejected.');
    b.writeln('DO \$\$');
    b.writeln('DECLARE col record;');
    b.writeln('BEGIN');
    b.writeln('  FOR col IN');
    b.writeln('    SELECT column_name FROM information_schema.columns');
    b.writeln("    WHERE table_schema = 'public' AND table_name = '$t'");
    b.writeln("      AND is_nullable = 'NO'");
    b.writeln("      AND column_name NOT IN ('id', 'user_id', 'updated_at', 'deleted')");
    b.writeln('  LOOP');
    b.writeln(
      '    EXECUTE format(\'ALTER TABLE $t ALTER COLUMN %I DROP NOT NULL\', col.column_name);',
    );
    b.writeln('  END LOOP;');
    b.writeln('END \$\$;');
    b.writeln();

    if (!spec.singleton) {
      b.writeln(
        'CREATE INDEX IF NOT EXISTS idx_${t}_user ON $t (user_id);',
      );
    }
    b.writeln(
      'CREATE INDEX IF NOT EXISTS idx_${t}_updated ON $t (updated_at);',
    );

    // weight_entries upserts on (user_id, for_date): one weigh-in per day.
    if (spec.local == 'weight_entries') {
      b.writeln();
      b.writeln('-- The push upserts on this pair, so it must be unique.');
      b.writeln('DO \$\$ BEGIN');
      b.writeln('  ALTER TABLE $t ADD CONSTRAINT ${t}_user_date_key');
      b.writeln('    UNIQUE (user_id, for_date);');
      b.writeln('EXCEPTION WHEN duplicate_table OR duplicate_object THEN NULL; END \$\$;');
    }
    b.writeln();

    // RLS. Without it every user reads every other user's rows.
    b.writeln('ALTER TABLE $t ENABLE ROW LEVEL SECURITY;');
    final ownCol = spec.singleton ? 'id' : 'user_id';
    b.writeln('DROP POLICY IF EXISTS "own_$t" ON $t;');
    b.writeln('CREATE POLICY "own_$t" ON $t');
    b.writeln('  FOR ALL USING (auth.uid() = $ownCol)');
    b.writeln('  WITH CHECK (auth.uid() = $ownCol);');
    b.writeln();
  }

  // Verification.
  final rule = '-- ${'=' * 66}';
  b.writeln(rule);
  b.writeln('-- Verify: every synced table should appear, with rls_enabled = true.');
  b.writeln(rule);
  b.writeln('SELECT c.relname AS table_name, c.relrowsecurity AS rls_enabled');
  b.writeln('FROM pg_class c JOIN pg_namespace n ON n.oid = c.relnamespace');
  b.writeln("WHERE n.nspname = 'public' AND c.relname IN (");
  b.writeln(kSyncTables.map((s) => "  '${s.remote}'").join(',\n'));
  b.writeln(') ORDER BY c.relname;');

  // ignore: avoid_print
  print(b.toString());
}
