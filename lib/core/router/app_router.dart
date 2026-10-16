/// ============================================================
/// APP ROUTER — GoRouter composed from every feature's route file
/// ============================================================
///
/// Shape (master prompt §6):
/// ```
/// StatefulShellRoute (tab bar + centre FAB)
///   ├─ /home
///   ├─ /library ── notes · tasks · reminders · habits · vault · archive ·
///   │              trash · pinned · favourites · tags[/:tagId]
///   ├─ /insights
///   └─ /settings ── notifications · appearance · vault-security · backup ·
///                   import-export · account · …
/// Root navigator (covers the tab bar): editors, details, search, calendar,
///   notification centre, onboarding, sign-in, /item/:type/:id deep links.
/// ```
/// Each feature owns `features/<f>/presentation/<f>_routes.dart`; this file
/// only stitches them together and owns the launch redirect.
///
/// **Android analogy:** a Navigation graph with nested graphs per tab
/// (`NavHost` + `BottomNavigationView` saving each tab's back stack).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/router/app_shell.dart';
import 'package:focusflow/core/router/navigator_keys.dart';
import 'package:focusflow/core/router/page_transitions.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/archive/presentation/archive_routes.dart';
import 'package:focusflow/features/auth/presentation/auth_routes.dart';
import 'package:focusflow/features/backup/presentation/backup_routes.dart';
import 'package:focusflow/features/calendar/presentation/calendar_routes.dart';
import 'package:focusflow/features/habits/presentation/habits_routes.dart';
import 'package:focusflow/features/home/presentation/home_routes.dart';
import 'package:focusflow/features/insights/presentation/insights_routes.dart';
import 'package:focusflow/features/library/presentation/library_routes.dart';
import 'package:focusflow/features/notes/presentation/notes_routes.dart';
import 'package:focusflow/features/notifications_center/presentation/notifications_center_routes.dart';
import 'package:focusflow/features/onboarding/presentation/onboarding_routes.dart';
import 'package:focusflow/features/reminders/presentation/reminders_routes.dart';
import 'package:focusflow/features/search/presentation/search_routes.dart';
import 'package:focusflow/features/settings/presentation/settings_routes.dart';
import 'package:focusflow/features/tasks/presentation/tasks_routes.dart';
import 'package:focusflow/features/vault/presentation/vault_routes.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:go_router/go_router.dart';

/// Re-runs the redirect when onboarding/account state changes.
class _RouterRefresh extends ChangeNotifier {
  _RouterRefresh(Ref ref) {
    ref.listen<(bool, AccountMode)>(
      settingsProvider.select((s) => (s.onboardingSeen, s.accountMode)),
      (_, _) => notifyListeners(),
    );
  }
}

/// Launch-flow decision, extracted for unit tests.
@visibleForTesting
String? launchRedirect({
  required String location,
  required bool onboardingSeen,
}) {
  const launchPaths = {AppRoutes.onboarding, AppRoutes.signIn};
  if (!onboardingSeen && !launchPaths.contains(location)) {
    return AppRoutes.onboarding;
  }
  return null;
}

String startLocation(AppSettings s) {
  if (!s.onboardingSeen) return AppRoutes.onboarding;
  return switch (s.startScreen) {
    StartScreen.home => AppRoutes.home,
    StartScreen.library => AppRoutes.library,
    StartScreen.insights => AppRoutes.insights,
  };
}

final routerProvider = Provider<GoRouter>((ref) {
  final refresh = _RouterRefresh(ref);
  ref.onDispose(refresh.dispose);

  final router = GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: startLocation(ref.read(settingsProvider)),
    refreshListenable: refresh,
    debugLogDiagnostics: kDebugMode,
    redirect: (context, state) => launchRedirect(
      location: state.matchedLocation,
      onboardingSeen: ref.read(settingsProvider).onboardingSeen,
    ),
    routes: [
      StatefulShellRoute(
        builder: (context, state, shell) => AppShell(shell: shell),
        // Cross-fade between tabs, every tab's state kept alive.
        navigatorContainerBuilder: (context, shell, children) =>
            FFAnimatedBranchContainer(
              currentIndex: shell.currentIndex,
              children: children,
            ),
        branches: [
          StatefulShellBranch(routes: [homeTabRoute]),
          StatefulShellBranch(
            routes: [
              libraryTabRoute([
                ...notesLibraryRoutes,
                ...tasksLibraryRoutes,
                ...remindersLibraryRoutes,
                ...habitsLibraryRoutes,
                ...vaultLibraryRoutes,
                ...archiveLibraryRoutes,
              ]),
            ],
          ),
          StatefulShellBranch(routes: [insightsTabRoute]),
          StatefulShellBranch(
            routes: [
              settingsTabRoute([
                ...accountSettingsRoutes,
                ...backupSettingsRoutes,
                ...vaultSettingsRoutes,
              ]),
            ],
          ),
        ],
      ),
      ...onboardingRootRoutes,
      ...authRootRoutes,
      ...searchRootRoutes,
      ...calendarRootRoutes,
      ...notificationsCenterRootRoutes,
      ...notesRootRoutes,
      ...tasksRootRoutes,
      ...remindersRootRoutes,
      ...habitsRootRoutes,
      ...vaultRootRoutes,
      // focusflow://item/{type}/{id} → the item's editor/detail.
      GoRoute(
        path: '/item/:type/:id',
        parentNavigatorKey: rootNavigatorKey,
        redirect: (context, state) {
          final type = ItemType.fromKey(state.pathParameters['type']);
          final id = state.pathParameters['id'];
          if (type == null || id == null) return AppRoutes.home;
          return AppRoutes.open(ItemRef(type, id));
        },
      ),
    ],
  );
  ref.onDispose(router.dispose);
  return router;
});
