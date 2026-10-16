/// Routes owned by the calendar feature (screen 26).
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/features/calendar/domain/services/calendar_rules.dart';
import 'package:focusflow/features/calendar/presentation/screens/calendar_screen.dart';
import 'package:go_router/go_router.dart';

/// `/calendar?date=yyyy-MM-dd` (full screen). A missing or malformed date
/// opens on today.
final List<RouteBase> calendarRootRoutes = [
  GoRoute(
    path: AppRoutes.calendar,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => CalendarScreen(
      initialDay: CalendarRules.tryParseDay(state.uri.queryParameters['date']),
    ),
  ),
];
