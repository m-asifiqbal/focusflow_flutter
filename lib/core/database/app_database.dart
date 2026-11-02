/// ============================================================
/// APP DATABASE — Drift (≈ Room) over an encrypted SQLite file
/// ============================================================
///
/// One database holds every module (see tables.dart). It is opened by
/// [EncryptedDatabase] with SQLite3MultipleCiphers + a random 256-bit key from
/// the platform keystore, so the whole file is encrypted at rest (the same
/// rule Fresh LPG follows with SQLCipher). Vault secrets are additionally
/// encrypted per item with the vault key (core/crypto).
///
/// Full-text search: one external-content FTS5 table per module
/// (`notes_fts`, `tasks_fts`, `reminders_fts`, `habits_fts`,
/// `medicines_fts`, `vault_fts`)
/// kept in sync by triggers created in [migration]. Query them with
/// `customSelect` (see features/search). Because the triggers key on rowid,
/// DAOs must write with insert / update / `insertOnConflictUpdate` (UPSERT);
/// `recursive_triggers` is on so even `INSERT OR REPLACE` stays consistent.
///
/// **Android/Kotlin analogy:** `@Database` + FTS4 `@Fts4(contentEntity=…)`.
///
/// **IMPORTANT:** after modifying tables run
///   `dart run build_runner build --delete-conflicting-outputs`
/// and add an `if (from < N)` step below (test/core/database/ has the harness).
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/sync_tombstones.dart';
import 'package:focusflow/core/database/tables.dart';

part 'app_database.g.dart';

@DriftDatabase(
  tables: [
    Notes,
    Tasks,
    Subtasks,
    Reminders,
    Habits,
    HabitLogs,
    Medicines,
    MedicineDoses,
    Prayers,
    PrayerLogs,
    VaultItems,
    VaultHistory,
    GeneratorHistory,
    Folders,
    Tags,
    ItemTags,
    Attachments,
    InboxEntries,
    FocusSessions,
    BackupRecords,
    Tombstones,
  ],
)
class AppDatabase extends _$AppDatabase {
  /// Production: `AppDatabase(EncryptedDatabase.open(...))`.
  /// Tests: `AppDatabase(NativeDatabase.memory())`.
  AppDatabase(super.executor);

  /// v1 — initial schema (all modules + FTS5 search + indexes).
  /// v2 — `tombstones` + delete/insert triggers (sync merge, core/sync).
  /// v3 — `notes.lock_verifier` (a note locked with its own PIN).
  ///
  /// `medicines` + `medicine_doses` (and later `prayers` + `prayer_logs`)
  /// came *without* a version bump:
  /// they are created on open when missing ([_ensureMedicineSchema],
  /// [_ensurePrayerSchema]), so
  /// backups of this app stay readable by installs that predate them (an
  /// older install skips the tables it doesn't know). Same for
  /// the columns in [addedColumns] ([_ensureAddedColumns]).
  @override
  int get schemaVersion => 3;

  /// Item tables that carry the shared lifecycle columns, by `ItemType.key`.
  static const Map<String, String> itemTables = {
    'note': 'notes',
    'task': 'tasks',
    'reminder': 'reminders',
    'habit': 'habits',
    'medicine': 'medicines',
    'prayer': 'prayers',
    'vault': 'vault_items',
  };

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createSearchIndex();
      await _createIndexes();
      await _createTombstoneTriggers();
      await _createMedicineIndexes();
      await _createPrayerIndexes();
    },
    onUpgrade: (m, from, to) async {
      // First: the tombstone triggers below include the medicine and prayer
      // tables.
      await m.createTable(medicines);
      await m.createTable(medicineDoses);
      await m.createTable(prayers);
      await m.createTable(prayerLogs);
      if (from < 2) {
        await m.createTable(tombstones);
        await _createTombstoneTriggers();
      }
      if (from < 3) {
        await m.addColumn(notes, notes.lockVerifier);
      }
      await _ensureMedicineSchema(force: true);
      await _ensurePrayerSchema(force: true);
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA recursive_triggers = ON');
      await _ensureQueryIndexes();
      await _ensureMedicineSchema();
      await _ensurePrayerSchema();
      await _ensureAddedColumns();
    },
  );

  /// Columns added after v3 shipped — (table, column, type) — created on
  /// open when missing: the same no-bump rule as the medicine tables, so
  /// backups stay readable by older installs (a restore keeps only the
  /// columns the schema has; a missing one takes its default).
  static const List<(String, String, String)> addedColumns = [
    // An Android alarm's "Auto-snooze after".
    ('reminders', 'auto_snooze_minutes', 'INTEGER NOT NULL DEFAULT 2'),
    // A note's paper (lined / grid).
    ('notes', 'paper', 'TEXT'),
    // A notification-centre row's own destination (digests have no item).
    ('inbox_entries', 'route', 'TEXT'),
    // A prayer's congregation (jamaat) time and its reminder.
    ('prayers', 'jamaat_minutes', 'INTEGER'),
    ('prayers', 'jamaat_after_start', 'INTEGER NOT NULL DEFAULT 0'),
    ('prayers', 'remind_before_jamaat', 'INTEGER'),
    // An estimated (typical) jamaat instead of the mosque's own time.
    ('prayers', 'jamaat_estimated', 'INTEGER NOT NULL DEFAULT 0'),
  ];

  Future<void> _ensureAddedColumns() async {
    final known = <String, Set<String>>{};
    for (final (table, column, type) in addedColumns) {
      final names = known[table] ??= {
        for (final c in await customSelect('PRAGMA table_info($table)').get())
          c.read<String>('name'),
      };
      if (!names.contains(column)) {
        await customStatement('ALTER TABLE $table ADD COLUMN $column $type');
      }
    }
  }

  /// (table, fts table, indexed columns) for every searchable module.
  static const List<(String, String, List<String>)> searchTables = [
    ('notes', 'notes_fts', ['title', 'plain_text']),
    ('tasks', 'tasks_fts', ['title', 'notes']),
    ('reminders', 'reminders_fts', ['title', 'note']),
    ('habits', 'habits_fts', ['name', 'category']),
    ('medicines', 'medicines_fts', ['name', 'strength', 'note']),
    ('prayers', 'prayers_fts', ['name', 'place', 'note']),
    // Vault: plaintext title ONLY — secrets are never indexed.
    ('vault_items', 'vault_fts', ['title']),
  ];

  Future<void> _createSearchIndex() async {
    for (final (table, fts, cols) in searchTables) {
      final colList = cols.join(', ');
      final newVals = cols.map((c) => 'new.$c').join(', ');
      final oldVals = cols.map((c) => 'old.$c').join(', ');
      await customStatement(
        "CREATE VIRTUAL TABLE IF NOT EXISTS $fts USING fts5($colList, "
        "content='$table', content_rowid='rowid', "
        "tokenize='unicode61 remove_diacritics 2', prefix='2 3')",
      );
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS ${fts}_ai AFTER INSERT ON $table BEGIN '
        'INSERT INTO $fts(rowid, $colList) VALUES (new.rowid, $newVals); END',
      );
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS ${fts}_ad AFTER DELETE ON $table BEGIN '
        "INSERT INTO $fts($fts, rowid, $colList) VALUES ('delete', old.rowid, $oldVals); END",
      );
      await customStatement(
        'CREATE TRIGGER IF NOT EXISTS ${fts}_au AFTER UPDATE ON $table BEGIN '
        "INSERT INTO $fts($fts, rowid, $colList) VALUES ('delete', old.rowid, $oldVals); "
        'INSERT INTO $fts(rowid, $colList) VALUES (new.rowid, $newVals); END',
      );
    }
  }

  /// Rebuilds every FTS index from its content table (after a restore).
  Future<void> rebuildSearchIndex() async {
    for (final (_, fts, _) in searchTables) {
      await customStatement("INSERT INTO $fts($fts) VALUES ('rebuild')");
    }
  }

  /// Hard deletes → `tombstones` (see sync_tombstones.dart).
  Future<void> _createTombstoneTriggers() async {
    for (final statement in tombstoneTriggerStatements()) {
      await customStatement(statement);
    }
  }

  /// Indexes added after v2 shipped. `IF NOT EXISTS` on every open (a no-op
  /// once they exist) instead of a schema bump: a new schema version would
  /// make backups of this app unreadable to its older installs.
  ///   • `habit_logs(date)`: Calendar / Insights read logs by date range,
  ///     which the `(habit_id, date)` unique index cannot serve;
  ///   • `folder_id` of notes / tasks / vault items: the folder lists count
  ///     the items of every folder with one correlated query each.
  Future<void> _ensureQueryIndexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_habit_logs_date ON habit_logs(date)',
      'CREATE INDEX IF NOT EXISTS idx_notes_folder ON notes(folder_id)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_folder ON tasks(folder_id)',
      'CREATE INDEX IF NOT EXISTS idx_vault_folder ON vault_items(folder_id)',
    ];
    for (final s in statements) {
      await customStatement(s);
    }
  }

  /// Creates the medicine tables, their search index and tombstone
  /// triggers on a database made before they existed. The tombstone trigger
  /// of `medicine_doses` is created last, so its presence means "done" and
  /// later opens cost one lookup. Every statement is idempotent.
  /// [force] skips the check (an upgrade step: its tombstone triggers may
  /// already include the marker).
  Future<void> _ensureMedicineSchema({bool force = false}) async {
    if (!force) {
      final done = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'trigger' "
        "AND name = 'tomb_medicine_doses_ai'",
      ).get();
      if (done.isNotEmpty) return;
    }
    final m = createMigrator();
    await m.createTable(medicines);
    await m.createTable(medicineDoses);
    // The search index and tombstone triggers below cover the prayer
    // tables too, so they must exist first.
    await m.createTable(prayers);
    await m.createTable(prayerLogs);
    await _createSearchIndex();
    await _createMedicineIndexes();
    await _createTombstoneTriggers();
  }

  /// The prayer tables, their search index and tombstone triggers on a
  /// database made before them — the medicine pattern again (no schema
  /// bump; marker trigger `tomb_prayer_logs_ai`).
  Future<void> _ensurePrayerSchema({bool force = false}) async {
    if (!force) {
      final done = await customSelect(
        "SELECT 1 FROM sqlite_master WHERE type = 'trigger' "
        "AND name = 'tomb_prayer_logs_ai'",
      ).get();
      if (done.isNotEmpty) return;
    }
    final m = createMigrator();
    await m.createTable(prayers);
    await m.createTable(prayerLogs);
    await _createSearchIndex();
    await _createPrayerIndexes();
    await _createTombstoneTriggers();
  }

  Future<void> _createPrayerIndexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_prayers_lifecycle ON prayers(deleted_at, archived_at)',
      'CREATE INDEX IF NOT EXISTS idx_prayer_logs_prayer ON prayer_logs(prayer_id, date)',
      'CREATE INDEX IF NOT EXISTS idx_prayer_logs_date ON prayer_logs(date)',
    ];
    for (final s in statements) {
      await customStatement(s);
    }
  }

  Future<void> _createMedicineIndexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_medicines_lifecycle ON medicines(deleted_at, archived_at)',
      'CREATE INDEX IF NOT EXISTS idx_medicine_doses_med ON medicine_doses(medicine_id, date)',
      'CREATE INDEX IF NOT EXISTS idx_medicine_doses_date ON medicine_doses(date)',
    ];
    for (final s in statements) {
      await customStatement(s);
    }
  }

  Future<void> _createIndexes() async {
    const statements = [
      'CREATE INDEX IF NOT EXISTS idx_notes_lifecycle ON notes(deleted_at, archived_at, updated_at)',
      'CREATE INDEX IF NOT EXISTS idx_tasks_lifecycle ON tasks(deleted_at, archived_at, due_date)',
      'CREATE INDEX IF NOT EXISTS idx_reminders_trigger ON reminders(deleted_at, archived_at, trigger_at)',
      'CREATE INDEX IF NOT EXISTS idx_habits_lifecycle ON habits(deleted_at, archived_at)',
      'CREATE INDEX IF NOT EXISTS idx_vault_lifecycle ON vault_items(deleted_at, archived_at)',
      'CREATE INDEX IF NOT EXISTS idx_subtasks_task ON subtasks(task_id, sort_order)',
      'CREATE INDEX IF NOT EXISTS idx_item_tags_tag ON item_tags(tag_id)',
      'CREATE INDEX IF NOT EXISTS idx_item_tags_item ON item_tags(item_type, item_id)',
      'CREATE INDEX IF NOT EXISTS idx_attachments_item ON attachments(item_type, item_id)',
      'CREATE INDEX IF NOT EXISTS idx_inbox_created ON inbox_entries(created_at)',
      'CREATE INDEX IF NOT EXISTS idx_vault_history_item ON vault_history(item_id, changed_at)',
      'CREATE INDEX IF NOT EXISTS idx_folders_module ON folders(module, sort_order)',
    ];
    for (final s in statements) {
      await customStatement(s);
    }
  }
}
