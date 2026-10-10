/// Routes owned by the tasks feature (screens 10 list, 11 editor).
library;

import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/core/router/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

/// `/library/tasks`.
final List<RouteBase> tasksLibraryRoutes = [
  GoRoute(
    path: 'tasks',
    builder: (context, state) => const PlaceholderScreen('Tasks'),
  ),
];

/// `/tasks/new?title=&date=&time=&priority=&tag=&rrule=` and `/tasks/:id`.
final List<RouteBase> tasksRootRoutes = [
  GoRoute(
    path: '/tasks/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        PlaceholderScreen('Task editor', detail: state.pathParameters['id']),
  ),
];
