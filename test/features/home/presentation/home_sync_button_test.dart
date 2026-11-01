/// Home's floating Drive sync button: shown in the bottom start corner only
/// while a Google account is connected and Backup & Sync › "Sync button on
/// Home" is on (captured light / dark for a look).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/features/home/presentation/widgets/home_sync_button.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../../backup/backup_test_support.dart';
import '../../reminders/isolated_notifications.dart';
import '../home_seed.dart';

void main() {
  Future<TestHarness> boot(WidgetTester tester, CloudAccount? account) async {
    await loadAppFonts();
    final h = (await tester.runAsync(
      () => TestHarness.create(
        now: homeNow,
        overrides: [
          ...isolatedNotifications(),
          cloudAccountProvider.overrideWith(() => FixedAccount(account)),
        ],
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await tester.runAsync(() => seedHomeMockup(h));
    return h;
  }

  testWidgets('connected: the glass sync button sits bottom start', (
    tester,
  ) async {
    final h = await boot(tester, asifAccount);
    await pumpApp(tester, h, AppRoutes.home);
    expect(find.byType(HomeSyncButton), findsOneWidget);
    expect(find.bySemanticsLabel('Sync with Google Drive'), findsOneWidget);
    final button = tester.getRect(find.byType(HomeSyncButton));
    final screen = tester.getRect(find.byType(MaterialApp).first);
    // Start edge, in the lower part of the screen (above the tab bar).
    expect(button.left, lessThan(screen.width / 4));
    expect(button.center.dy, greaterThan(screen.height * 0.75));
    await captureScreen(tester, 'home_sync_button');

    await h.updateSettings((s) => s.copyWith(themeMode: ThemeMode.dark));
    await settle(tester);
    await captureScreen(tester, 'home_sync_button_dark');
  });

  testWidgets('connected but switched off: hidden, back when on', (
    tester,
  ) async {
    final h = await boot(tester, asifAccount);
    await tester.runAsync(
      () => h.updateSettings((s) => s.copyWith(homeSyncButton: false)),
    );
    await pumpApp(tester, h, AppRoutes.home);
    expect(find.byType(HomeSyncButton), findsNothing);

    await tester.runAsync(
      () => h.updateSettings((s) => s.copyWith(homeSyncButton: true)),
    );
    await settle(tester);
    expect(find.byType(HomeSyncButton), findsOneWidget);
  });

  testWidgets('not connected: no sync button', (tester) async {
    final h = await boot(tester, null);
    await pumpApp(tester, h, AppRoutes.home);
    expect(find.byType(HomeSyncButton), findsNothing);
  });
}
