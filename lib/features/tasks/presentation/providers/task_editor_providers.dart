/// ============================================================
/// TASK EDITOR PROVIDERS — live lookups for the editor's pickers
/// ============================================================
///
/// What: notes the "Linked note" picker can link (live, filtered by the
/// search text). Lists and tags reuse `taskListsProvider` /
/// `allTagsProvider` from the tasks list providers.
/// Why: pickers read repositories only through providers (no repository
/// calls in widgets).
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/notes/domain/entities/note.dart';
import 'package:focusflow/features/notes/domain/repository/notes_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Active notes matching the search text (most recently edited first).
final linkableNotesProvider = StreamProvider.autoDispose
    .family<List<Note>, String>(
      (ref, text) => ref
          .watch(notesRepositoryProvider)
          .watchNotes(NotesQuery(text: text.trim(), limit: 60)),
    );
