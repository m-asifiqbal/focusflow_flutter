/// Routes owned by the notes feature (screens 07 list, 08 editor).
library;

import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/core/router/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

/// `/library/notes` (inside the Library tab).
final List<RouteBase> notesLibraryRoutes = [
  GoRoute(
    path: 'notes',
    builder: (context, state) => const PlaceholderScreen('Notes'),
  ),
];

/// `/notes/new?text=&folderId=&tag=` and `/notes/:id` (full screen).
final List<RouteBase> notesRootRoutes = [
  GoRoute(
    path: '/notes/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => PlaceholderScreen(
      'Note editor',
      detail: state.pathParameters['id'],
    ),
  ),
];
