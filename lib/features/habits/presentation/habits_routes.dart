/// Routes owned by the habits feature (screens 14 list, 15 editor, 16 detail).
library;

import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/features/habits/presentation/screens/habit_detail_screen.dart';
import 'package:focusflow/features/habits/presentation/screens/habit_editor_screen.dart';
import 'package:focusflow/features/habits/presentation/screens/habits_list_screen.dart';
import 'package:go_router/go_router.dart';

/// `/library/habits`.
final List<RouteBase> habitsLibraryRoutes = [
  GoRoute(
    path: 'habits',
    builder: (context, state) => const HabitsListScreen(),
  ),
];

/// `/habits/new?name=`, `/habits/:id` (detail), `/habits/:id/edit`.
final List<RouteBase> habitsRootRoutes = [
  GoRoute(
    path: '/habits/new',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        HabitEditorScreen(initialName: state.uri.queryParameters['name']),
  ),
  GoRoute(
    path: '/habits/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        HabitDetailScreen(habitId: state.pathParameters['id']!),
    routes: [
      GoRoute(
        path: 'edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            HabitEditorScreen(habitId: state.pathParameters['id']),
      ),
    ],
  ),
];
