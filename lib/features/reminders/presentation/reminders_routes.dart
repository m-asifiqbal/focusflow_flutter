/// Routes owned by the reminders feature (screens 12 list, 13 editor).
library;

import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/features/reminders/presentation/screens/reminder_editor_screen.dart';
import 'package:focusflow/features/reminders/presentation/screens/reminders_list_screen.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_editor_state.dart';
import 'package:go_router/go_router.dart';

/// `/library/reminders`.
final List<RouteBase> remindersLibraryRoutes = [
  GoRoute(
    path: 'reminders',
    builder: (context, state) => const RemindersListScreen(),
  ),
];

/// `/reminders/new?title=&at=&rrule=&linkType=&linkId=` and `/reminders/:id`.
final List<RouteBase> remindersRootRoutes = [
  GoRoute(
    path: '/reminders/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) {
      final args = ReminderEditorArgs.fromRoute(
        state.pathParameters['id'] ?? 'new',
        state.uri.queryParameters,
      );
      return ReminderEditorScreen(key: ValueKey(args), args: args);
    },
  ),
];
