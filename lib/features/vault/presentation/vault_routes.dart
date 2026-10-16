/// Routes owned by the vault feature (screens 17–22) and Settings › Vault
/// security (33).
library;

import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/features/vault/presentation/screens/vault_item_detail_screen.dart';
import 'package:focusflow/features/vault/presentation/screens/vault_item_editor_screen.dart';
import 'package:focusflow/features/vault/presentation/screens/vault_screen.dart';
import 'package:focusflow/features/vault/presentation/screens/vault_security_settings_screen.dart';
import 'package:go_router/go_router.dart';

/// `/library/vault` — lock gate, then the inner tabs
/// (Vault · Generator · Favourites · Security). Full screen on the root
/// navigator: the vault has its own tab bar instead of the app's.
final List<RouteBase> vaultLibraryRoutes = [
  GoRoute(
    path: 'vault',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const VaultScreen(),
  ),
];

/// `/vault/new?type=`, `/vault/item/:id`, `/vault/item/:id/edit`.
final List<RouteBase> vaultRootRoutes = [
  GoRoute(
    path: '/vault/new',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => VaultItemEditorScreen(
      type: VaultItemEditorScreen.typeFromQuery(
        state.uri.queryParameters['type'],
      ),
    ),
  ),
  GoRoute(
    path: '/vault/item/:id',
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) =>
        VaultItemDetailScreen(id: state.pathParameters['id']!),
    routes: [
      GoRoute(
        path: 'edit',
        parentNavigatorKey: rootNavigatorKey,
        builder: (context, state) =>
            VaultItemEditorScreen(id: state.pathParameters['id']),
      ),
    ],
  ),
];

/// `/settings/vault-security` (screen 33).
final List<RouteBase> vaultSettingsRoutes = [
  GoRoute(
    path: 'vault-security',
    // Full-screen drill-in above the tab bar like the other settings
    // sub-pages (mockup 33); the path stays /settings/vault-security.
    parentNavigatorKey: rootNavigatorKey,
    builder: (context, state) => const VaultSecuritySettingsScreen(),
  ),
];
