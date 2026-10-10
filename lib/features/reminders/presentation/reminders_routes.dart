/// Routes owned by the reminders feature (screens 12 list, 13 editor).
library;

import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/core/router/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

/// `/library/reminders`.
final List<RouteBase> remindersLibraryRoutes = [
  GoRoute(
    path: 'reminders',
    builder: (context, state) => const PlaceholderScreen('Reminders'),
  ),
];

/// `/reminders/new?title=&at=&rrule=&linkType=&linkId=` and `/reminders/:id`.
final List<RouteBase> remindersRootRoutes = [
  GoRoute(
    path: '/reminders/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => PlaceholderScreen(
      'Reminder editor',
      detail: state.pathParameters['id'],
    ),
  ),
];
