/// Routes owned by the habits feature (screens 14 list, 15 editor, 16 detail).
library;

import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/core/router/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

/// `/library/habits`.
final List<RouteBase> habitsLibraryRoutes = [
  GoRoute(
    path: 'habits',
    builder: (context, state) => const PlaceholderScreen('Habits'),
  ),
];

/// `/habits/new?name=`, `/habits/:id` (detail), `/habits/:id/edit`.
final List<RouteBase> habitsRootRoutes = [
  GoRoute(
    path: '/habits/new',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const PlaceholderScreen('New habit'),
  ),
  GoRoute(
    path: '/habits/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        PlaceholderScreen('Habit detail', detail: state.pathParameters['id']),
    routes: [
      GoRoute(
        path: 'edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            PlaceholderScreen('Edit habit', detail: state.pathParameters['id']),
      ),
    ],
  ),
];
