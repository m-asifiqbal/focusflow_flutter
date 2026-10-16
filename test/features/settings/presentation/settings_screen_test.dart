/// Screen 30 — Settings root: the mockup state (signed in, live values)
/// in light + dark; signed-out card; search finds sub-page rows and deep
/// links; pickers write settings; sign out asks and signs out; no overflow
/// at 360 pt / text scale 1.3.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/crypto/biometric_auth.dart';
import 'package:focusflow/core/items/library_counts.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/cloud_account_controller.dart';
import 'package:focusflow/core/sync/sync_controller.dart';
import 'package:focusflow/features/library/presentation/providers/library_providers.dart';
import 'package:focusflow/features/settings/domain/entities/storage_usage.dart';
import 'package:focusflow/features/settings/domain/repository/storage_repository.dart';
import 'package:focusflow/features/settings/domain/services/device_authenticator.dart'
    as lock;
import 'package:focusflow/features/settings/presentation/providers/app_lock_providers.dart';
import 'package:focusflow/features/settings/presentation/providers/settings_root_providers.dart';
import 'package:focusflow/features/settings/presentation/screens/appearance_settings_screen.dart';
import 'package:focusflow/features/vault/presentation/providers/vault_crypto_providers.dart';
import 'package:focusflow/features/vault/presentation/screens/vault_security_settings_screen.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../../helpers/screen_harness.dart';
import '../../../helpers/test_container.dart';

/// design/30_settings.png is 1170×7584 (390×2528 pt).
const _mockupTall = Size(390, 2528);
final _now = DateTime(2026, 6, 12, 9, 41);

const _asif = CloudAccount(
  provider: CloudProvider.google,
  email: 'asif.design@gmail.com',
  displayName: 'Asif Iqbal',
);

class _FixedAccount extends CloudAccountNotifier {
  _FixedAccount(this.account);

  final CloudAccount? account;

  @override
  CloudAccount? build() => account;
}

class _FakeController implements CloudAccountController {
  _FakeController(this.ref);

  final Ref ref;
  int signOuts = 0;

  @override
  bool get appleAvailable => false;

  @override
  bool get googleAvailable => false;

  @override
  Future<CloudAccount?> signInWithApple() async => null;

  @override
  Future<CloudAccount?> signInWithGoogle() async => null;

  @override
  Future<void> signOut({bool revoke = false}) async {
    signOuts++;
    ref.read(cloudAccountProvider.notifier).set(null);
  }
}

/// Device owner check that always passes (App lock is on in these tests,
/// so the gate unlocks at once).
class _OwnerAuth implements lock.DeviceAuthenticator {
  @override
  Future<bool> isSupported() async => true;

  @override
  Future<lock.BiometricKind> biometricKind() async => lock.BiometricKind.faceId;

  @override
  Future<lock.DeviceAuthResult> authenticate(String reason) async =>
      lock.DeviceAuthResult.success;
}

class _FakeStorage implements StorageRepository {
  @override
  Future<int> clearCache() async => 0;

  @override
  Future<StorageUsage> measure() async =>
      const StorageUsage(databaseBytes: 40000000, attachmentsBytes: 8000000);
}

void main() {
  late TestHarness h;
  _FakeController? controller;

  Future<void> setUp(
    WidgetTester tester, {
    CloudAccount? account = _asif,
  }) async {
    await loadAppFonts();
    h = (await tester.runAsync(
      () => TestHarness.create(
        now: _now,
        prefs: {
          SyncController.lastSyncKey: _now
              .subtract(const Duration(minutes: 2))
              .toIso8601String(),
        },
        overrides: [
          cloudAccountProvider.overrideWith(() => _FixedAccount(account)),
          cloudAccountControllerProvider.overrideWith(
            (ref) => controller = _FakeController(ref),
          ),
          appVersionProvider.overrideWith((ref) async => 'v1.0.0 (24)'),
          storageRepositoryProvider.overrideWithValue(_FakeStorage()),
          deviceAuthenticatorProvider.overrideWithValue(_OwnerAuth()),
          biometricAuthProvider.overrideWithValue(FakeBiometricAuth()),
          libraryCountsProvider.overrideWith(
            (ref) => Stream.value(
              const LibraryCounts(
                pinned: 9,
                tags: 7,
                folders: 4,
                archived: 37,
                trash: 5,
              ),
            ),
          ),
        ],
      ),
    ))!;
    addTearDown(() => tester.runAsync(h.dispose));
    // Mockup: week starts Saturday.
    await tester.runAsync(
      () => h.updateSettings(
        (s) => s.copyWith(
          weekStartsOn: DateTime.saturday,
          appLockEnabled: true,
          accountMode: account == null ? AccountMode.offline : null,
        ),
      ),
    );
  }

  AppSettings settings() => h.read(settingsProvider);

  /// Taps the last match (sheet options sit above the page and tab bar).
  Future<void> tapText(WidgetTester tester, String text) async {
    await tester.ensureVisible(find.text(text).last);
    await tester.pump();
    await tester.tap(find.text(text).last);
    await settle(tester);
  }

  testWidgets('mockup state (light)', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settings, size: _mockupTall);
    for (final t in [
      'Settings',
      'Asif Iqbal',
      'asif.design@gmail.com',
      'SYNCED 2 MIN AGO',
      'English',
      'Home',
      'Saturday',
      '12-hour',
      'System',
      '9',
      'Grid · Last edited',
      // Smart lists aren't implemented: the row shows a setting that is.
      'Completed shown',
      'Snooze 10m',
      'Reset 12:00 AM',
      '11',
      'Face ID',
      'On',
      '30 s',
      'Google Drive',
      '48 MB',
      '37',
      '5',
      'v1.0.0 (24)',
      'Sign out',
      'Made with care · Your data stays yours',
    ]) {
      expect(find.text(t), findsWidgets, reason: t);
    }
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '30_settings');
    debugDefaultTargetPlatformOverride = null;
  });

  testWidgets('mockup state (dark)', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settings, size: _mockupTall, dark: true);
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '30_settings_dark');
  });

  testWidgets('signed out: sign-in card, no Sign out button', (tester) async {
    await setUp(tester, account: null);
    await pumpApp(tester, h, AppRoutes.settings);
    expect(find.text('Sign in to back up'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Sign out'), findsNothing);
    await captureScreen(tester, '30_settings_signed_out');
    // No OAuth ids in tests: the button explains instead of failing.
    await tester.tap(find.text('Continue with Google'));
    await settle(tester);
    expect(
      find.text('Google Drive is not set up in this build'),
      findsOneWidget,
    );
  });

  testWidgets('search finds sub-page rows and deep-links', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settings);
    await tester.enterText(find.byType(EditableText), 'dark');
    await settle(tester);
    expect(find.text('Theme'), findsOneWidget);
    expect(find.text('Appearance'), findsWidgets);
    expect(find.text('Language'), findsNothing);
    await captureScreen(tester, '30_settings_search');
    await tester.tap(find.text('Theme'));
    await settle(tester);
    expect(find.byType(AppearanceSettingsScreen), findsOneWidget);
  });

  testWidgets('search with no match shows the empty state', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settings);
    await tester.enterText(find.byType(EditableText), 'zzzz');
    await settle(tester);
    expect(find.text('No settings match "zzzz"'), findsOneWidget);
  });

  testWidgets('pickers and switch write settings', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settings);
    await tapText(tester, 'Week starts on');
    await tapText(tester, 'Monday');
    expect(settings().weekStartsOn, DateTime.monday);
    expect(find.text('Monday'), findsOneWidget);

    // The root row opens General (date pattern + clock).
    await tapText(tester, 'Date & time format');
    expect(find.text('Date format'), findsOneWidget);
    await tapText(tester, 'Time format');
    await tapText(tester, '24-hour');
    expect(settings().use24HourTime, isTrue);
    await tapText(tester, 'Settings');
    expect(find.text('Reset 00:00'), findsOneWidget);

    await tapText(tester, 'Start screen');
    await tapText(tester, 'Library');
    expect(settings().startScreen, StartScreen.library);

    final before = settings().hideInAppSwitcher;
    await tapText(tester, 'Hide content in app switcher');
    expect(settings().hideInAppSwitcher, !before);
  });

  testWidgets('Clear clipboard after opens Vault security (re-auth there), '
      'never writes from the root', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settings);
    final before = settings().clipboardClearSeconds;
    await tapText(tester, 'Clear clipboard after');
    expect(find.byType(VaultSecuritySettingsScreen), findsOneWidget);
    expect(find.text('1 min'), findsNothing, reason: 'no picker on root');
    expect(settings().clipboardClearSeconds, before);
  });

  testWidgets('search "clipboard" deep-links to Vault security', (
    tester,
  ) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settings);
    await tester.enterText(find.byType(EditableText), 'clipboard');
    await settle(tester);
    await tester.tap(find.text('Clear clipboard after').last);
    await settle(tester);
    expect(find.byType(VaultSecuritySettingsScreen), findsOneWidget);
  });

  testWidgets('Tasks row reflects "Show completed"', (tester) async {
    await setUp(tester);
    await tester.runAsync(
      () => h.updateSettings((s) => s.copyWith(tasksShowCompleted: false)),
    );
    await pumpApp(tester, h, AppRoutes.settings);
    expect(find.text('Completed hidden'), findsOneWidget);
    expect(find.textContaining('Smart lists'), findsNothing);
  });

  testWidgets('rows drill into sub-pages', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settings);
    await tapText(tester, 'Appearance');
    expect(find.byType(AppearanceSettingsScreen), findsOneWidget);
  });

  testWidgets('sign out asks, then signs out', (tester) async {
    await setUp(tester);
    await pumpApp(tester, h, AppRoutes.settings);
    await tapText(tester, 'Sign out');
    expect(find.text('Sign out?'), findsOneWidget);
    await tester.tap(find.text('Sign out').last);
    await settle(tester);
    expect(controller!.signOuts, 1);
    expect(find.text('Sign in to back up'), findsOneWidget);
  });

  testWidgets('no overflow at 360 pt and text scale 1.3', (tester) async {
    await setUp(tester);
    await pumpApp(
      tester,
      h,
      AppRoutes.settings,
      size: const Size(360, 2900),
      textScale: 1.3,
    );
    expect(tester.takeException(), isNull);
    await captureScreen(tester, '30_settings_small');
  });
}
