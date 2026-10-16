/// Automatic backups: the schedule rules (chosen time, daily / weekly),
/// what a background run does (local backup when due, Drive only when
/// signed in, past the slot and on Wi-Fi with "Wi-Fi only") and local
/// backups' "Keep last N".
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/sync/account_store.dart';
import 'package:focusflow/core/sync/background_jobs.dart';
import 'package:focusflow/core/sync/background_tasks.dart';
import 'package:focusflow/core/sync/backup_files.dart';
import 'package:focusflow/core/sync/backup_schedule.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/cloud_account_controller.dart';
import 'package:focusflow/core/sync/local_backups.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

import '../../helpers/test_container.dart';
import 'drive_fakes.dart';
import 'sync_fixtures.dart';

const _google = CloudAccount(provider: CloudProvider.google, email: 'a@b.co');

void main() {
  group('BackupSchedule', () {
    const ninePm = 21 * 60;

    test('slots and delays follow the chosen time of day', () {
      expect(
        BackupSchedule.lastSlot(DateTime(2026, 3, 5, 22), ninePm),
        DateTime(2026, 3, 5, 21),
      );
      expect(
        BackupSchedule.lastSlot(DateTime(2026, 3, 5, 8), ninePm),
        DateTime(2026, 3, 4, 21),
      );
      expect(
        BackupSchedule.delayUntilNext(DateTime(2026, 3, 5, 20, 30), ninePm),
        const Duration(minutes: 30),
      );
    });

    test('daily is due once the slot passed since the last sync', () {
      bool due(DateTime now, DateTime? last) => BackupSchedule.isDriveDue(
        now: now,
        lastSync: last,
        frequency: BackupFrequency.daily,
        minutesOfDay: ninePm,
      );
      expect(due(DateTime(2026, 3, 5, 8), null), isTrue);
      expect(
        due(DateTime(2026, 3, 5, 20), DateTime(2026, 3, 4, 21, 5)),
        isFalse,
      );
      expect(
        due(DateTime(2026, 3, 5, 21, 1), DateTime(2026, 3, 4, 21, 5)),
        isTrue,
      );
    });

    test('weekly waits about a week', () {
      bool due(DateTime now) => BackupSchedule.isDriveDue(
        now: now,
        lastSync: DateTime(2026, 3, 1, 21, 5),
        frequency: BackupFrequency.weekly,
        minutesOfDay: ninePm,
      );
      expect(due(DateTime(2026, 3, 3, 22)), isFalse);
      expect(due(DateTime(2026, 3, 8, 21, 30)), isTrue);
    });

    test('the job signature changes with what the job must do', () {
      const s = AppSettings();
      expect(backupSignature(s, _google), isNot(backupSignature(s, null)));
      expect(
        backupSignature(s.copyWith(backupMinutes: 60), _google),
        isNot(backupSignature(s, _google)),
      );
    });
  });

  group('BackgroundJobs', () {
    late FakeDriveStore store;
    late FakeNetwork net;
    late MemorySecureStore secure;
    late AppFiles files;

    Future<TestHarness> harness({required DateTime now}) async {
      final h = await TestHarness.create(
        now: now,
        overrides: [
          ...driveOverrides(
            drive: store,
            files: files,
            secure: secure,
            net: net,
          ),
          googleConfigProvider.overrideWithValue(const ConfiguredGoogle()),
        ],
      );
      addTearDown(h.dispose);
      store.now = h.clock.now;
      return h;
    }

    setUp(() {
      store = FakeDriveStore();
      net = FakeNetwork(wifi: false);
      secure = MemorySecureStore({
        AccountStore.storageKey: AccountStore.encode(_google),
      });
      files = tempFiles(addTearDown);
    });

    test(
      'Wi-Fi only skips Drive on mobile data; local backup still runs',
      () async {
        final h = await harness(now: DateTime(2026, 3, 5, 22));
        final done = await BackgroundJobs(h.container.read).run();
        expect(done, contains(BackgroundStep.localBackup));
        expect(done, isNot(contains(BackgroundStep.driveBackup)));
        expect(store.files, isEmpty);
      },
    );

    test('on Wi-Fi the Drive backup runs once per slot', () async {
      net.wifi = true;
      final h = await harness(now: DateTime(2026, 3, 5, 22));
      final jobs = BackgroundJobs(h.container.read);
      expect(await jobs.run(), contains(BackgroundStep.driveBackup));
      expect(store.backupNames, hasLength(1));
      expect(h.read(syncStatusProvider).lastSyncAt, isNotNull);

      h.clock.advance(const Duration(hours: 1));
      final again = await jobs.run();
      expect(again, isNot(contains(BackgroundStep.driveBackup)));
      expect(again, isNot(contains(BackgroundStep.localBackup)));
    });

    test('no Drive backup when auto backup is off or signed out', () async {
      net.wifi = true;
      final h = await harness(now: DateTime(2026, 3, 5, 22));
      await h
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(autoBackupDrive: false));
      expect(
        await BackgroundJobs(h.container.read).isDriveBackupDue(),
        isFalse,
      );

      await h
          .read(settingsProvider.notifier)
          .update((s) => s.copyWith(autoBackupDrive: true));
      await h.read(cloudAccountControllerProvider).signOut();
      expect(
        await BackgroundJobs(h.container.read).isDriveBackupDue(),
        isFalse,
      );
    });
  });

  test('local backups keep the last N files', () async {
    final files = tempFiles(addTearDown);
    final h = await TestHarness.create(
      now: syncNow,
      overrides: driveOverrides(
        drive: null,
        files: files,
        secure: MemorySecureStore(),
        net: FakeNetwork(),
      ),
    );
    addTearDown(h.dispose);
    await h
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(keepBackups: 2));
    final local = h.read(localBackupsProvider);
    final records = [];
    for (var i = 0; i < 3; i++) {
      h.clock.advance(const Duration(minutes: 1));
      records.add(await local.backupNow());
    }
    expect(records.first.localPath, startsWith('${LocalBackups.folder}/'));
    expect(await files.exists(records.first.localPath as String), isFalse);
    expect(await files.exists(records.last.localPath as String), isTrue);
    expect(await local.read(records.last), isNotNull);
  });
}
