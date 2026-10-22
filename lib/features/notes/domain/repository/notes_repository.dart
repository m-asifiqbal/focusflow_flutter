/// ============================================================
/// NOTES REPOSITORY (contract)
/// ============================================================
///
/// Lists stream *active* notes only, pinned first. Lifecycle (archive,
/// trash, delete forever), duplicate and multi-select bulk actions live in
/// ItemsRepository; this contract covers what is note-specific.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';

/// Sort control of the notes list (pinned always first).
enum NotesSort {
  lastEdited('Last edited'),
  created('Created'),
  titleAz('Title A–Z'),
  colour('Colour'),
  manual('Manual');

  const NotesSort(this.label);

  final String label;
}

@immutable
class NotesQuery {
  const NotesQuery({
    this.folderId,
    this.tagId,
    this.text = '',
    this.sort = NotesSort.lastEdited,
    this.pinnedOnly = false,
    this.limit,
    this.light = false,
  });

  /// Folder chip filter (null = all).
  final String? folderId;
  final String? tagId;

  /// Full-text filter (prefix match per word; locked notes match by title
  /// only).
  final String text;
  final NotesSort sort;
  final bool pinnedOnly;

  /// e.g. Home "Recent notes" → 4.
  final int? limit;

  /// Rows without the body: [Note.contentDelta] stays `[]`, the checklist
  /// empty and [Note.plainText] only its first ~160 characters (enough for
  /// [Note.displayTitle]). For views that need titles and dates of many
  /// notes (the calendar) and must not pull every note's full text — and
  /// must never be saved back.
  final bool light;

  NotesQuery copyWith({
    String? folderId,
    bool clearFolder = false,
    String? tagId,
    bool clearTag = false,
    String? text,
    NotesSort? sort,
    bool? pinnedOnly,
    int? limit,
    bool? light,
  }) => NotesQuery(
    folderId: clearFolder ? null : (folderId ?? this.folderId),
    tagId: clearTag ? null : (tagId ?? this.tagId),
    text: text ?? this.text,
    sort: sort ?? this.sort,
    pinnedOnly: pinnedOnly ?? this.pinnedOnly,
    limit: limit ?? this.limit,
    light: light ?? this.light,
  );

  @override
  bool operator ==(Object other) =>
      other is NotesQuery &&
      other.folderId == folderId &&
      other.tagId == tagId &&
      other.text == text &&
      other.sort == sort &&
      other.pinnedOnly == pinnedOnly &&
      other.limit == limit &&
      other.light == light;

  @override
  int get hashCode =>
      Object.hash(folderId, tagId, text, sort, pinnedOnly, limit, light);
}

/// Header numbers ("48 notes · 3 pinned") and folder chip counts.
@immutable
class NotesCounts {
  const NotesCounts({
    this.total = 0,
    this.pinned = 0,
    this.locked = 0,
    this.lastEditedAt,
    this.byFolder = const {},
  });

  final int total;
  final int pinned;
  final int locked;
  final DateTime? lastEditedAt;

  /// folderId → active notes (key null = notes without a folder).
  final Map<String?, int> byFolder;

  @override
  bool operator ==(Object other) =>
      other is NotesCounts &&
      other.total == total &&
      other.pinned == pinned &&
      other.locked == locked &&
      other.lastEditedAt == lastEditedAt &&
      mapEquals(other.byFolder, byFolder);

  @override
  int get hashCode => Object.hash(
    total,
    pinned,
    locked,
    lastEditedAt,
    Object.hashAllUnordered(byFolder.entries.map((e) => (e.key, e.value))),
  );
}

abstract interface class NotesRepository {
  /// Active notes for [query], pinned first, with folder name, tags and the
  /// linked reminder's time.
  Stream<List<Note>> watchNotes(NotesQuery query);

  /// One note in any lifecycle state (null when gone).
  Stream<Note?> watchNote(String id);
  Future<Note?> getNote(String id);

  /// Creates a note and returns its id. [initialText] (quick capture / scan)
  /// becomes the body; [title] the title.
  Future<String> createEmpty({
    String? folderId,
    String? colorHex,
    List<String> tagNames = const [],
    String title = '',
    String initialText = '',
  });

  /// Auto-save of the editor content.
  Future<void> saveContent(
    String id, {
    required String title,
    required String deltaJson,
    required String plainText,
    List<ChecklistItem> checklist = const [],
    required int wordCount,
  });

  Future<void> setColor(String id, String? colorHex);
  Future<void> setPinned(String id, bool pinned);
  Future<void> setFavorite(String id, bool favorite);

  /// Locks / unlocks [id]. Unlocking also forgets its PIN verifier; locking
  /// without one is the legacy "Vault PIN" lock.
  Future<void> setLocked(String id, bool locked);

  /// Locks [id] with its own PIN: [verifier] is what NotePinService made
  /// (never the PIN itself). Replaces a previous PIN.
  Future<void> lockWithPin(String id, String verifier);

  /// The PIN verifier of [id]; null when it has none (not locked, or locked
  /// the legacy way with the Vault PIN). Kept out of [Note] so lists never
  /// carry it.
  Future<String?> lockVerifier(String id);
  Future<void> setFolder(String id, String? folderId);

  /// Points the note at a reminder (null clears the pointer only — use
  /// RemindersRepository.removeLinkedReminder to delete the reminder).
  Future<void> setReminderId(String id, String? reminderId);

  /// Relative cover image path (null removes the cover).
  Future<void> setCover(String id, String? coverImagePath);

  /// Replaces the note's tags by name (missing tags are created).
  Future<void> setTags(String id, List<String> tagNames);

  /// Manual order: place [id] between [afterId] (above) and [beforeId]
  /// (below); either may be null at the ends.
  Future<void> reorder(String id, {String? afterId, String? beforeId});

  /// Records an image / file attached to the note ([localPath] is relative
  /// to the app documents directory, e.g. `attachments/<id>.jpg`).
  Future<void> addAttachment(
    String noteId, {
    required String localPath,
    required String fileName,
    String mimeType = '',
    int sizeBytes = 0,
  });

  /// Removes the note's attachment rows whose path is neither in
  /// [keepPaths] (the editor's body) nor referenced by the note's *current*
  /// stored body / cover (sync may have changed it meanwhile). Returns the
  /// removed paths that no other row references any more — the caller
  /// deletes those files.
  Future<List<String>> pruneAttachments(String noteId, Set<String> keepPaths);

  /// Hard-deletes the note (no trash) when it has no title, body,
  /// checklist, cover or attachments — discarding an untouched new note.
  /// Never touches an archived / trashed note (the user's action wins); a
  /// reminder linked to the deleted note is removed with it. Returns true
  /// when it was deleted.
  Future<bool> deleteIfEmpty(String id);

  Stream<NotesCounts> watchCounts();

  /// Creation instants of active notes created in [from, to) (local
  /// bounds), oldest first — Insights › Notes created.
  Stream<List<DateTime>> watchCreatedInRange(DateTime from, DateTime to);
}
