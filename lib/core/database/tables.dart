/// ============================================================
/// DRIFT TABLES — the single on-device database (schema v2)
/// ============================================================
///
/// Every module table (`notes`, `tasks`, `reminders`, `habits`,
/// `vault_items`) mixes in [ItemColumns] — the shared lifecycle the whole
/// app is built on:
///
///   Active          archivedAt == null && deletedAt == null
///   Archive         archivedAt != null   (hidden, restorable, still synced)
///   Recently Deleted deletedAt != null   (purged 30 days after deletedAt)
///
/// Conventions:
/// - ids are uuid v4 strings (stable across devices for sync/merge).
/// - DateTime columns use drift's default (unix seconds); "pure dates"
///   (habit log days) are `yyyy-MM-dd` text so they never shift with
///   time zones.
/// - Every write bumps `updatedAt` + `syncVersion` (last-write-wins merge,
///   see core/sync).
/// - Search: an FTS5 table `search_index` is kept in sync by SQL triggers
///   (created in app_database.dart), so DAOs never touch it.
/// - Sync: hard deletes leave a row in [Tombstones] (also written by SQL
///   triggers — see core/database/sync_tombstones.dart) so a merge with an
///   older backup never resurrects them.
///
/// **IMPORTANT:** after editing this file run
///   `dart run build_runner build --delete-conflicting-outputs`
/// and add a migration step in AppDatabase.migration.
/// ============================================================
library;

import 'package:drift/drift.dart';

/// Columns shared by every item table (see file header).
mixin ItemColumns on Table {
  TextColumn get id => text()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get archivedAt => dateTime().nullable()();
  DateTimeColumn get deletedAt => dateTime().nullable()();
  BoolColumn get isPinned => boolean().withDefault(const Constant(false))();
  BoolColumn get isFavorite => boolean().withDefault(const Constant(false))();

  /// `RRGGBB`; null = module default / white card.
  TextColumn get colorHex => text().nullable()();

  /// Folder (notes/vault) or list (tasks). See [Folders].
  TextColumn get folderId => text().nullable()();

  /// Manual sort position (lower first). Fractional so a drag only rewrites
  /// the moved row.
  RealColumn get sortOrder => real().withDefault(const Constant(0))();

  IntColumn get syncVersion => integer().withDefault(const Constant(0))();
  DateTimeColumn get lastSyncedAt => dateTime().nullable()();

  /// Device that last wrote the row (core/storage/device_id).
  TextColumn get deviceId => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────
// Notes
// ─────────────────────────────────────────────────────────────

@DataClassName('NoteRow')
class Notes extends Table with ItemColumns {
  TextColumn get title => text().withDefault(const Constant(''))();

  /// Quill Delta JSON (`[{"insert":"…"}]`). Source of truth for the body.
  TextColumn get contentDelta => text().withDefault(const Constant('[]'))();

  /// Plain text extracted from the delta — previews + full-text search.
  TextColumn get plainText => text().withDefault(const Constant(''))();

  /// Cached checklist preview: JSON `[{"text":"…","done":true}]`.
  TextColumn get checklistJson => text().withDefault(const Constant('[]'))();

  /// Relative path (under app documents) of the cover image, if any.
  TextColumn get coverImagePath => text().nullable()();

  /// Locked notes require the vault PIN to open; previews are blurred.
  BoolColumn get isLocked => boolean().withDefault(const Constant(false))();
  IntColumn get wordCount => integer().withDefault(const Constant(0))();

  /// Linked reminder ("Reminder Fri" in the editor meta line).
  TextColumn get reminderId => text().nullable()();
}

// ─────────────────────────────────────────────────────────────
// Tasks
// ─────────────────────────────────────────────────────────────

@DataClassName('TaskRow')
class Tasks extends Table with ItemColumns {
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get notes => text().withDefault(const Constant(''))();

  /// Local calendar day the task is due (stored at local midnight).
  DateTimeColumn get dueDate => dateTime().nullable()();

  /// Minutes after midnight (09:00 → 540); null = all day.
  IntColumn get dueTimeMinutes => integer().nullable()();

  /// 0 none · 1 low · 2 medium · 3 high.
  IntColumn get priority => integer().withDefault(const Constant(0))();

  /// RFC 5545 RRULE (e.g. `FREQ=WEEKLY;BYDAY=TU`); null = no repeat.
  TextColumn get repeatRule => text().nullable()();

  /// "Remind me 15 min before" — creates/updates [reminderId].
  IntColumn get remindOffsetMinutes => integer().nullable()();
  TextColumn get reminderId => text().nullable()();
  TextColumn get linkedNoteId => text().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Board view column: 0 to do · 1 doing · 2 done (v1.1).
  IntColumn get boardStatus => integer().withDefault(const Constant(0))();
}

@DataClassName('SubtaskRow')
class Subtasks extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text()();
  TextColumn get title => text().withDefault(const Constant(''))();
  BoolColumn get done => boolean().withDefault(const Constant(false))();
  RealColumn get sortOrder => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────
// Reminders
// ─────────────────────────────────────────────────────────────

@DataClassName('ReminderRow')
class Reminders extends Table with ItemColumns {
  TextColumn get title => text().withDefault(const Constant(''))();
  TextColumn get note => text().withDefault(const Constant(''))();

  /// Next time the reminder fires (local wall time stored as an instant).
  DateTimeColumn get triggerAt => dateTime()();

  /// RRULE; null = once.
  TextColumn get repeatRule => text().nullable()();

  /// 0 notification · 1 alarm (full-screen intent / time-sensitive).
  IntColumn get alertStyle => integer().withDefault(const Constant(0))();
  TextColumn get sound => text().withDefault(const Constant('chime'))();
  IntColumn get snoozeMinutes => integer().withDefault(const Constant(10))();
  DateTimeColumn get snoozedUntil => dateTime().nullable()();

  /// JSON `{"lat":…,"lng":…,"radius":…,"onEnter":true,"label":"Office"}`
  /// (geofencing is v1.1 behind a flag; the column exists for sync).
  TextColumn get locationJson => text().nullable()();

  /// What the reminder belongs to (task / note …), if anything.
  TextColumn get linkedItemId => text().nullable()();
  TextColumn get linkedItemType => text().nullable()();
  BoolColumn get isEnabled => boolean().withDefault(const Constant(true))();
  DateTimeColumn get lastFiredAt => dateTime().nullable()();
  DateTimeColumn get completedAt => dateTime().nullable()();

  /// Stable 31-bit id for flutter_local_notifications.
  IntColumn get notificationId => integer()();
}

// ─────────────────────────────────────────────────────────────
// Habits
// ─────────────────────────────────────────────────────────────

@DataClassName('HabitRow')
class Habits extends Table with ItemColumns {
  TextColumn get name => text().withDefault(const Constant(''))();

  /// Key into the habit icon catalogue (features/habits).
  TextColumn get iconKey => text().withDefault(const Constant('star'))();
  TextColumn get category => text().withDefault(const Constant('Health'))();

  /// 0 build · 1 quit.
  IntColumn get habitType => integer().withDefault(const Constant(0))();

  /// Daily target (8 glasses). 1 = a simple yes/no habit.
  IntColumn get targetCount => integer().withDefault(const Constant(1))();
  TextColumn get unit => text().withDefault(const Constant('times'))();

  /// 0 every day · 1 specific days ([weekdaysMask]) · 2 x per week · 3 every N days.
  IntColumn get frequencyType => integer().withDefault(const Constant(0))();

  /// Bit 0 = Monday … bit 6 = Sunday (127 = every day).
  IntColumn get weekdaysMask => integer().withDefault(const Constant(127))();
  IntColumn get timesPerWeek => integer().withDefault(const Constant(3))();
  IntColumn get everyNDays => integer().withDefault(const Constant(2))();

  /// 0 anytime · 1 morning · 2 afternoon · 3 evening (list filter chips).
  IntColumn get partOfDay => integer().withDefault(const Constant(0))();
  BoolColumn get reminderEnabled =>
      boolean().withDefault(const Constant(false))();

  /// JSON list of `HH:mm` strings.
  TextColumn get reminderTimesJson =>
      text().withDefault(const Constant('[]'))();

  /// First day the habit counts (yyyy-MM-dd).
  TextColumn get startDate => text()();
  BoolColumn get isPaused => boolean().withDefault(const Constant(false))();
}

@DataClassName('HabitLogRow')
class HabitLogs extends Table {
  TextColumn get id => text()();
  TextColumn get habitId => text()();

  /// Local day, yyyy-MM-dd.
  TextColumn get date => text()();
  IntColumn get count => integer().withDefault(const Constant(0))();
  BoolColumn get skipped => boolean().withDefault(const Constant(false))();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};

  @override
  List<Set<Column<Object>>> get uniqueKeys => [
    {habitId, date},
  ];
}

// ─────────────────────────────────────────────────────────────
// Vault (secrets live ONLY inside encryptedPayload)
// ─────────────────────────────────────────────────────────────

@DataClassName('VaultItemRow')
class VaultItems extends Table with ItemColumns {
  /// 0 login · 1 card · 2 wifi · 3 secure note.
  IntColumn get itemType => integer().withDefault(const Constant(0))();

  /// Plaintext title — the ONLY searchable field.
  TextColumn get title => text().withDefault(const Constant(''))();

  /// Brand / icon key (letter avatar fallback).
  TextColumn get iconKey => text().nullable()();

  /// AES-256-GCM: nonce(12) ‖ ciphertext ‖ mac(16) of the JSON payload
  /// {username, password, url, totpSecret, notes, card…, wifi…, customFields}.
  BlobColumn get encryptedPayload => blob()();

  /// Cached 0–4 strength of the current password (no secret leaks).
  IntColumn get passwordStrength => integer().nullable()();
  DateTimeColumn get passwordUpdatedAt => dateTime().nullable()();

  /// HMAC-SHA256(password) under a key derived from the vault DEK —
  /// detects reuse without decrypting every item.
  TextColumn get passwordFingerprint => text().nullable()();

  /// Have-I-Been-Pwned result cache (opt-in): null = never checked.
  IntColumn get breachCount => integer().nullable()();
  DateTimeColumn get breachCheckedAt => dateTime().nullable()();
  BoolColumn get hasTotp => boolean().withDefault(const Constant(false))();

  /// "Password expiry reminder" in days; null = off.
  IntColumn get expiryDays => integer().nullable()();
}

@DataClassName('VaultHistoryRow')
class VaultHistory extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();

  /// Previous password, encrypted with the vault DEK.
  BlobColumn get encryptedPassword => blob()();
  DateTimeColumn get changedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Password generator history (last 10, encrypted, local only — never synced).
@DataClassName('GeneratorHistoryRow')
class GeneratorHistory extends Table {
  TextColumn get id => text()();
  BlobColumn get encryptedValue => blob()();
  TextColumn get mode => text().withDefault(const Constant('password'))();
  IntColumn get entropyBits => integer().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────
// Organisation: folders/lists, tags, attachments
// ─────────────────────────────────────────────────────────────

/// Note folders (Ideas, Work…), task lists (Work, Personal) and vault
/// folders — scoped by [module] (`ItemType.key`).
@DataClassName('FolderRow')
class Folders extends Table {
  TextColumn get id => text()();
  TextColumn get module => text()();
  TextColumn get name => text()();
  TextColumn get colorHex => text().nullable()();
  TextColumn get iconKey => text().nullable()();
  RealColumn get sortOrder => real().withDefault(const Constant(0))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();
  DateTimeColumn get deletedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('TagRow')
class Tags extends Table {
  TextColumn get id => text()();

  /// Without the leading '#', lower case, unique.
  TextColumn get name => text().unique()();
  TextColumn get colorHex => text().nullable()();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get updatedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

@DataClassName('ItemTagRow')
class ItemTags extends Table {
  TextColumn get itemId => text()();

  /// `ItemType.key`.
  TextColumn get itemType => text()();
  TextColumn get tagId => text()();

  @override
  Set<Column<Object>> get primaryKey => {itemId, tagId};
}

@DataClassName('AttachmentRow')
class Attachments extends Table {
  TextColumn get id => text()();
  TextColumn get itemId => text()();
  TextColumn get itemType => text()();
  TextColumn get fileName => text()();
  TextColumn get mimeType => text().withDefault(const Constant(''))();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();

  /// Relative to the app documents directory (`attachments/<id>.<ext>`).
  TextColumn get localPath => text()();
  DateTimeColumn get createdAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────
// Notification centre inbox, focus sessions, backup history
// ─────────────────────────────────────────────────────────────

/// Every fired local notification (and in-app event) lands here — the
/// Notification centre (screen 27) reads it; unread count drives the bell dot.
@DataClassName('InboxRow')
class InboxEntries extends Table {
  TextColumn get id => text()();

  /// reminder · task · habit · security · sync · system.
  TextColumn get kind => text()();
  TextColumn get title => text()();
  TextColumn get body => text().withDefault(const Constant(''))();
  TextColumn get itemId => text().nullable()();
  TextColumn get itemType => text().nullable()();

  /// JSON list of action keys offered inline (done, snooze, reschedule, view…).
  TextColumn get actionsJson => text().withDefault(const Constant('[]'))();
  DateTimeColumn get createdAt => dateTime()();
  DateTimeColumn get readAt => dateTime().nullable()();
  DateTimeColumn get dismissedAt => dateTime().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Focus time (Insights › Focus hours). Written by the task focus timer.
@DataClassName('FocusSessionRow')
class FocusSessions extends Table {
  TextColumn get id => text()();
  TextColumn get taskId => text().nullable()();
  DateTimeColumn get startedAt => dateTime()();
  IntColumn get durationMinutes => integer()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

/// Local record of backups made from this device (Drive + local files).
@DataClassName('BackupRecordRow')
class BackupRecords extends Table {
  TextColumn get id => text()();

  /// drive · local.
  TextColumn get location => text()();
  DateTimeColumn get createdAt => dateTime()();
  IntColumn get sizeBytes => integer().withDefault(const Constant(0))();
  IntColumn get itemCount => integer().withDefault(const Constant(0))();
  BoolColumn get isAuto => boolean().withDefault(const Constant(false))();
  BoolColumn get isEncrypted => boolean().withDefault(const Constant(false))();
  TextColumn get driveFileId => text().nullable()();
  TextColumn get localPath => text().nullable()();

  @override
  Set<Column<Object>> get primaryKey => {id};
}

// ─────────────────────────────────────────────────────────────
// Sync bookkeeping (schema v2)
// ─────────────────────────────────────────────────────────────

/// One row per *hard* delete that a backup merge must replay on other
/// devices (permanent delete, the 30-day purge, a cleared habit log, a
/// deleted tag …). Written only by SQL triggers (sync_tombstones.dart):
/// an AFTER DELETE trigger records the key, an AFTER INSERT trigger removes
/// it again when the same key comes back (undo, re-log, restore).
/// Child rows that always travel with their parent (subtasks, item tags,
/// attachments, vault history) need no tombstones.
@DataClassName('TombstoneRow')
class Tombstones extends Table {
  /// What was deleted: an `ItemType.key` (`note`, `task`, `reminder`,
  /// `habit`, `vault`) or `tag`, `folder`, `habit_log`, `focus_session`.
  TextColumn get entity => text()();

  /// The deleted row's id — for habit logs the natural key
  /// `habitId|yyyy-MM-dd` (log ids differ between devices).
  TextColumn get entityId => text()();
  DateTimeColumn get deletedAt => dateTime()();

  /// Device that deleted it; '' until the next backup stamps it.
  TextColumn get deviceId => text().withDefault(const Constant(''))();

  @override
  Set<Column<Object>> get primaryKey => {entity, entityId};
}
