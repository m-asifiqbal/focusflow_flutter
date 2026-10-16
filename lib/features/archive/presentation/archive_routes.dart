/// Routes owned by the archive feature (screens 23 Archive, 24 Recently
/// Deleted). They sit under the Library tab's path but are pushed on the
/// root navigator so they cover the shell (no tab bar / FAB): the mockups
/// show them full-screen with only the sticky Restore / Delete bar.
library;

import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/features/archive/presentation/screens/archive_screen.dart';
import 'package:focusflow/features/archive/presentation/screens/trash_screen.dart';
import 'package:go_router/go_router.dart';

/// `/library/archive`, `/library/trash` (full screen over the shell).
final List<RouteBase> archiveLibraryRoutes = [
  GoRoute(
    path: 'archive',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const ArchiveScreen(),
  ),
  GoRoute(
    path: 'trash',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const TrashScreen(),
  ),
];
