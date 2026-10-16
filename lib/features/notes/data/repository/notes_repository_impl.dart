/// ============================================================
/// NOTES REPOSITORY (Drift implementation)
/// ============================================================
///
/// List streams recompute when notes, folders, reminders or tags change
/// (a renamed folder or tag updates every card). The text filter uses the
/// `notes_fts` index; locked notes only match on their title.
/// ============================================================
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/database/daos/dao_support.dart';
import 'package:focusflow/core/database/daos/fts_query.dart';
import 'package:focusflow/core/database/daos/inbox_dao.dart';
import 'package:focusflow/core/database/daos/notes_dao.dart';
import 'package:focusflow/core/database/daos/organisation_dao.dart';
import 'package:focusflow/core/database/daos/reminders_dao.dart';
import 'package:focusflow/core/items/data/item_mappers.dart';
import 'package:focusflow/core/items/data/repository_base.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/notes/domain/services/note_content.dart';

class NotesRepositoryImpl extends RepositoryBase implements NotesRepository {
  NotesRepositoryImpl({
    required super.db,
    required super.clock,
    required super.deviceId,
    required super.newId,
  }) : _dao = NotesDao(db),
       _org = OrganisationDao(db),
       _reminders = RemindersDao(db),
       _inbox = InboxDao(db),
       _tags = TagWriter(OrganisationDao(db), newId);

  final NotesDao _dao;
  final OrganisationDao _org;
  final RemindersDao _reminders;
  final InboxDao _inbox;
  final TagWriter _tags;

  Set<ResultSetImplementation<dynamic, dynamic>> get _tables => {
    db.notes,
    db.folders,
    db.reminders,
    db.itemTags,
    db.tags,
  };

  static Note _map(NoteListRow r, List<Tag> tags) {
    final n = r.row;
    return Note(
      id: n.id,
      title: n.title,
      contentDelta: n.contentDelta,
      plainText: n.plainText,
      checklist: ChecklistItem.decodeList(n.checklistJson),
      coverImagePath: n.coverImagePath,
      isLocked: n.isLocked,
      wordCount: n.wordCount,
      reminderId: n.reminderId,
      reminderAt: r.reminderAt,
      folderId: n.folderId,
      folderName: r.folderName,
      tags: tags,
      colorHex: n.colorHex,
      isPinned: n.isPinned,
      isFavorite: n.isFavorite,
      sortOrder: n.sortOrder,
      createdAt: n.createdAt,
      updatedAt: n.updatedAt,
      archivedAt: n.archivedAt,
      deletedAt: n.deletedAt,
    );
  }

  Future<List<Note>> _withTags(List<NoteListRow> rows) async {
    if (rows.isEmpty) return const [];
    final tags = await _org.tagsByItem(
      ItemType.note,
      itemIds: rows.map((r) => r.row.id),
    );
    return [for (final r in rows) _map(r, ItemMappers.tags(tags[r.row.id]))];
  }

  static String _orderFor(NotesSort sort) => switch (sort) {
    NotesSort.lastEdited => NotesOrder.lastEdited,
    NotesSort.created => NotesOrder.created,
    NotesSort.titleAz => NotesOrder.titleAz,
    NotesSort.colour => NotesOrder.colour,
    NotesSort.manual => NotesOrder.manual,
  };

  @override
  Stream<List<Note>> watchNotes(NotesQuery query) =>
      db.watchComputed(_tables, () async {
        final terms = FtsQuery.terms(query.text);
        final rows = await _dao
            .queryNotes(
              folderId: query.folderId,
              tagId: query.tagId,
              ftsMatch: FtsQuery.prefixMatch(terms),
              ftsTitleMatch: FtsQuery.prefixMatch(terms, column: 'title'),
              pinnedOnly: query.pinnedOnly,
              orderBy: _orderFor(query.sort),
              limit: query.limit,
            )
            .get();
        return _withTags(rows);
      });

  @override
  Stream<Note?> watchNote(String id) =>
      db.watchComputed(_tables, () => getNote(id));

  @override
  Future<Note?> getNote(String id) async {
    final row = await _dao.noteById(id).getSingleOrNull();
    if (row == null) return null;
    return (await _withTags([row])).first;
  }

  static int _countWords(String text) => RegExp(r'\S+').allMatches(text).length;

  @override
  Future<String> createEmpty({
    String? folderId,
    String? colorHex,
    List<String> tagNames = const [],
    String title = '',
    String initialText = '',
  }) => db.transaction(() async {
    final s = stamp();
    final id = newId();
    final body = initialText.trim();
    await _dao.insertNote(
      NotesCompanion.insert(
        id: id,
        createdAt: s.now,
        updatedAt: s.now,
        title: Value(title.trim()),
        plainText: Value(body),
        contentDelta: Value(
          body.isEmpty
              ? '[]'
              : jsonEncode([
                  {'insert': '$body\n'},
                ]),
        ),
        wordCount: Value(_countWords('$title $body')),
        folderId: Value(folderId),
        colorHex: Value(colorHex),
        sortOrder: Value(((await _dao.maxSortOrder()) ?? 0) + 1),
        syncVersion: const Value(1),
        deviceId: Value(deviceId),
      ),
    );
    if (tagNames.isNotEmpty) {
      await _tags.replaceTags(ItemType.note, id, tagNames, s);
    }
    return id;
  });

  Future<void> _update(String id, NotesCompanion changes) =>
      _dao.updateNote(id, changes, stamp());

  @override
  Future<void> saveContent(
    String id, {
    required String title,
    required String deltaJson,
    required String plainText,
    List<ChecklistItem> checklist = const [],
    required int wordCount,
  }) => _update(
    id,
    NotesCompanion(
      title: Value(title),
      contentDelta: Value(deltaJson),
      plainText: Value(plainText),
      checklistJson: Value(ChecklistItem.encodeList(checklist)),
      wordCount: Value(wordCount),
    ),
  );

  @override
  Future<void> setColor(String id, String? colorHex) =>
      _update(id, NotesCompanion(colorHex: Value(colorHex)));

  @override
  Future<void> setPinned(String id, bool pinned) =>
      _update(id, NotesCompanion(isPinned: Value(pinned)));

  @override
  Future<void> setFavorite(String id, bool favorite) =>
      _update(id, NotesCompanion(isFavorite: Value(favorite)));

  @override
  Future<void> setLocked(String id, bool locked) =>
      _update(id, NotesCompanion(isLocked: Value(locked)));

  @override
  Future<void> setFolder(String id, String? folderId) =>
      _update(id, NotesCompanion(folderId: Value(folderId)));

  @override
  Future<void> setReminderId(String id, String? reminderId) =>
      _update(id, NotesCompanion(reminderId: Value(reminderId)));

  @override
  Future<void> setCover(String id, String? coverImagePath) =>
      _update(id, NotesCompanion(coverImagePath: Value(coverImagePath)));

  @override
  Future<void> setTags(String id, List<String> tagNames) =>
      db.transaction(() async {
        final s = stamp();
        if (await _tags.replaceTags(ItemType.note, id, tagNames, s)) {
          await _dao.updateNote(id, const NotesCompanion(), s);
        }
      });

  @override
  Future<void> reorder(String id, {String? afterId, String? beforeId}) async {
    final after = afterId == null ? null : await _dao.sortOrderOf(afterId);
    final before = beforeId == null ? null : await _dao.sortOrderOf(beforeId);
    await _update(
      id,
      NotesCompanion(sortOrder: Value(sortBetween(after, before))),
    );
  }

  @override
  Future<void> addAttachment(
    String noteId, {
    required String localPath,
    required String fileName,
    String mimeType = '',
    int sizeBytes = 0,
  }) => db.transaction(() async {
    final s = stamp();
    await _org.insertAttachment(
      AttachmentsCompanion.insert(
        id: newId(),
        itemId: noteId,
        itemType: ItemType.note.key,
        fileName: fileName,
        mimeType: Value(mimeType),
        sizeBytes: Value(sizeBytes),
        localPath: localPath,
        createdAt: s.now,
      ),
    );
    await _dao.updateNote(noteId, const NotesCompanion(), s);
  });

  @override
  Future<List<String>> pruneAttachments(String noteId, Set<String> keepPaths) =>
      db.transaction(() async {
        // Keep what the *database* references too, not only the editor's
        // snapshot: sync / restore may have added an image to the stored
        // body while the editor was open.
        final note = await _dao.rowById(noteId);
        final keep = {
          ...keepPaths,
          if (note != null)
            ...NoteContent.fromDeltaJson(note.contentDelta).imagePaths,
          if (note?.coverImagePath != null) note!.coverImagePath!,
        };
        final rows = await _org.attachmentsOf(ItemType.note, [noteId]);
        final stale = rows.where((a) => !keep.contains(a.localPath)).toList();
        if (stale.isEmpty) return const <String>[];
        await (db.delete(
          db.attachments,
        )..where((a) => a.id.isIn(stale.map((a) => a.id)))).go();
        await _dao.updateNote(noteId, const NotesCompanion(), stamp());
        final orphaned = <String>[];
        for (final path in {for (final a in stale) a.localPath}) {
          if (!await _org.isFileReferenced(path)) orphaned.add(path);
        }
        return orphaned;
      });

  @override
  Future<bool> deleteIfEmpty(String id) => db.transaction(() async {
    final row = await _dao.rowById(id);
    if (row == null) return false;
    // Archived / trashed by the user while open: their action wins.
    if (row.archivedAt != null || row.deletedAt != null) return false;
    final empty =
        row.title.trim().isEmpty &&
        row.plainText.trim().isEmpty &&
        ChecklistItem.decodeList(row.checklistJson).isEmpty &&
        row.coverImagePath == null &&
        (await _org.attachmentsOf(ItemType.note, [id])).isEmpty;
    if (!empty) return false;
    // A reminder set on the blank note goes with it (never orphaned).
    final reminders = {
      ...(await _reminders.rowsLinkedTo(
        ItemType.note.key,
        id,
      )).map((r) => r.id),
      ?row.reminderId,
    }.toList();
    if (reminders.isNotEmpty) {
      await _org.deleteItemTagsOf(ItemType.reminder, reminders);
      await _org.deleteAttachmentsOf(ItemType.reminder, reminders);
      await _inbox.clearItemRefs(ItemType.reminder.key, reminders);
      await _reminders.deleteReminders(reminders);
    }
    await _org.deleteItemTagsOf(ItemType.note, [id]);
    await _dao.deleteNote(id);
    return true;
  });

  @override
  Stream<NotesCounts> watchCounts() => db.watchComputed({db.notes}, () async {
    final c = await _dao.counts().getSingle();
    final byFolder = await _dao.countsByFolder().get();
    return NotesCounts(
      total: c.read<int>('total'),
      pinned: c.read<int>('pinned'),
      locked: c.read<int>('locked'),
      lastEditedAt: c.readNullable<DateTime>('last_edited'),
      byFolder: {
        for (final r in byFolder)
          r.readNullable<String>('folder_id'): r.read<int>('c'),
      },
    );
  });

  @override
  Stream<List<DateTime>> watchCreatedInRange(DateTime from, DateTime to) =>
      db.watchComputed({db.notes}, () => _dao.createdInRange(from, to).get());
}
