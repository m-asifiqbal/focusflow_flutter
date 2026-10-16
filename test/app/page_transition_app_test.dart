/// Regression: go_router 18 only picks Material pages when it finds
/// material_ui's MaterialApp, so every route used to be a zero-duration
/// NoTransitionPage. core/router/route_pages.dart gives each route an
/// explicit MaterialPage; a real push in the running app must slide.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';

import '../helpers/screen_harness.dart';
import '../helpers/test_container.dart';

void main() {
  testWidgets('pushing a settings sub-page slides it in', (tester) async {
    await loadAppFonts();
    final h = (await tester.runAsync(
      () => TestHarness.create(now: DateTime(2026, 6, 13, 9, 41)),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await pumpApp(tester, h, AppRoutes.settings);
    h.read(routerProvider).push(AppRoutes.settingsAppearance);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 120));

    final page = find.text('Appearance').last.evaluate().first;
    final route = ModalRoute.of(page)!;
    expect(route.transitionDuration, greaterThan(Duration.zero));
    expect(
      find.ancestor(
        of: find.text('Appearance').last,
        matching: find.byType(CupertinoPageTransition),
      ),
      findsOneWidget,
    );
    await tester.pumpAndSettle();
  });
}
