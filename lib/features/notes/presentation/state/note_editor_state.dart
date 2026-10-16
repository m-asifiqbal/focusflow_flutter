/// ============================================================
/// NOTE EDITOR STATE — what the editor screen (08) renders around Quill
/// ============================================================
///
/// The Quill document and title text live in UI controllers owned by the
/// screen; this state carries everything else: which note is open, whether
/// this session created it (empty new notes are discarded on back), the
/// auto-save status shown under the folder name, and whether a locked note
/// has been unlocked with the vault PIN for this session.
/// ============================================================
library;

import 'package:flutter/foundation.dart';

/// Arguments of an editor session: an existing note ([noteId]) or a new
/// one prefilled from `/notes/new?text=&folderId=&tag=`.
///
/// [session] makes every opened editor screen its own controller (the
/// screen passes a fresh token), so reopening `/notes/new` never reuses a
/// controller that is still closing the previous note.
@immutable
class NoteEditorArgs {
  const NoteEditorArgs({
    this.noteId,
    this.text,
    this.folderId,
    this.tag,
    this.session,
  });

  final String? noteId;
  final String? text;
  final String? folderId;
  final String? tag;
  final Object? session;

  bool get isNew => noteId == null;

  @override
  bool operator ==(Object other) =>
      other is NoteEditorArgs &&
      other.noteId == noteId &&
      other.text == text &&
      other.folderId == folderId &&
      other.tag == tag &&
      other.session == session;

  @override
  int get hashCode => Object.hash(noteId, text, folderId, tag, session);
}

/// Header overline: "Saving…" while a write is pending, "AUTO-SAVED" after.
enum NoteSaveStatus { saved, saving, failed }

/// Editor content to persist (title + Quill Delta JSON).
@immutable
class NoteDraft {
  const NoteDraft({required this.title, required this.deltaJson});

  final String title;
  final String deltaJson;

  @override
  bool operator ==(Object other) =>
      other is NoteDraft &&
      other.title == title &&
      other.deltaJson == deltaJson;

  @override
  int get hashCode => Object.hash(title, deltaJson);
}

@immutable
class NoteEditorState {
  const NoteEditorState({
    required this.noteId,
    required this.createdHere,
    this.status = NoteSaveStatus.saved,
    this.unlocked = false,
  });

  final String noteId;

  /// Created by this editor session (discarded on back when still empty).
  final bool createdHere;
  final NoteSaveStatus status;

  /// A locked note was opened with the vault PIN in this session.
  final bool unlocked;

  NoteEditorState copyWith({NoteSaveStatus? status, bool? unlocked}) =>
      NoteEditorState(
        noteId: noteId,
        createdHere: createdHere,
        status: status ?? this.status,
        unlocked: unlocked ?? this.unlocked,
      );
}
