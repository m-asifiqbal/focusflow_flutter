/// Routes owned by the library feature (screen 05, tab 2) + the mixed
/// collections (Pinned, Favourites, Tags).
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

/// Root of the Library tab branch; [children] are the module lists that
/// other features register (they stay inside the tab, bar visible).
GoRoute libraryTabRoute(List<RouteBase> children) => GoRoute(
  path: AppRoutes.library,
  builder: (context, state) => const PlaceholderScreen('Library'),
  routes: [...libraryCollectionRoutes, ...children],
);

/// `/library/pinned`, `/library/favourites`, `/library/tags[/:tagId]`.
final List<RouteBase> libraryCollectionRoutes = [
  GoRoute(
    path: 'pinned',
    builder: (context, state) => const PlaceholderScreen('Pinned'),
  ),
  GoRoute(
    path: 'favourites',
    builder: (context, state) => const PlaceholderScreen('Favourites'),
  ),
  GoRoute(
    path: 'tags',
    builder: (context, state) => const PlaceholderScreen('Tags & Folders'),
    routes: [
      GoRoute(
        path: ':tagId',
        builder: (context, state) =>
            PlaceholderScreen('Tag', detail: state.pathParameters['tagId']),
      ),
    ],
  ),
];
