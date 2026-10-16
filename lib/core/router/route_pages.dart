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
import 'package:focusflow/core/router/container_back_gesture.dart';
import 'package:focusflow/core/router/open_container_transition.dart';
import 'package:focusflow/core/router/open_origin.dart';
import 'package:go_router/go_router.dart';

/// A [MaterialPage] whose route keeps the page *underneath* still when it
/// grows out of a tapped card. A normal push slides the old page a third of
/// the way left (parallax); next to a card-to-details container that looks
/// like two unrelated motions, so such a route declines to transition from it.
class FFPage<T> extends MaterialPage<T> {
  const FFPage({
    required super.child,
    super.key,
    super.name,
    super.arguments,
    super.restorationId,
  });

  @override
  Route<T> createRoute(BuildContext context) => _FFPageRoute<T>(page: this);
}

// Page-based twin of MaterialPageRoute (same as the framework's private one).
class _FFPageRoute<T> extends PageRoute<T>
    with MaterialRouteTransitionMixin<T>
    implements OpenContainerRoute {
  _FFPageRoute({required FFPage<T> page})
    : super(settings: page, allowSnapshotting: page.allowSnapshotting) {
    assert(opaque);
  }

  FFPage<T> get _page => settings as FFPage<T>;

  @override
  Widget buildContent(BuildContext context) => _page.child;

  @override
  bool get maintainState => _page.maintainState;

  @override
  bool get fullscreenDialog => _page.fullscreenDialog;

  @override
  String get debugLabel => '${super.debugLabel}(${_page.name})';

  @override
  bool canTransitionFrom(TransitionRoute<dynamic> previousRoute) =>
      FFOpenOrigin.claim(this) == null;

  // ── edge swipe-back for container pages (see ContainerBackGesture) ──

  @override
  bool get backGestureEnabled {
    if (isFirst || willHandlePopInternally) return false;
    if (popDisposition == RoutePopDisposition.doNotPop) return false;
    final nav = navigator;
    final primary = animation;
    final secondary = secondaryAnimation;
    if (nav == null || primary == null || secondary == null) return false;
    return primary.isCompleted &&
        secondary.isDismissed &&
        !nav.userGestureInProgress;
  }

  @override
  void backGestureStart() => navigator?.didStartUserGesture();

  @override
  void backGestureTo(double value) => controller?.value = value;

  @override
  void backGestureEnd({required bool pop}) {
    final nav = navigator;
    final c = controller;
    if (nav == null || c == null) return;
    if (pop) {
      nav.pop();
    } else {
      final ms = (240 * (1 - c.value)).round().clamp(60, 240);
      c.animateTo(
        1,
        duration: Duration(milliseconds: ms),
        curve: Curves.easeOut,
      );
    }
    // Keep the gesture "in progress" until the settle finishes, so the page
    // stays input-blocked and its transition doesn't change mid-flight.
    if (c.isAnimating) {
      late AnimationStatusListener done;
      done = (_) {
        nav.didStopUserGesture();
        c.removeStatusListener(done);
      };
      c.addStatusListener(done);
    } else {
      nav.didStopUserGesture();
    }
  }

  // A container opens a touch quicker than a slide and closes quicker still
  // (the way home should feel decisive).
  @override
  Duration get transitionDuration => FFOpenOrigin.claim(this) == null
      ? super.transitionDuration
      : OpenContainerTransition.opening;

  @override
  Duration get reverseTransitionDuration => FFOpenOrigin.claim(this) == null
      ? super.reverseTransitionDuration
      : OpenContainerTransition.closing;
}

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
            : (context, state) => FFPage<void>(
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
