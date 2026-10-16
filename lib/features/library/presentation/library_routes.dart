/// Routes owned by the library feature (screen 05, tab 2) + the mixed
/// collections (Pinned, Favourites, Tags & Folders, one tag).
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/library/presentation/providers/library_providers.dart';
import 'package:focusflow/features/library/presentation/screens/library_collection_screen.dart';
import 'package:focusflow/features/library/presentation/screens/library_screen.dart';
import 'package:focusflow/features/library/presentation/screens/tags_folders_screen.dart';
import 'package:go_router/go_router.dart';

/// Root of the Library tab branch; [children] are the module lists that
/// other features register (they stay inside the tab, bar visible).
GoRoute libraryTabRoute(List<RouteBase> children) => GoRoute(
  path: AppRoutes.library,
  builder: (context, state) => const LibraryScreen(),
  routes: [...libraryCollectionRoutes, ...children],
);

/// `/library/pinned`, `/library/favourites`, `/library/tags[/:tagId]`.
final List<RouteBase> libraryCollectionRoutes = [
  GoRoute(
    path: 'pinned',
    builder: (context, state) =>
        const LibraryCollectionScreen(kind: LibraryCollection.pinned),
  ),
  GoRoute(
    path: 'favourites',
    builder: (context, state) =>
        const LibraryCollectionScreen(kind: LibraryCollection.favourites),
  ),
  GoRoute(
    path: 'tags',
    builder: (context, state) => const TagsFoldersScreen(),
    routes: [
      GoRoute(
        path: ':tagId',
        builder: (context, state) =>
            LibraryCollectionScreen.tag(state.pathParameters['tagId']!),
      ),
    ],
  ),
];
