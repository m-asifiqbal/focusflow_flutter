/// Restore reporting — the summary says what was *not* restored (vault
/// kept, missing attachments), a failed write is reported exactly (data
/// rolled back; vault key possibly swapped already), and a restore keeps
/// the Drive sync bookkeeping honest (Replace forgets earlier merges and
/// "Last sync"; the pending Restore / Start fresh choice is settled).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/sync/backup_engine.dart';
import 'package:focusflow/core/sync/backup_format.dart';
import 'package:focusflow/core/sync/merge_report.dart';
import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/core/sync/sync_controller.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/core/sync/vault_bridge.dart';
import 'package:focusflow/features/backup/presentation/notifiers/backup_actions.dart';
import 'package:focusflow/features/backup/presentation/widgets/restore_sheets.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../core/sync/drive_fakes.dart';
import '../../core/sync/sync_fixtures.dart';
import '../../helpers/test_container.dart';

/// A bridge whose key id changes when it accepts an envelope (an empty
/// local vault adopting the backup's key).
class _SwappingVault extends NoVaultBackupBridge {
  String keyId = 'local';

  @override
  Future<Map<String, Object?>?> exportKeyEnvelope() async => {'keyId': keyId};

  @override
  Future<bool> acceptKeyEnvelope(Map<String, Object?>? envelope) async {
    keyId = 'backup';
    return true;
  }
}

BackupArchive _archiveOf(DbSnapshot s, {String deviceId = 'other'}) {
  final plain = s.encode();
  return BackupArchive(
    manifest: BackupManifest(
      schemaVersion: 2,
      appVersion: '1',
      createdAt: syncNow,
      deviceId: deviceId,
      deviceName: 'Pixel',
      platform: 'Android',
      counts: s.counts,
      itemCount: s.itemCount,
      checksum: BackupArchive.sha256Hex(plain),
    ),
    dbJson: plain,
  );
}

void main() {
  test('the summary names what was not restored', () {
    expect(
      restoreSummary(
        const RestoreResult(
          mode: RestoreMode.replace,
          report: MergeReport(added: 12),
          vaultRestored: false,
          filesMissing: 2,
        ),
      ),
      'Restored 12 items · Vault items weren\'t restored — this phone\'s '
      'vault uses a different PIN · 2 attachments are missing',
    );
    expect(
      restoreSummary(
        const RestoreResult(
          mode: RestoreMode.merge,
          report: MergeReport(added: 1, updated: 3),
        ),
      ),
      'Restore done · 1 added · 3 updated',
    );
    expect(
      restoreFailedMessage(const RestoreFailed(vaultKeyChanged: true)),
      contains("vault now opens with the backup's PIN"),
    );
    expect(
      restoreFailedMessage(const RestoreFailed(vaultKeyChanged: false)),
      "Restore failed. Your data wasn't changed.",
    );
  });

  test('a failed write rolls back and reports the swapped vault key', () async {
    final h = await TestHarness.create(now: syncNow);
    addTearDown(h.dispose);
    await h.read(notesRepositoryProvider).createEmpty(title: 'Mine');
    final vault = _SwappingVault();
    final engine = engineFor(h, tempFiles(addTearDown), vault: vault);
    // A row this schema can't take (no created_at): the insert fails.
    final bad = _archiveOf(
      DbSnapshot({
        'notes': [
          {'id': 'n-bad', 'title': 'Broken'},
        ],
      }),
    );
    await expectLater(
      engine.restore(bad, mode: RestoreMode.replace),
      throwsA(
        isA<RestoreFailed>().having(
          (e) => e.vaultKeyChanged,
          'vaultKeyChanged',
          isTrue,
        ),
      ),
    );
    final notes = (await engine.snapshot()).rows('notes');
    expect(notes.map((r) => r['title']), ['Mine']);
  });

  group('sync bookkeeping after a restore', () {
    late TestHarness h;

    setUp(() async {
      h = await TestHarness.create(
        now: syncNow,
        prefs: plaintextBackupPrefs(),
        overrides: driveOverrides(
          drive: FakeDriveStore(),
          files: tempFiles(addTearDown),
          secure: MemorySecureStore(),
          net: FakeNetwork(),
        ),
      );
      addTearDown(h.dispose);
      final sync = h.read(driveSyncProvider);
      await sync.state.saveMerged({'tablet': syncNow});
      await sync.holdMergeForDecision();
      await h
          .read(sharedPreferencesProvider)
          .setString(SyncController.lastSyncKey, syncNow.toIso8601String());
    });

    test('Replace forgets earlier merges and "Last sync"', () async {
      final archive = _archiveOf(DbSnapshot(const {}), deviceId: 'old-phone');
      await h
          .read(backupActionsProvider)
          .restore(archive, mode: RestoreMode.replace);
      final state = h.read(driveSyncProvider).state;
      expect(state.merged().keys, ['old-phone']);
      expect(state.decisionPending, isFalse);
      expect(
        h.read(sharedPreferencesProvider).getString(SyncController.lastSyncKey),
        isNull,
      );
    });

    test('Merge keeps earlier merges and adds the restored one', () async {
      final archive = _archiveOf(DbSnapshot(const {}), deviceId: 'old-phone');
      await h
          .read(backupActionsProvider)
          .restore(archive, mode: RestoreMode.merge);
      final state = h.read(driveSyncProvider).state;
      expect(state.merged().keys, containsAll(['tablet', 'old-phone']));
      expect(state.decisionPending, isFalse);
      expect(
        h.read(sharedPreferencesProvider).getString(SyncController.lastSyncKey),
        isNotNull,
      );
    });
  });
}
