/// The one place that says what syncs and how.
///
/// Push, pull, and the Supabase DDL in `docs/04_Database.md` are all derived
/// from this list, so a table cannot be half-wired the way it used to be: for
/// months `program_completions` and `notification_prefs` were written locally
/// and never uploaded, which is why starting a program and then signing out
/// lost it. Adding a table here is the whole job now.
library;

/// How a column crosses the wire.
enum SyncColumnKind {
  /// Passes through untouched (TEXT/INTEGER/REAL both sides).
  plain,

  /// SQLite stores 0/1, Postgres stores boolean. Coerced in both directions.
  boolean,

  /// A JSON array or object kept as TEXT on both sides. Postgres would happily
  /// accept jsonb, but TEXT means SQLite's stored string round-trips byte for
  /// byte instead of coming back re-serialised with different key order.
  json,
}

class SyncColumn {
  final String name;
  final SyncColumnKind kind;

  /// Postgres type used when generating DDL.
  final String pgType;

  const SyncColumn(this.name, {this.kind = SyncColumnKind.plain, required this.pgType});

  const SyncColumn.text(this.name) : kind = SyncColumnKind.plain, pgType = 'text';
  const SyncColumn.int(this.name) : kind = SyncColumnKind.plain, pgType = 'integer';
  const SyncColumn.real(this.name) : kind = SyncColumnKind.plain, pgType = 'real';
  const SyncColumn.bool(this.name) : kind = SyncColumnKind.boolean, pgType = 'boolean';
  const SyncColumn.json(this.name) : kind = SyncColumnKind.json, pgType = 'text';
}

class SyncTableSpec {
  /// SQLite table name.
  final String local;

  /// Supabase table name. Differs only where history left it differing.
  final String remote;

  /// Primary-key column in SQLite. Not always `id`: program progress is keyed
  /// by `session_id`, saved barcodes by `barcode`.
  final String localPk;

  /// True for the one-row-per-device tables (`profile`, `notification_prefs`).
  /// Locally the row is always `id = 1`; remotely its primary key is the user's
  /// uuid, because in the cloud "the profile" only means anything per account.
  final bool singleton;

  /// Columns that exist on both sides, excluding the primary key, `user_id`,
  /// and `updated_at` — those three are handled structurally.
  final List<SyncColumn> columns;

  /// Local columns deliberately absent from the cloud. A pull preserves the
  /// device's existing values for these instead of nulling them.
  final List<String> localOnly;

  const SyncTableSpec({
    required this.local,
    required this.columns,
    String? remote,
    this.localPk = 'id',
    this.singleton = false,
    this.localOnly = const [],
  }) : remote = remote ?? local;

  Iterable<String> get columnNames => columns.map((c) => c.name);

  SyncColumn? column(String name) {
    for (final c in columns) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// Every table whose rows belong to a user and therefore follow the account.
///
/// Deliberately absent: `exercises`, `programs`, `program_sessions`,
/// `program_session_items` (bundled seed content, identical for everyone, so
/// uploading a copy per account would be pure waste) and `sync_queue` /
/// `sync_metadata` (the sync machinery itself). Form check is absent because it
/// persists nothing — it is a live analysis call with no table behind it.
const List<SyncTableSpec> kSyncTables = [
  SyncTableSpec(
    local: 'profile',
    remote: 'profiles',
    singleton: true,
    // protein_goal_g and image_key have no cloud column yet; a pull must leave
    // whatever the device already had rather than wiping it.
    localOnly: ['protein_goal_g'],
    columns: [
      SyncColumn.text('name'),
      SyncColumn.text('avatar_url'),
      SyncColumn.real('weight_kg'),
      SyncColumn.real('goal_weight_kg'),
      SyncColumn.real('height_cm'),
      SyncColumn.int('age'),
      SyncColumn.text('gender'),
      SyncColumn.text('goal'),
      SyncColumn.text('activity_level'),
      SyncColumn.int('allowance_kcal'),
      SyncColumn.int('target_override'),
      // text[] in Postgres, not text: _fixProfileArrayFields decodes the
      // SQLite JSON string into a Dart List before the push, and PostgREST
      // will not put a list into a text column.
      SyncColumn('equipment', kind: SyncColumnKind.json, pgType: 'text[]'),
      SyncColumn.text('theme_mode'),
      SyncColumn.text('theme_color'),
      SyncColumn.text('plan_category_pref'),
      SyncColumn.text('plan_pace_pref'),
      SyncColumn.text('unit_kg_lb'),
      SyncColumn.bool('week_starts_mon'),
      SyncColumn.bool('haptics_on'),
      // The four that used to be stripped from the push. Without them the
      // cloud profile could never say which program was running or whether
      // onboarding had been done, so every sign-in looked like a fresh install.
      SyncColumn.text('active_program_id'),
      SyncColumn.int('active_program_week'),
      SyncColumn.int('active_program_day'),
      SyncColumn.bool('onboarding_complete'),
    ],
  ),
  SyncTableSpec(
    local: 'food_logs',
    localOnly: ['photo_path', 'protein_g'],
    columns: [
      SyncColumn.text('food_id'),
      SyncColumn.text('food_name'),
      SyncColumn.text('custom_name'),
      SyncColumn.real('quantity'),
      SyncColumn.int('kcal_min'),
      SyncColumn.int('kcal_max'),
      SyncColumn.text('source'),
      SyncColumn.text('logged_at'),
      SyncColumn.text('deleted_at'),
    ],
  ),
  SyncTableSpec(
    local: 'burn_completions',
    columns: [
      SyncColumn.text('for_date'),
      SyncColumn.text('activity'),
      SyncColumn.int('minutes'),
      SyncColumn.int('kcal'),
      SyncColumn.text('completed_at'),
    ],
  ),
  SyncTableSpec(
    local: 'weight_entries',
    columns: [
      SyncColumn.text('for_date'),
      SyncColumn.real('weight_kg'),
    ],
  ),
  SyncTableSpec(
    local: 'food_catalog',
    localOnly: ['image_key', 'protein_g'],
    columns: [
      SyncColumn.text('name'),
      SyncColumn.text('name_ur'),
      SyncColumn.text('portion_label'),
      SyncColumn.int('grams'),
      SyncColumn.int('kcal_min'),
      SyncColumn.int('kcal_max'),
      SyncColumn.text('image_url'),
      SyncColumn.bool('is_verified'),
    ],
  ),

  // ── Tables that used to be local-only ────────────────────────────────────
  // Each was marked "per-device" in the schema, which in practice meant the
  // user lost it on sign-out. A phone is not an account: the account is what
  // the user believes owns their program, their coach threads and their
  // settings, so all of it follows them now.

  /// Program progress. Keyed by `session_id`, not `id`.
  SyncTableSpec(
    local: 'program_completions',
    localPk: 'session_id',
    columns: [
      SyncColumn.text('program_id'),
      SyncColumn.int('week_number'),
      SyncColumn.int('day_number'),
      SyncColumn.int('kcal'),
      SyncColumn.text('completed_at'),
    ],
  ),

  /// Notification settings — one row per account, like the profile.
  SyncTableSpec(
    local: 'notification_prefs',
    singleton: true,
    columns: [
      SyncColumn.bool('meal_reminders_enabled'),
      SyncColumn.json('meal_times'),
      SyncColumn.bool('streak_risk_enabled'),
      SyncColumn.bool('milestones_enabled'),
      SyncColumn.bool('global_mute'),
      SyncColumn.bool('burn_reminders_enabled'),
      SyncColumn.bool('program_reminders_enabled'),
      SyncColumn.bool('weigh_in_enabled'),
      SyncColumn.int('weigh_in_day'),
      SyncColumn.text('weigh_in_time'),
      SyncColumn.bool('water_reminders_enabled'),
      SyncColumn.bool('quiet_hours_enabled'),
      SyncColumn.text('quiet_from'),
      SyncColumn.text('quiet_to'),
    ],
  ),

  /// AI Coach threads and their messages.
  SyncTableSpec(
    local: 'chat_conversations',
    columns: [
      SyncColumn.text('title'),
      SyncColumn.text('created_at'),
    ],
  ),
  SyncTableSpec(
    local: 'chat_messages',
    columns: [
      SyncColumn.text('conversation_id'),
      SyncColumn.text('role'),
      SyncColumn.text('content'),
      SyncColumn.text('created_at'),
    ],
  ),

  /// Gym machine scanner history. `response_json` is the cached AI answer, so
  /// a scan stays readable on a new device without paying for it again.
  SyncTableSpec(
    local: 'machine_scans',
    columns: [
      SyncColumn.text('machine_name'),
      SyncColumn.json('response_json'),
      SyncColumn.text('created_at'),
    ],
  ),

  /// The in-app notification inbox, including which items were read.
  SyncTableSpec(
    local: 'notifications',
    columns: [
      SyncColumn.text('category'),
      SyncColumn.text('title'),
      SyncColumn.text('body'),
      SyncColumn.json('payload'),
      SyncColumn.text('created_at'),
      SyncColumn.text('read_at'),
    ],
  ),

  /// Barcodes the user taught the app, keyed by `barcode`.
  SyncTableSpec(
    local: 'saved_products',
    localPk: 'barcode',
    columns: [
      SyncColumn.real('quantity'),
    ],
  ),
];
