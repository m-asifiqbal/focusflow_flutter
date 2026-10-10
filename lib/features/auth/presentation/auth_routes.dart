/// Routes owned by the auth feature (screen 02 — Sign in / Welcome).
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/core/router/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

final List<RouteBase> authRootRoutes = [
  GoRoute(
    path: AppRoutes.signIn,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => PlaceholderScreen(
      'Sign in',
      detail: 'intent=${state.uri.queryParameters['intent'] ?? 'none'}',
    ),
  ),
];
