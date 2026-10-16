/// Routes owned by the notification centre feature (screen 27).
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/features/notifications_center/presentation/screens/notification_center_screen.dart';
import 'package:go_router/go_router.dart';

/// `/notifications` (full screen).
final List<RouteBase> notificationsCenterRootRoutes = [
  GoRoute(
    path: AppRoutes.notificationCenter,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const NotificationCenterScreen(),
  ),
];
