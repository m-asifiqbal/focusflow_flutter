/// Screen 36 — Account & profile: mockup captures (light / dark), the
/// signed-out variant, the focus-goal editor and
/// Erase local data (type DELETE → back to onboarding), plus no overflow
/// at 360 pt / text scale 1.3.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_router.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/cloud_account_controller.dart';
import 'package:focusflow/features/auth/presentation/providers/account_providers.dart';
import 'package:focusflow/features/auth/presentation/screens/account_screen.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';
import '../auth_test_support.dart';

final _now = DateTime(2026, 10, 13, 9, 41);

class _FixedAccount extends CloudAccountNotifier {
  _FixedAccount(this.account);

  final CloudAccount? account;

  @override
  CloudAccount? build() => account;
}

const _asif = CloudAccount(
  provider: CloudProvider.google,
  email: 'asif.design@gmail.com',
  displayName: 'Asif Iqbal',
);

void main() {
  setUpAll(loadAppFonts);

  Future<TestHarness> harness(
    WidgetTester tester, {
    CloudAccount? account = _asif,
  }) async {
    final fakes = AuthFakes();
    final h = (await tester.runAsync(
      () => authHarness(
        fakes,
        now: _now,
        overrides: [
          cloudAccountProvider.overrideWith(() => _FixedAccount(account)),
          deviceTimeZoneProvider.overrideWith((ref) async => 'Asia/Dhaka'),
          accountStatsProvider.overrideWith(
            (ref) => const AsyncData(
              AccountStats(items: 113, bestStreak: 45, daysActive: 142),
            ),
          ),
          if (account != null)
            linkedDevicesProvider.overrideWith(
              (ref) async => LinkedDevices([
                const DeviceEntry(
                  deviceId: TestHarness.deviceId,
                  name: 'Pixel 8 Pro',
                  platform: 'Android 15',
                  isThisDevice: true,
                ),
                DeviceEntry(
                  deviceId: 'iphone',
                  name: 'iPhone 15',
                  platform: 'iOS 18',
                  lastSyncAt: _now.subtract(const Duration(hours: 3)),
                ),
              ]),
            ),
        ],
      ),
    ))!;
    addTearDown(() async {
      await tester.runAsync(h.dispose);
      if (fakes.dir.existsSync()) fakes.dir.deleteSync(recursive: true);
    });
    await tester.runAsync(
      () => h.updateSettings(
        (s) => s.copyWith(
          displayName: 'Asif',
          dailyFocusGoal: 7,
          accountMode: account == null
              ? AccountMode.offline
              : AccountMode.google,
        ),
      ),
    );
    return h;
  }

  String location(TestHarness h) =>
      h.read(routerProvider).routerDelegate.currentConfiguration.uri.toString();

  testWidgets('matches the mockup (light + dark captures)', (tester) async {
    final h = await harness(tester);
    await pumpApp(tester, h, AppRoutes.settingsAccount);
    expect(find.byType(AccountScreen), findsOneWidget);
    expect(find.text('Asif Iqbal'), findsOneWidget);
    expect(find.text('asif.design@gmail.com'), findsOneWidget);
    expect(find.text('113'), findsOneWidget);
    expect(find.text('7 tasks'), findsOneWidget);
    expect(find.text('Asia/Dhaka'), findsOneWidget);
    expect(find.text('Last synced 3h ago · iOS 18'), findsOneWidget);
    await captureScreen(tester, '36_account_profile');

    await tester.drag(find.byType(Scrollable).first, const Offset(0, -600));
    await settle(tester);
    expect(find.text('Delete account & Drive data'), findsOneWidget);
    await captureScreen(tester, '36_account_profile_bottom');

    await pumpApp(tester, h, AppRoutes.settingsAccount, dark: true);
    await captureScreen(tester, '36_account_profile_dark');
  });

  testWidgets('signed-out variant', (tester) async {
    final h = await harness(tester, account: null);
    await pumpApp(tester, h, AppRoutes.settingsAccount);
    expect(find.text('Asif'), findsWidgets);
    expect(find.text('Offline · data stays on this device'), findsOneWidget);
    expect(find.text('Connect Google Drive'), findsOneWidget);
    await captureScreen(tester, '36_account_signed_out');
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await settle(tester);
    expect(find.text('Erase local data'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    expect(find.text('Delete account & Drive data'), findsNothing);
  });

  testWidgets('daily focus goal editor saves to settings', (tester) async {
    final h = await harness(tester);
    await pumpApp(tester, h, AppRoutes.settingsAccount);
    await tester.tap(find.text('Daily focus goal'));
    await settle(tester);
    await tester.tap(find.bySemanticsLabel('More tasks'));
    await tester.pump();
    await tester.tap(find.text('Save'));
    await settle(tester);
    expect(h.read(settingsProvider).dailyFocusGoal, 8);
    expect(find.text('8 tasks'), findsOneWidget);
  });

  testWidgets('Erase local data needs DELETE, then returns to onboarding', (
    tester,
  ) async {
    final h = await harness(tester);
    await pumpApp(tester, h, AppRoutes.settingsAccount);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -900));
    await settle(tester);
    await tester.tap(find.text('Erase local data'));
    await settle(tester);
    expect(find.text('Erase local data?'), findsOneWidget);

    await tester.tap(find.text('Erase'));
    await settle(tester);
    expect(find.text('Erase local data?'), findsOneWidget, reason: 'disabled');

    await tester.enterText(find.byType(TextField).first, 'DELETE');
    await tester.pump();
    await tester.tap(find.text('Erase'));
    await settle(tester, rounds: 8);

    final s = h.read(settingsProvider);
    expect(s.onboardingSeen, isFalse);
    expect(s.accountMode, AccountMode.none);
    expect(location(h), AppRoutes.onboarding);
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    final h = await harness(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.settingsAccount,
      size: const Size(360, 800),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await tester.drag(find.byType(Scrollable).first, const Offset(0, -1500));
    await settle(tester);
    expect(tester.takeException(), isNull);
  });
}
