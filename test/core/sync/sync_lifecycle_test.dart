/// Sync lifecycle — the controller always leaves its busy state (Drive
/// timeouts, unexpected errors, missing backup PIN), token errors are
/// told apart (offline vs sign in again), the resume refresh picks up
/// background writes, scheduling waits for the stored account, and
/// sign-out forgets the sync bookkeeping.
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/sync/account_store.dart';
import 'package:focusflow/core/sync/background_tasks.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/drive_sync_state.dart';
import 'package:focusflow/core/sync/google_account.dart';
import 'package:focusflow/core/sync/google_drive_store.dart';
import 'package:focusflow/core/sync/sync_controller.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import '../../helpers/test_container.dart';
import 'drive_fakes.dart';
import 'sync_fixtures.dart';

const _google = CloudAccount(provider: CloudProvider.google, email: 'a@b.co');

class _Tokens implements DriveTokenSource {
  _Tokens({this.error});

  final Object? error;

  @override
  Future<String?> token({bool interactive = false}) async {
    if (error case final e?) throw e;
    return 't';
  }

  @override
  Future<void> invalidate(String token) async {}
}

/// A Drive whose list() throws a non-Drive error (a bug, say).
class _BuggyDrive extends FakeDriveStore {
  @override
  Future<List<DriveFile>> list() async => throw StateError('bug');
}

void main() {
  Future<TestHarness> harness({
    DriveStore? drive,
    DriveStoreFactory? factory,
    bool plaintext = true,
    MemorySecureStore? secure,
  }) async {
    final h = await TestHarness.create(
      now: syncNow,
      prefs: plaintext ? plaintextBackupPrefs() : const {},
      overrides: [
        ...driveOverrides(
          drive: drive is FakeDriveStore ? drive : FakeDriveStore(),
          files: tempFiles(addTearDown),
          secure: secure ?? MemorySecureStore(),
          net: FakeNetwork(),
        ),
        if (factory != null)
          driveStoreFactoryProvider.overrideWithValue(factory),
      ],
    );
    addTearDown(h.dispose);
    return h;
  }

  test('a Drive call that never answers times out and releases busy', () async {
    final hanging = MockClient((_) => Completer<http.Response>().future);
    final store = GoogleDriveStore(
      _Tokens(),
      httpClient: hanging,
      requestTimeout: const Duration(milliseconds: 50),
    );
    final h = await harness(
      factory: ({bool interactive = false}) async => store,
    );
    final out = await h.read(syncStatusProvider.notifier).syncNow();
    final s = h.read(syncStatusProvider);
    expect(out, isNull);
    expect(s.isBusy, isFalse);
    expect(s.failure, DriveFailureKind.offline);
  });

  test('an unexpected error still leaves the busy state', () async {
    final h = await harness(drive: _BuggyDrive());
    await h.read(syncStatusProvider.notifier).syncNow();
    final s = h.read(syncStatusProvider);
    expect(s.isBusy, isFalse);
    expect(s.phase, SyncPhase.error);
    expect(s.failure, DriveFailureKind.unknown);
  });

  test('no backup PIN: sync stops before Drive and says so', () async {
    final drive = FakeDriveStore();
    final h = await harness(drive: drive, plaintext: false);
    final out = await h.read(syncStatusProvider.notifier).syncNow();
    final s = h.read(syncStatusProvider);
    expect(out, isNull);
    expect(s.needsBackupPin, isTrue);
    expect(s.isBusy, isFalse);
    expect(s.lastSyncAt, isNull);
    expect(drive.files, isEmpty);
  });

  test(
    'token errors: network trouble is offline, the rest sign in again',
    () async {
      DriveFailureKind kind(Object e) => GoogleDriveStore.mapTokenError(e).kind;
      expect(kind(const SocketException('down')), DriveFailureKind.offline);
      expect(kind(TimeoutException('slow')), DriveFailureKind.offline);
      expect(
        kind(const CloudAuthException('network_error')),
        DriveFailureKind.offline,
      );
      expect(
        kind(const CloudAuthException('Account revoked')),
        DriveFailureKind.authExpired,
      );
      // End to end: a token fetch that fails offline reports offline.
      final store = GoogleDriveStore(
        _Tokens(error: const SocketException('down')),
        httpClient: MockClient((_) async => http.Response('{}', 200)),
      );
      await expectLater(
        store.list(),
        throwsA(
          isA<DriveFailure>().having(
            (f) => f.kind,
            'kind',
            DriveFailureKind.offline,
          ),
        ),
      );
    },
  );

  test('backups over 5 MB upload resumably', () async {
    final requests = <http.BaseRequest>[];
    final client = MockClient.streaming((req, body) async {
      requests.add(req);
      await body.drain<void>();
      return http.StreamedResponse(const Stream.empty(), 500);
    });
    final store = GoogleDriveStore(_Tokens(), httpClient: client);
    await expectLater(
      store.upload('big.ffbackup', Uint8List(6 * 1024 * 1024)),
      throwsA(isA<DriveFailure>()),
    );
    expect(requests.first.url.queryParameters['uploadType'], 'resumable');

    requests.clear();
    await expectLater(
      store.upload('small.ffbackup', Uint8List(1024)),
      throwsA(isA<DriveFailure>()),
    );
    expect(requests.first.url.queryParameters['uploadType'], 'multipart');
  });

  test(
    'resume refresh re-reads the last sync and re-queries streams',
    () async {
      final h = await harness();
      final sync = h.read(syncStatusProvider.notifier);
      expect(h.read(syncStatusProvider).lastSyncAt, isNull);
      var emissions = 0;
      final sub = h.db.select(h.db.notes).watch().listen((_) => emissions++);
      addTearDown(sub.cancel);
      await pumpEventQueue();
      final before = emissions;
      // What the background isolate leaves behind.
      await h
          .read(sharedPreferencesProvider)
          .setString(
            SyncController.lastSyncKey,
            syncNow.toUtc().toIso8601String(),
          );
      await sync.refreshFromDisk();
      await pumpEventQueue();
      expect(h.read(syncStatusProvider).lastSyncAt, syncNow);
      expect(emissions, greaterThan(before));
    },
  );

  test('scheduling waits for the stored account to load', () async {
    final secure = MemorySecureStore({
      AccountStore.storageKey: AccountStore.encode(_google),
    });
    final h = await harness(secure: secure);
    // Right after launch the provider still says "no account"…
    expect(h.read(cloudAccountProvider), isNull);
    // …but the schedule inputs wait for the keychain read.
    final (_, account) = await scheduleInputs(h.container.read);
    expect(account?.email, 'a@b.co');
    final s = h.read(settingsProvider);
    expect(backupSignature(s, account), backupSignature(s, _google));
  });

  test(
    'sign-out forgets merged backups, the pending choice and last sync',
    () async {
      final h = await harness();
      await h
          .read(sharedPreferencesProvider)
          .setString(SyncController.lastSyncKey, syncNow.toIso8601String());
      final state = DriveSyncState(h.read(sharedPreferencesProvider));
      await state.saveMerged({'other': syncNow});
      await state.setDecisionPending(true);
      await h.read(syncStatusProvider.notifier).refreshFromDisk();
      expect(h.read(syncStatusProvider).lastSyncAt, isNotNull);

      await h.read(cloudAccountControllerProvider).signOut();
      expect(state.merged(), isEmpty);
      expect(state.decisionPending, isFalse);
      expect(h.read(syncStatusProvider).lastSyncAt, isNull);
      expect(
        h.read(sharedPreferencesProvider).getString(SyncController.lastSyncKey),
        isNull,
      );
    },
  );
}
