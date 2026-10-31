/// ============================================================
/// SHARED NOTE INTAKE — "Share → FocusFlow" saves a new note
/// ============================================================
///
/// What: listens to [ShareIntake] (core/platform/share_intake.dart) and saves
/// every share as a new note right away — the link (or text) in the body,
/// the page title as the title ([SharedNote]) — then reports the new note's
/// id so the app can open it. Started once by the app startup host.
/// Why: sharing is a capture gesture: the note must exist even if the user
/// switches straight back to the other app, so it is saved before anything
/// is shown, not left as an unsaved editor draft.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/platform/share_intake.dart';
import 'package:focusflow/core/utils/app_logger.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/features/notes/domain/services/shared_note.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

class SharedNoteIntake {
  SharedNoteIntake(this._intake, this._notes);

  final ShareIntake _intake;
  final NotesRepository _notes;

  /// Saves shares from now on (and those that started the app); [onSaved]
  /// gets each new note's id.
  Future<void> start(void Function(String noteId) onSaved) async {
    _intake.listen((share) => unawaited(_save(share, onSaved)));
    for (final share in await _intake.initial()) {
      await _save(share, onSaved);
    }
  }

  void stop() => _intake.stopListening();

  /// Saves [share] as a note; its id, or null when there was nothing to keep.
  Future<String?> save(SharedText share) async {
    final note = SharedNote.from(share.text, subject: share.subject);
    if (note == null) return null;
    return _notes.createEmpty(
      title: note.title,
      initialText: note.plainText,
      initialDelta: note.deltaJson,
    );
  }

  Future<void> _save(
    SharedText share,
    void Function(String noteId) onSaved,
  ) async {
    try {
      final id = await save(share);
      if (id != null) onSaved(id);
    } catch (e, st) {
      // Never log the shared text itself (it may be private).
      AppLogger.e('Saving a shared note failed', error: e, stackTrace: st);
    }
  }
}

final sharedNoteIntakeProvider = Provider<SharedNoteIntake>(
  (ref) => SharedNoteIntake(
    ref.watch(shareIntakeProvider),
    ref.watch(notesRepositoryProvider),
  ),
);
