/// Routes owned by the home feature (screen 03, tab 1).
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

/// Root of the Home tab branch.
final GoRoute homeTabRoute = GoRoute(
  path: AppRoutes.home,
  builder: (context, state) => const PlaceholderScreen('Home'),
);
