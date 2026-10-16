/// ============================================================
/// ROUTE PAGES — explicit Material pages for every GoRoute
/// ============================================================
///
/// Why: go_router 18 decides between Material / Cupertino / "no transition"
/// pages by looking for a `MaterialApp` from the new `material_ui` package.
/// Flutter's own `MaterialApp` doesn't match, so every route silently became
/// a zero-duration `NoTransitionPage` — no screen transition ever ran.
/// [withMaterialPages] rebuilds each `GoRoute(builder:)` with a real
/// `MaterialPage`, which takes its animation from the theme's
/// `pageTransitionsTheme` (core/router/page_transitions.dart): slide in /
/// slide out with swipe-back, and the open-container grow from a tapped card.
///
/// Routes that already have a `pageBuilder`, and redirect-only routes, are
/// left alone; shell routes keep their (persistent, transition-less) page.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// [routes] (recursively) with Material pages.
List<RouteBase> withMaterialPages(List<RouteBase> routes) => [
  for (final r in routes) _withMaterialPage(r),
];

RouteBase _withMaterialPage(RouteBase route) {
  if (route is! GoRoute) return route;
  final builder = route.builder;
  return GoRoute(
    path: route.path,
    name: route.name,
    caseSensitive: route.caseSensitive,
    parentNavigatorKey: route.parentNavigatorKey,
    redirect: route.redirect,
    onExit: route.onExit,
    routes: withMaterialPages(route.routes),
    pageBuilder:
        route.pageBuilder ??
        (builder == null
            ? null
            : (context, state) => MaterialPage<void>(
                key: state.pageKey,
                name: state.name ?? state.path,
                arguments: <String, String>{
                  ...state.pathParameters,
                  ...state.uri.queryParameters,
                },
                restorationId: state.pageKey.value,
                child: builder(context, state),
              )),
  );
}
