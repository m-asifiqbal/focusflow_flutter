/// Routes owned by the settings feature (screens 30–32 + sub-pages).
/// Account & profile (36) lives in auth_routes.dart (auth feature).
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:flutter/widgets.dart';
import 'package:focusflow/features/settings/presentation/screens/about_settings_screen.dart';
import 'package:focusflow/features/settings/presentation/screens/app_lock_settings_screen.dart';
import 'package:focusflow/features/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:focusflow/features/settings/presentation/screens/general_settings_screen.dart';
import 'package:focusflow/features/settings/presentation/screens/gestures_settings_screen.dart';
import 'package:focusflow/features/settings/presentation/screens/home_layout_settings_screen.dart';
import 'package:focusflow/features/settings/presentation/screens/module_settings_screen.dart';
import 'package:focusflow/features/settings/presentation/screens/sounds_haptics_settings_screen.dart';
import 'package:focusflow/features/settings/presentation/screens/storage_settings_screen.dart';
import 'package:focusflow/features/settings/presentation/screens/tags_folders_settings_screen.dart';
import 'package:focusflow/features/settings/presentation/screens/notifications_settings_screen.dart';
import 'package:focusflow/features/settings/presentation/screens/settings_screen.dart';
import 'package:go_router/go_router.dart';

/// Root of the Settings tab branch; [children] are sub-pages other
/// features register (backup, vault security).
GoRoute settingsTabRoute(List<RouteBase> children) => GoRoute(
  path: AppRoutes.settings,
  builder: (context, state) => const SettingsScreen(),
  routes: [...settingsChildRoutes, ...children],
);

/// `/settings/<page>` sub-pages owned by this feature.
final List<RouteBase> settingsChildRoutes = [
  GoRoute(
    path: 'notifications',
    // Full-screen drill-in above the tab bar (mockup 31); the path stays
    // /settings/notifications.
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const NotificationsSettingsScreen(),
  ),
  GoRoute(
    path: 'appearance',
    // Full-screen drill-in (mockup 32 has no tab bar).
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const AppearanceSettingsScreen(),
  ),
  for (final (path, screen) in <(String, Widget)>[
    ('general', const GeneralSettingsScreen()),
    ('home-layout', const HomeLayoutSettingsScreen()),
    ('gestures', const GesturesSettingsScreen()),
    ('sounds-haptics', const SoundsHapticsSettingsScreen()),
    ('app-lock', const AppLockSettingsScreen()),
    ('tags-folders', const TagsFoldersSettingsScreen()),
    ('storage', const StorageSettingsScreen()),
    ('about', const AboutSettingsScreen()),
  ])
    GoRoute(
      path: path,
      // Full-screen drill-ins like 31–33 (no tab bar).
      parentNavigatorKey: rootNavigatorKey,
      builder: (context, state) => screen,
    ),
  GoRoute(
    path: 'modules/:module',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        ModuleSettingsScreen(module: state.pathParameters['module'] ?? ''),
  ),
];
