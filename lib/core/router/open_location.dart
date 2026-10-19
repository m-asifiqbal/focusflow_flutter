/// ============================================================
/// OPEN LOCATION — a drill-in that never duplicates the tab shell
/// ============================================================
///
/// What: [OpenLocation.openLocation] opens a location the way the screen it
/// is called from can afford — `push` (back returns here) for full-screen
/// routes and for tab pages while the tab bar is showing, `go` (switch to the
/// tab) for a tab page requested from a full-screen route.
///
/// Why: Library lists and some Settings pages are declared inside the
/// `StatefulShellRoute` (they show the tab bar). go_router merges a pushed
/// shell page into the shell only when the shell is the top-most route; with
/// a full-screen route above it (notification centre, search, calendar, an
/// editor) it stacks a *second* shell with the same page key — Flutter
/// asserts in debug and the app shows a blank screen in release (the "View"
/// button on "2 tasks are overdue" in the notification centre). `go` is the
/// supported way to reach such a page, and what a tap on the system
/// notification already does. Pages that declare the root navigator
/// (`parentNavigatorKey: rootNavigatorKey` — editors, the vault, Archive,
/// most Settings pages) are safe to push from anywhere and keep their
/// back-to-where-you-were behaviour.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

/// Whether go_router can push a shell page right now: the top-most route is
/// the tab shell (no full-screen page above it).
bool tabShellIsTopmost(GoRouter router) {
  final matches = router.routerDelegate.currentConfiguration.matches;
  return matches.isNotEmpty && matches.last is ShellRouteMatch;
}

/// Whether [location] is a page *inside* the tab shell (a Library list, the
/// Settings pages that keep the tab bar …), as opposed to a full-screen page
/// on the root navigator. Decided by the router's own route table, so it can
/// never drift from the routes.
bool isShellPage(GoRouter router, String location) {
  final uri = Uri.tryParse(location);
  if (uri == null) return false;
  final matches = router.configuration.findMatch(uri).matches;
  return matches.isNotEmpty && matches.last is ShellRouteMatch;
}

extension OpenLocation on BuildContext {
  /// Opens [location] as a drill-in where that is possible (see the library
  /// comment), otherwise switches to its tab.
  void openLocation(String location) {
    final router = GoRouter.of(this);
    if (isShellPage(router, location) && !tabShellIsTopmost(router)) {
      router.go(location);
    } else {
      unawaited(router.push<void>(location));
    }
  }
}
