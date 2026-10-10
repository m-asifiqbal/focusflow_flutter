/// Routes owned by the insights feature (screen 25, tab 3).
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

/// Root of the Insights tab branch.
final GoRoute insightsTabRoute = GoRoute(
  path: AppRoutes.insights,
  builder: (context, state) => const PlaceholderScreen('Insights'),
);
