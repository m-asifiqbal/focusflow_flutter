/// Routes owned by the notes feature (screens 07 list, 08 editor).
library;

import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/features/notes/presentation/screens/note_editor_screen.dart';
import 'package:focusflow/features/notes/presentation/screens/notes_list_screen.dart';
import 'package:go_router/go_router.dart';

/// `/library/notes` (inside the Library tab).
final List<RouteBase> notesLibraryRoutes = [
  GoRoute(
    path: 'notes',
    builder: (context, state) =>
        NotesListScreen(folderId: state.uri.queryParameters['folderId']),
  ),
];

/// `/notes/new?text=&folderId=&tag=` and `/notes/:id` (full screen).
/// `/notes/new` is listed first so it never matches `:id`.
final List<RouteBase> notesRootRoutes = [
  GoRoute(
    path: '/notes/new',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) {
      final q = state.uri.queryParameters;
      return NoteEditorScreen(
        key: state.pageKey,
        text: q['text'],
        folderId: q['folderId'],
        tag: q['tag'],
      );
    },
  ),
  GoRoute(
    path: '/notes/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => NoteEditorScreen(
      key: state.pageKey,
      noteId: state.pathParameters['id'],
    ),
  ),
];
