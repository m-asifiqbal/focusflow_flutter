/// Routes owned by the onboarding feature (screen 01).
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/features/onboarding/presentation/screens/onboarding_screen.dart';
import 'package:go_router/go_router.dart';

final List<RouteBase> onboardingRootRoutes = [
  GoRoute(
    path: AppRoutes.onboarding,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const OnboardingScreen(),
  ),
];
