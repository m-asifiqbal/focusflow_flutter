/// Shared setup for the Backup & Sync (34) / Import & Export (35) screen
/// tests: a harness over the auth fakes (fake Drive, keychain, files) with
/// a fixed Google account, and the mockup's history rows.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/sync/cloud_account.dart';
import 'package:focusflow/core/sync/cloud_account_controller.dart';
import 'package:focusflow/core/sync/drive_sync.dart';
import 'package:focusflow/features/backup/domain/entities/backup_record.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';
import '../auth/auth_test_support.dart';

final backupNow = DateTime(2026, 6, 13, 9, 41);

class FixedAccount extends CloudAccountNotifier {
  FixedAccount(this.account);

  final CloudAccount? account;

  @override
  CloudAccount? build() => account;
}

const asifAccount = CloudAccount(
  provider: CloudProvider.google,
  email: 'asif.design@gmail.com',
  displayName: 'Asif Iqbal',
);

const _mb = 1024 * 1024;

Future<(TestHarness, AuthFakes)> backupHarness(
  WidgetTester tester, {
  CloudAccount? account = asifAccount,
  bool fakeUsage = true,
  List<Override> overrides = const [],
}) async {
  final fakes = AuthFakes();
  final h = (await tester.runAsync(
    () => authHarness(
      fakes,
      now: backupNow,
      overrides: [
        cloudAccountProvider.overrideWith(() => FixedAccount(account)),
        if (fakeUsage) ...[
          driveUsageProvider.overrideWith(
            (ref) async => account == null
                ? null
                : const DriveUsage(
                    usedBytes: 2516582,
                    limitBytes: 15 * 1024 * _mb,
                  ),
          ),
          backupItemCountProvider.overrideWith((ref) => Stream.value(113)),
          backupKeyExistsProvider.overrideWith((ref) async => true),
        ],
        ...overrides,
      ],
    ),
  ))!;
  addTearDown(() async {
    await tester.runAsync(h.dispose);
    if (fakes.dir.existsSync()) fakes.dir.deleteSync(recursive: true);
  });
  return (h, fakes);
}

/// The three HISTORY rows of the mockup.
Future<void> seedHistory(TestHarness h) async {
  final repo = h.read(backupRecordsRepositoryProvider);
  await repo.add(
    BackupRecord(
      id: '',
      location: BackupLocation.drive,
      createdAt: DateTime(2026, 6, 13, 9, 39),
      sizeBytes: (2.4 * _mb).round(),
      itemCount: 113,
      isAuto: true,
      isEncrypted: true,
      driveFileId: 'f1',
    ),
  );
  await repo.add(
    BackupRecord(
      id: '',
      location: BackupLocation.local,
      createdAt: DateTime(2026, 6, 12, 23, 2),
      sizeBytes: (2.3 * _mb).round(),
      itemCount: 112,
      localPath: 'FocusFlow/x.ffbackup',
    ),
  );
  await repo.add(
    BackupRecord(
      id: '',
      location: BackupLocation.drive,
      createdAt: DateTime(2026, 6, 11, 21),
      sizeBytes: (2.3 * _mb).round(),
      itemCount: 110,
      isAuto: true,
      driveFileId: 'f0',
    ),
  );
}
