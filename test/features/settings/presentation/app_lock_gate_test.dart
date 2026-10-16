/// AppLockGate lifecycle behaviour: one prompt per real background stint
/// (a cancelled prompt is never re-opened by its own resume), and the
/// app-switcher privacy cover on `inactive` (not while the OS prompt is up).
library;

import 'dart:async';
import 'dart:ui';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/features/settings/domain/services/device_authenticator.dart';
import 'package:focusflow/features/settings/domain/services/privacy_screen.dart';
import 'package:focusflow/features/settings/presentation/providers/app_lock_providers.dart';
import 'package:focusflow/features/settings/presentation/widgets/app_lock/app_lock_screen.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';

class _Auth implements DeviceAuthenticator {
  DeviceAuthResult next = DeviceAuthResult.cancelled;
  Completer<DeviceAuthResult>? hold;
  int prompts = 0;

  @override
  Future<bool> isSupported() async => true;

  @override
  Future<BiometricKind> biometricKind() async => BiometricKind.faceId;

  @override
  Future<DeviceAuthResult> authenticate(String reason) {
    prompts++;
    return hold?.future ?? Future.value(next);
  }
}

class _Privacy implements PrivacyScreen {
  @override
  Future<void> setEnabled(bool enabled, {required Color coverColor}) async {}
}

void main() {
  late TestHarness h;
  late _Auth auth;

  Future<void> setUp(WidgetTester tester, {required bool lock}) async {
    await loadAppFonts();
    auth = _Auth();
    h = (await tester.runAsync(
      () => TestHarness.create(
        now: DateTime(2026, 6, 12, 9, 41),
        overrides: [
          deviceAuthenticatorProvider.overrideWithValue(auth),
          privacyScreenProvider.overrideWithValue(_Privacy()),
        ],
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    await tester.runAsync(
      () => h.updateSettings(
        (s) => s.copyWith(appLockEnabled: lock, hideInAppSwitcher: true),
      ),
    );
  }

  Future<void> lifecycle(WidgetTester tester, List<AppLifecycleState> s) async {
    for (final state in s) {
      tester.binding.handleAppLifecycleStateChanged(state);
      await tester.pump();
    }
    await settle(tester);
  }

  const toBackground = [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ];
  const toForeground = [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ];

  testWidgets('a cancelled prompt is not re-opened by resume', (tester) async {
    await setUp(tester, lock: true);
    await pumpApp(tester, h, AppRoutes.settingsStorage);
    expect(auth.prompts, 1);
    expect(find.text('Unlock with Face ID'), findsOneWidget);
    // The prompt's own dismissal / Control Center: inactive -> resumed.
    await lifecycle(tester, [
      AppLifecycleState.inactive,
      AppLifecycleState.resumed,
    ]);
    expect(auth.prompts, 1);
    // Even a long background stint while already locked: no auto prompt.
    await lifecycle(tester, toBackground);
    h.clock.advance(AppLockController.grace * 2);
    await lifecycle(tester, toForeground);
    expect(auth.prompts, 1);
    expect(find.text('Unlock with Face ID'), findsOneWidget);
  });

  testWidgets('unlocked app re-locks and prompts once after the grace', (
    tester,
  ) async {
    await setUp(tester, lock: true);
    auth.next = DeviceAuthResult.success;
    await pumpApp(tester, h, AppRoutes.settingsStorage);
    expect(find.text('Unlock with Face ID'), findsNothing);
    auth.next = DeviceAuthResult.cancelled;
    await lifecycle(tester, toBackground);
    h.clock.advance(AppLockController.grace);
    await lifecycle(tester, toForeground);
    expect(auth.prompts, 2);
    expect(find.text('Unlock with Face ID'), findsOneWidget);
  });

  testWidgets('privacy cover on inactive, not while authenticating', (
    tester,
  ) async {
    await setUp(tester, lock: false);
    await pumpApp(tester, h, AppRoutes.settingsStorage);
    await lifecycle(tester, [AppLifecycleState.inactive]);
    expect(find.byType(PrivacyCover), findsOneWidget);
    await lifecycle(tester, [AppLifecycleState.resumed]);
    expect(find.byType(PrivacyCover), findsNothing);

    // While the OS prompt is up (switching App lock on), no cover.
    auth.hold = Completer();
    final pending = h.read(appLockControllerProvider.notifier).setEnabled(true);
    await tester.pump();
    await lifecycle(tester, [AppLifecycleState.inactive]);
    expect(find.byType(PrivacyCover), findsNothing);
    auth.hold!.complete(DeviceAuthResult.cancelled);
    await tester.runAsync(() => pending);
    await lifecycle(tester, [AppLifecycleState.resumed]);
  });
}
