/// Prayers through Drive sync: a phone's prayers (with a jamaat time) and
/// their logs reach another phone by "Sync now", show up in its live
/// streams, and a later mark on either phone travels back.
library;

import 'package:drift/drift.dart' show driftRuntimeOptions;
import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/sync/backup_crypto.dart';
import 'package:focusflow/core/sync/backup_files.dart';
import 'package:focusflow/core/sync/sync_providers.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/repository/prayers_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';
import 'drive_fakes.dart';
import 'sync_fixtures.dart';

void main() {
  late FakeDriveStore store;

  setUpAll(() => driftRuntimeOptions.dontWarnAboutMultipleDatabases = true);

  setUp(() => store = FakeDriveStore());

  /// A phone signed in to the shared fake Drive.
  Future<TestHarness> phone(String deviceId) async {
    final files = tempFiles(addTearDown);
    final h = await TestHarness.create(
      now: syncNow,
      prefs: plaintextBackupPrefs(),
      deviceId: deviceId,
      overrides: driveOverrides(
        drive: store,
        files: files,
        secure: MemorySecureStore(),
        net: FakeNetwork(),
      ),
    );
    addTearDown(h.dispose);
    store.now = h.clock.now;
    return h;
  }

  test('prayers and their logs sync to another phone and back', () async {
    final a = await phone('phone-a-000001');
    final repoA = a.read(prayersRepositoryProvider);
    final id = await repoA.save(
      Prayer(
        id: '',
        name: 'Dhuhr',
        start: const PrayerTimeRule.fixed(12 * 60 + 30),
        end: const PrayerTimeRule.fixed(15 * 60 + 45),
        jamaat: const PrayerJamaat.at(13 * 60 + 15),
        createdAt: syncNow,
        updatedAt: syncNow,
      ),
    );
    await repoA.mark(id, syncNow, PrayerStatus.onTime, congregation: true);
    await a.read(driveSyncProvider).syncNow();

    final b = await phone('phone-b-000002');
    b.clock.advance(const Duration(minutes: 5));
    final out = await b.read(driveSyncProvider).syncNow();
    expect(out.mergedBackups, 1);
    final repoB = b.read(prayersRepositoryProvider);
    final onB = await repoB.watchPrayers(PrayersScope.active).first;
    expect(onB.single.name, 'Dhuhr');
    expect(onB.single.jamaat, const PrayerJamaat.at(13 * 60 + 15));
    final logsB = await repoB
        .watchLogs(syncNow, syncNow.add(const Duration(days: 1)))
        .first;
    expect(logsB.single.status, PrayerStatus.onTime);
    expect(logsB.single.congregation, isTrue);

    // B marks the next day late; A gets it with its next sync.
    final next = syncNow.add(const Duration(days: 1));
    b.clock.advance(const Duration(minutes: 5));
    await repoB.mark(id, next, PrayerStatus.late);
    await b.read(driveSyncProvider).syncNow();
    a.clock.set(b.clock.now().add(const Duration(minutes: 5)));
    await a.read(driveSyncProvider).syncNow();
    final logsA = await repoA
        .watchLogs(syncNow, next.add(const Duration(days: 1)))
        .first;
    expect(logsA.map((l) => l.status), [
      PrayerStatus.onTime,
      PrayerStatus.late,
    ]);
  });
}
