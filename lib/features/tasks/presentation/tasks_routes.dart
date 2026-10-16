/// Routes owned by the tasks feature (screens 10 list, 11 editor).
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/features/tasks/presentation/screens/task_editor_screen.dart';
import 'package:focusflow/features/tasks/presentation/screens/tasks_list_screen.dart';
import 'package:focusflow/features/tasks/presentation/state/task_editor_state.dart';
import 'package:go_router/go_router.dart';

/// `/library/tasks`.
final List<RouteBase> tasksLibraryRoutes = [
  GoRoute(path: 'tasks', builder: (context, state) => const TasksListScreen()),
];

/// `/tasks/new?title=&date=&time=&priority=&tag=&rrule=` and `/tasks/:id`.
final List<RouteBase> tasksRootRoutes = [
  GoRoute(
    path: '/tasks/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) {
      final args = TaskEditorArgs.fromRoute(
        state.pathParameters['id'] ?? 'new',
        state.uri.queryParameters,
      );
      return TaskEditorScreen(key: ValueKey(args), args: args);
    },
  ),
];
