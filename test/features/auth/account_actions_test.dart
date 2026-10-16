/// Account danger zone (screen 36) without the UI: erase forgets the
/// Drive sync bookkeeping, "Delete account & Drive data" says exactly what
/// happened when it stops part-way (and erases nothing locally until Drive
/// is empty), a retry finishes, and "Remove device" keeps its backups
/// unless asked.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/drive_store.dart';
import 'package:focusflow/core/sync/sync_controller.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/features/auth/presentation/notifiers/account_actions_controller.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../core/sync/drive_fakes.dart';
import '../../helpers/test_container.dart';
import 'auth_test_support.dart';

final _now = DateTime(2026, 10, 13, 9, 41);

class _FlakyDrive extends FakeDriveStore {
  final Set<String> failIds = {};

  @override
  Future<void> delete(String fileId) async {
    if (failIds.contains(fileId)) {
      throw const DriveFailure(DriveFailureKind.unknown, '500');
    }
    await super.delete(fileId);
  }
}

void main() {
  late AuthFakes fakes;
  late _FlakyDrive drive;

  setUp(() {
    drive = _FlakyDrive();
    fakes = AuthFakes(drive: drive);
  });
  tearDown(() {
    if (fakes.dir.existsSync()) fakes.dir.deleteSync(recursive: true);
  });

  Future<TestHarness> signedIn() async {
    final h = await authHarness(fakes, now: _now);
    addTearDown(h.dispose);
    // The controller is autoDispose: keep it alive like the screen does.
    h.container.listen(accountActionsProvider, (_, _) {});
    await h.read(cloudAccountControllerProvider).signInWithGoogle();
    return h;
  }

  Future<int> noteCount(TestHarness h) async =>
      (await h.db.customSelect('SELECT COUNT(*) AS n FROM notes').getSingle())
          .read<int>('n');

  test('erase forgets merged backups and the last sync time', () async {
    final h = await signedIn();
    final prefs = h.read(sharedPreferencesProvider);
    await prefs.setString(SyncController.lastSyncKey, _now.toIso8601String());
    await h.read(driveSyncProvider).state.saveMerged({'tablet': _now});
    await h.read(notesRepositoryProvider).createEmpty(title: 'Gone soon');

    await h.read(accountActionsProvider.notifier).eraseLocalData();
    expect(await noteCount(h), 0);
    expect(prefs.getString(SyncController.lastSyncKey), isNull);
    expect(h.read(driveSyncProvider).state.merged(), isEmpty);
    expect(h.read(cloudAccountProvider), isNull);
  });

  test('a partial Drive delete reports counts and erases nothing local; '
      'a retry finishes', () async {
    final h = await signedIn();
    await h.read(notesRepositoryProvider).createEmpty(title: 'Keep me');
    await h.read(driveSyncProvider).syncNow(merge: false);
    await fakes.addDriveBackup(createdAt: _now);
    final stuck = fakes.drive.files.values.last.id;
    drive.failIds.add(stuck);
    final total = fakes.drive.files.length;
    final actions = h.read(accountActionsProvider.notifier);

    await expectLater(
      actions.deleteAccountAndDriveData(),
      throwsA(
        isA<AccountActionFailure>().having(
          (e) => e.message,
          'message',
          'Deleted ${total - 1} of $total files from Google Drive; 1 could '
              'not be deleted. Your local data was not erased. Try again to '
              'finish.',
        ),
      ),
    );
    expect(await noteCount(h), 1);
    expect(h.read(cloudAccountProvider), isNotNull);

    drive.failIds.clear();
    await actions.deleteAccountAndDriveData();
    expect(fakes.drive.files, isEmpty);
    expect(h.read(cloudAccountProvider), isNull);
  });

  test('Drive unreachable: nothing deleted, nothing erased', () async {
    final h = await signedIn();
    fakes.drive.failWith = const DriveFailure(DriveFailureKind.offline);
    await expectLater(
      h.read(accountActionsProvider.notifier).deleteAccountAndDriveData(),
      throwsA(
        isA<AccountActionFailure>().having(
          (e) => e.message,
          'message',
          contains('nothing was deleted'),
        ),
      ),
    );
    expect(h.read(cloudAccountProvider), isNotNull);
  });

  test('Remove device keeps its backups by default', () async {
    final h = await signedIn();
    await fakes.addDriveBackup(createdAt: _now);
    await h.read(accountActionsProvider.notifier).removeDevice('other-device');
    expect(fakes.drive.backupNames, hasLength(1));
    await h
        .read(accountActionsProvider.notifier)
        .removeDevice('other-device', deleteBackups: true);
    expect(fakes.drive.backupNames, isEmpty);
  });
}
