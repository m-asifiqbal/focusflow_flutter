/// Routes owned by the auth feature (screen 02 — Sign in / Welcome, and
/// screen 36 — Account & profile).
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/features/auth/presentation/screens/account_screen.dart';
import 'package:focusflow/features/auth/presentation/screens/sign_in_screen.dart';
import 'package:go_router/go_router.dart';

/// `/settings/account` — Account & profile (screen 36), in the Settings tab.
final List<RouteBase> accountSettingsRoutes = [
  GoRoute(
    path: 'account',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const AccountScreen(),
  ),
];

final List<RouteBase> authRootRoutes = [
  GoRoute(
    path: AppRoutes.signIn,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => SignInScreen(
      restoreIntent: state.uri.queryParameters['intent'] == 'restore',
    ),
  ),
];
