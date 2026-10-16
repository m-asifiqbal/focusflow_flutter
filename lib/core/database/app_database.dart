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
/// (`notes_fts`, `tasks_fts`, `reminders_fts`, `habits_fts`, `vault_fts`)
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
  @override
  int get schemaVersion => 2;

  /// Item tables that carry the shared lifecycle columns, by `ItemType.key`.
  static const Map<String, String> itemTables = {
    'note': 'notes',
    'task': 'tasks',
    'reminder': 'reminders',
    'habit': 'habits',
    'vault': 'vault_items',
  };

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();
      await _createSearchIndex();
      await _createIndexes();
      await _createTombstoneTriggers();
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.createTable(tombstones);
        await _createTombstoneTriggers();
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON');
      await customStatement('PRAGMA recursive_triggers = ON');
    },
  );

  /// (table, fts table, indexed columns) for every searchable module.
  static const List<(String, String, List<String>)> searchTables = [
    ('notes', 'notes_fts', ['title', 'plain_text']),
    ('tasks', 'tasks_fts', ['title', 'notes']),
    ('reminders', 'reminders_fts', ['title', 'note']),
    ('habits', 'habits_fts', ['name', 'category']),
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
