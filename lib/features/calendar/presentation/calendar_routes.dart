/// Routes owned by the calendar feature (screen 26).
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/core/router/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

/// `/calendar?date=yyyy-MM-dd` (full screen).
final List<RouteBase> calendarRootRoutes = [
  GoRoute(
    path: AppRoutes.calendar,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const PlaceholderScreen('Calendar'),
  ),
];
