/// Routes owned by the archive feature (screens 23 Archive, 24 Recently Deleted).
library;

import 'package:focusflow/core/router/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

/// `/library/archive`, `/library/trash`.
final List<RouteBase> archiveLibraryRoutes = [
  GoRoute(
    path: 'archive',
    builder: (context, state) => const PlaceholderScreen('Archive'),
  ),
  GoRoute(
    path: 'trash',
    builder: (context, state) => const PlaceholderScreen('Recently Deleted'),
  ),
];
