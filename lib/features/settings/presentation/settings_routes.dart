/// Routes owned by the settings feature (screens 30–32, 36 + sub-pages).
library;

import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

/// Root of the Settings tab branch; [children] are sub-pages other
/// features register (backup, vault security).
GoRoute settingsTabRoute(List<RouteBase> children) => GoRoute(
  path: AppRoutes.settings,
  builder: (context, state) => const PlaceholderScreen('Settings'),
  routes: [...settingsChildRoutes, ...children],
);

/// `/settings/<page>` sub-pages owned by this feature.
final List<RouteBase> settingsChildRoutes = [
  for (final (path, title) in const [
    ('notifications', 'Notifications & Reminders'),
    ('appearance', 'Appearance'),
    ('account', 'Account & profile'),
    ('general', 'General'),
    ('home-layout', 'Home layout & widgets'),
    ('gestures', 'Gestures & swipe actions'),
    ('sounds-haptics', 'Sounds & haptics'),
    ('app-lock', 'App lock'),
    ('tags-folders', 'Tags & folders'),
    ('storage', 'Storage'),
    ('about', 'About'),
  ])
    GoRoute(path: path, builder: (context, state) => PlaceholderScreen(title)),
  GoRoute(
    path: 'modules/:module',
    builder: (context, state) =>
        PlaceholderScreen('Module', detail: state.pathParameters['module']),
  ),
];
