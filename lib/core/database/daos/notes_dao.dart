/// ============================================================
/// NOTES DAO — row-level queries for `notes`
/// ============================================================
///
/// List queries join the folder name and the linked reminder's next
/// trigger so a note card renders from one row. The optional full-text
/// filter goes through `notes_fts` (rowid join); locked notes only match
/// on their title so a search never reveals a locked body.
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/tables.dart';

part 'notes_dao.g.dart';

/// A note row plus the joined columns a card needs.
typedef NoteListRow = ({NoteRow row, String? folderName, DateTime? reminderAt});

/// ORDER BY fragments (alias `n`); pinned notes always come first.
abstract final class NotesOrder {
  static const lastEdited = 'n.updated_at DESC';
  static const created = 'n.created_at DESC';
  static const titleAz =
      "CASE WHEN trim(n.title) = '' THEN 1 ELSE 0 END, "
      'n.title COLLATE NOCASE ASC';
  static const colour =
      'CASE WHEN n.color_hex IS NULL THEN 1 ELSE 0 END, '
      'n.color_hex ASC, n.updated_at DESC';
  static const manual = 'n.sort_order ASC, n.created_at DESC';
}

@DriftAccessor(tables: [Notes, Folders, Reminders, ItemTags, Tags])
class NotesDao extends DatabaseAccessor<AppDatabase> with _$NotesDaoMixin {
  NotesDao(super.attachedDatabase);

  static const _joins =
      'f.name AS folder_name, '
      'CASE WHEN r.id IS NULL THEN NULL '
      'ELSE COALESCE(r.snoozed_until, r.trigger_at) END AS reminder_at '
      'FROM notes n '
      'LEFT JOIN folders f ON f.id = n.folder_id AND f.deleted_at IS NULL '
      'LEFT JOIN reminders r ON r.id = n.reminder_id AND r.deleted_at IS NULL '
      'AND r.archived_at IS NULL';

  static const _select = 'SELECT n.*, $_joins';

  /// Every column of `notes` except the heavy ones: the Delta and the
  /// checklist cache are `[]`, the plain text is cut to its first 160
  /// characters. Must list every column (the row mapper reads them all).
  static const _selectLight =
      'SELECT n.id, n.created_at, n.updated_at, n.archived_at, n.deleted_at, '
      'n.is_pinned, n.is_favorite, n.color_hex, n.folder_id, n.sort_order, '
      'n.sync_version, n.last_synced_at, n.device_id, n.title, '
      "'[]' AS content_delta, substr(n.plain_text, 1, 160) AS plain_text, "
      "'[]' AS checklist_json, n.cover_image_path, n.is_locked, "
      'n.word_count, n.reminder_id, $_joins';

  NoteListRow _map(QueryRow r) => (
    row: notes.map(r.data),
    folderName: r.readNullable<String>('folder_name'),
    reminderAt: r.readNullable<DateTime>('reminder_at'),
  );

  /// Active notes filtered by folder / tag / FTS expressions.
  ///
  /// [ftsMatch] matches title + body; [ftsTitleMatch] is the same terms
  /// restricted to the title column and is used for locked notes. Both are
  /// built with FtsQuery and must be passed together.
  Selectable<NoteListRow> queryNotes({
    String? folderId,
    String? tagId,
    String? ftsMatch,
    String? ftsTitleMatch,
    bool pinnedOnly = false,
    String orderBy = NotesOrder.lastEdited,
    int? limit,
    bool light = false,
  }) {
    final where = <String>[activeSql('n')];
    final vars = <Variable>[];
    if (folderId != null) {
      where.add('n.folder_id = ?');
      vars.add(Variable.withString(folderId));
    }
    if (tagId != null) {
      where.add(
        "EXISTS (SELECT 1 FROM item_tags it WHERE it.item_type = 'note' "
        'AND it.item_id = n.id AND it.tag_id = ?)',
      );
      vars.add(Variable.withString(tagId));
    }
    if (pinnedOnly) where.add('n.is_pinned = 1');
    if (ftsMatch != null && ftsTitleMatch != null) {
      where.add(
        '((n.is_locked = 0 AND n.rowid IN (SELECT rowid FROM notes_fts '
        'WHERE notes_fts MATCH ?)) OR (n.is_locked = 1 AND n.rowid IN '
        '(SELECT rowid FROM notes_fts WHERE notes_fts MATCH ?)))',
      );
      vars
        ..add(Variable.withString(ftsMatch))
        ..add(Variable.withString(ftsTitleMatch));
    }
    return customSelect(
      '${light ? _selectLight : _select} WHERE ${where.join(' AND ')} '
      'ORDER BY n.is_pinned DESC, $orderBy'
      '${limit == null ? '' : ' LIMIT $limit'}',
      variables: vars,
      readsFrom: {notes, folders, reminders, itemTags},
    ).map(_map);
  }

  /// One note (any lifecycle state) with its joined columns.
  Selectable<NoteListRow> noteById(String id) => customSelect(
    '$_select WHERE n.id = ?',
    variables: [Variable.withString(id)],
    readsFrom: {notes, folders, reminders},
  ).map(_map);

  Future<NoteRow?> rowById(String id) =>
      (select(notes)..where((n) => n.id.equals(id))).getSingleOrNull();

  Future<void> insertNote(NotesCompanion note) => into(notes).insert(note);

  /// Stamped update (updated_at, device_id, sync_version + 1).
  Future<int> updateNote(String id, NotesCompanion changes, WriteStamp stamp) =>
      (update(
        notes,
      )..where((n) => n.id.equals(id))).write(stampedUpdate(changes, stamp));

  Future<int> deleteNote(String id) =>
      (delete(notes)..where((n) => n.id.equals(id))).go();

  Future<double?> maxSortOrder() {
    final max = notes.sortOrder.max();
    return (selectOnly(
      notes,
    )..addColumns([max])).map((r) => r.read(max)).getSingle();
  }

  Future<double?> sortOrderOf(String id) async =>
      (await rowById(id))?.sortOrder;

  /// Counts for headers: total / pinned / last edit / per folder.
  Selectable<QueryRow> counts() => customSelect(
    'SELECT COUNT(*) AS total, '
    'COALESCE(SUM(CASE WHEN is_pinned = 1 THEN 1 ELSE 0 END), 0) AS pinned, '
    'COALESCE(SUM(CASE WHEN is_locked = 1 THEN 1 ELSE 0 END), 0) AS locked, '
    'MAX(updated_at) AS last_edited FROM notes WHERE ${activeSql()}',
    readsFrom: {notes},
  );

  /// Creation instants of active notes created in [from, to), oldest
  /// first (Insights › Notes created).
  Selectable<DateTime> createdInRange(DateTime from, DateTime to) =>
      customSelect(
        'SELECT created_at FROM notes WHERE ${activeSql()} '
        'AND created_at >= ? AND created_at < ? ORDER BY created_at ASC',
        variables: [Variable<DateTime>(from), Variable<DateTime>(to)],
        readsFrom: {notes},
      ).map((r) => r.read<DateTime>('created_at'));

  /// `folder_id → active note count` (null key = no folder).
  Selectable<QueryRow> countsByFolder() => customSelect(
    'SELECT folder_id, COUNT(*) AS c FROM notes WHERE ${activeSql()} '
    'GROUP BY folder_id',
    readsFrom: {notes},
  );
}
