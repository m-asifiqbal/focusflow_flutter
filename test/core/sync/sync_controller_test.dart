/// SyncController (syncStatusProvider) — the status the UI shows for
/// Sync now: offline, not signed in, sign-in expired, Drive full, done
/// (with the last sync time persisted across restarts).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/sync_controller.dart';
import 'package:focusflow/shared/providers/core_providers.dart';

import '../../helpers/test_container.dart';
import 'drive_fakes.dart';
import 'sync_fixtures.dart';

void main() {
  late FakeDriveStore store;
  late FakeNetwork net;

  Future<TestHarness> harness({bool signedIn = true}) async {
    final h = await TestHarness.create(
      now: syncNow,
      prefs: plaintextBackupPrefs(),
      overrides: driveOverrides(
        drive: signedIn ? store : null,
        files: tempFiles(addTearDown),
        secure: MemorySecureStore(),
        net: net,
      ),
    );
    addTearDown(h.dispose);
    store.now = h.clock.now;
    return h;
  }

  setUp(() {
    store = FakeDriveStore();
    net = FakeNetwork();
  });

  test('offline fails fast without touching Drive', () async {
    net.online = false;
    final h = await harness();
    final out = await h.read(syncStatusProvider.notifier).syncNow();
    final s = h.read(syncStatusProvider);
    expect(out, isNull);
    expect(s.phase, SyncPhase.error);
    expect(s.failure, DriveFailureKind.offline);
    expect(s.message, contains('offline'));
    expect(store.files, isEmpty);
  });

  test('not signed in with Google', () async {
    final h = await harness(signedIn: false);
    await h.read(syncStatusProvider.notifier).syncNow();
    expect(h.read(syncStatusProvider).failure, DriveFailureKind.notSignedIn);
  });

  test('expired sign-in and a full Drive are reported', () async {
    final h = await harness();
    final sync = h.read(syncStatusProvider.notifier);
    store.failWith = const DriveFailure(DriveFailureKind.authExpired);
    await sync.syncNow();
    expect(h.read(syncStatusProvider).failure, DriveFailureKind.authExpired);
    expect(h.read(syncStatusProvider).message, contains('Sign in again'));
    store.failWith = const DriveFailure(DriveFailureKind.quota);
    await sync.syncNow();
    expect(h.read(syncStatusProvider).failure, DriveFailureKind.quota);
    expect(h.read(syncStatusProvider).lastSyncAt, isNull);
  });

  test('success records the time and goes back to idle on reset', () async {
    final h = await harness();
    final phases = <SyncPhase>[];
    h.container.listen(syncStatusProvider, (_, s) => phases.add(s.phase));
    final out = await h.read(syncStatusProvider.notifier).syncNow();
    expect(out, isNotNull);
    final s = h.read(syncStatusProvider);
    expect(s.phase, SyncPhase.done);
    expect(s.lastSyncAt, syncNow);
    expect(s.message, 'Backed up to Google Drive');
    expect(phases.first, SyncPhase.preparing);
    expect(phases, contains(SyncPhase.uploading));
    expect(
      h.read(sharedPreferencesProvider).getString(SyncController.lastSyncKey),
      isNotNull,
    );

    h.read(syncStatusProvider.notifier).reset();
    expect(h.read(syncStatusProvider).phase, SyncPhase.idle);
    expect(h.read(syncStatusProvider).lastSyncAt, syncNow);
  });
}
