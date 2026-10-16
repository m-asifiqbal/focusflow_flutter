/// Routes owned by the search feature (screen 06).
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/features/search/presentation/screens/search_screen.dart';
import 'package:go_router/go_router.dart';

/// `/search?q=` (full screen).
final List<RouteBase> searchRootRoutes = [
  GoRoute(
    path: AppRoutes.search,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        SearchScreen(initialQuery: state.uri.queryParameters['q']),
  ),
];
