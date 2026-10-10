/// Routes owned by the vault feature (screens 17–22) and Settings › Vault
/// security (33).
library;

import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/core/router/placeholder_screen.dart';
import 'package:go_router/go_router.dart';

/// `/library/vault` — lock gate, then the inner tabs
/// (Vault · Generator · Favourites · Security).
final List<RouteBase> vaultLibraryRoutes = [
  GoRoute(
    path: 'vault',
    builder: (context, state) => const PlaceholderScreen('Vault'),
  ),
];

/// `/vault/new?type=`, `/vault/item/:id`, `/vault/item/:id/edit`.
final List<RouteBase> vaultRootRoutes = [
  GoRoute(
    path: '/vault/new',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const PlaceholderScreen('New vault item'),
  ),
  GoRoute(
    path: '/vault/item/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        PlaceholderScreen('Vault item', detail: state.pathParameters['id']),
    routes: [
      GoRoute(
        path: 'edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) => PlaceholderScreen(
          'Edit vault item',
          detail: state.pathParameters['id'],
        ),
      ),
    ],
  ),
];

/// `/settings/vault-security` (screen 33).
final List<RouteBase> vaultSettingsRoutes = [
  GoRoute(
    path: 'vault-security',
    builder: (context, state) => const PlaceholderScreen('Vault security'),
  ),
];
