/// ============================================================
/// PRAYERS ROUTES — the Prayer page and its screens, over everything
/// ============================================================
///
/// `/prayers` is pushed over everything (Library, Home, Insights, a
/// notification); Prayer has no tab of its own. The fixed paths come before
/// `/prayers/:id` so they match first.
/// ============================================================
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/presentation/screens/prayer_editor_screen.dart';
import 'package:focusflow/features/prayers/presentation/screens/prayer_screen.dart';
import 'package:focusflow/features/prayers/presentation/screens/prayer_settings_screen.dart';
import 'package:focusflow/features/prayers/presentation/screens/prayer_setup_screen.dart';
import 'package:go_router/go_router.dart';

/// `/prayers`, `/prayers/new`, `/prayers/setup`, `/prayers/settings`,
/// `/prayers/:id` (editor).
final List<RouteBase> prayersRootRoutes = [
  GoRoute(
    path: AppRoutes.prayers,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const PrayerScreen(),
  ),
  GoRoute(
    path: AppRoutes.newPrayer,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => PrayerEditorScreen(
      initial: state.extra is Prayer ? state.extra! as Prayer : null,
    ),
  ),
  GoRoute(
    path: AppRoutes.prayerSetup,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const PrayerSetupScreen(),
  ),
  GoRoute(
    path: AppRoutes.prayerSettings,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const PrayerSettingsScreen(),
  ),
  GoRoute(
    path: '/prayers/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        PrayerEditorScreen(prayerId: state.pathParameters['id']),
  ),
];
