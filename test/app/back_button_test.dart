/// Android back button at the tab roots: another tab → Home first; on Home →
/// "Exit?" dialog (Stay keeps the app, Exit closes it). Pages and dialogs
/// above the shell still close first.
library;

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';

import '../helpers/screen_harness.dart';
import '../helpers/test_container.dart';

void main() {
  late TestHarness h;
  final platformCalls = <String>[];

  setUp(platformCalls.clear);

  Future<void> boot(WidgetTester tester, {String at = AppRoutes.home}) async {
    await loadAppFonts();
    h = (await tester.runAsync(
      () => TestHarness.create(now: DateTime(2026, 6, 13, 9, 41)),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        platformCalls.add(call.method);
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
    await pumpApp(tester, h, at);
  }

  Future<void> back(WidgetTester tester) async {
    await tester.binding.handlePopRoute();
    await settle(tester);
  }

  testWidgets('on Home, back asks before exiting; Stay keeps the app', (
    tester,
  ) async {
    await boot(tester);
    await back(tester);
    expect(find.text('Exit FocusFlow?'), findsOneWidget);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
    await tester.tap(find.text('Stay'));
    await settle(tester);
    expect(find.text('Exit FocusFlow?'), findsNothing);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
  });

  testWidgets('Exit in the dialog closes the app', (tester) async {
    await boot(tester);
    await back(tester);
    await tester.tap(find.text('Exit'));
    await settle(tester);
    expect(platformCalls, contains('SystemNavigator.pop'));
  });

  testWidgets('back while the dialog is open just closes it', (tester) async {
    await boot(tester);
    await back(tester);
    expect(find.text('Exit FocusFlow?'), findsOneWidget);
    await back(tester);
    expect(find.text('Exit FocusFlow?'), findsNothing);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
  });

  testWidgets('on another tab, back goes to Home first, then asks', (
    tester,
  ) async {
    await boot(tester, at: AppRoutes.settings);
    expect(find.text('Exit FocusFlow?'), findsNothing);
    await back(tester);
    // Home is showing now (its greeting is on screen), no dialog yet.
    expect(find.textContaining('Good '), findsWidgets);
    expect(find.text('Exit FocusFlow?'), findsNothing);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
    await back(tester);
    expect(find.text('Exit FocusFlow?'), findsOneWidget);
  });

  testWidgets('a pushed page closes before any of that', (tester) async {
    await boot(tester, at: AppRoutes.settingsAppearance);
    final router = h.read(routerProvider);
    expect(router.state.uri.path, AppRoutes.settingsAppearance);
    await back(tester);
    // Back on the Settings tab root, not exited, not asked.
    expect(router.state.uri.path, AppRoutes.settings);
    expect(find.text('Exit FocusFlow?'), findsNothing);
    expect(platformCalls, isNot(contains('SystemNavigator.pop')));
  });
}
