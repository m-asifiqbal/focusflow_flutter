/// ============================================================
/// PRAYERS ROUTES — the Prayer tab and the screens over everything
/// ============================================================
///
/// `/prayer` is the root of the Prayer tab branch (registered always; the
/// tab bar shows it only when Settings › Prayer › "Show Prayer as a tab"
/// is on). `/prayers` is the same screen pushed over everything (Library,
/// Home, a notification) — so it works whether or not the tab is shown.
/// The fixed paths come before `/prayers/:id` so they match first.
/// ============================================================
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/features/prayers/presentation/screens/prayer_editor_screen.dart';
import 'package:focusflow/features/prayers/presentation/screens/prayer_screen.dart';
import 'package:focusflow/features/prayers/presentation/screens/prayer_settings_screen.dart';
import 'package:focusflow/features/prayers/presentation/screens/prayer_setup_screen.dart';
import 'package:go_router/go_router.dart';

/// Root of the Prayer tab branch.
final GoRoute prayerTabRoute = GoRoute(
  path: AppRoutes.prayer,
  builder: (context, state) => const PrayerScreen(),
);

/// `/prayers`, `/prayers/new`, `/prayers/setup`, `/prayers/settings`,
/// `/prayers/:id` (editor).
final List<RouteBase> prayersRootRoutes = [
  GoRoute(
    path: AppRoutes.prayers,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const PrayerScreen(asPage: true),
  ),
  GoRoute(
    path: AppRoutes.newPrayer,
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const PrayerEditorScreen(),
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
