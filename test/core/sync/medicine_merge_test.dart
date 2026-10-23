/// Medicines in backups: they travel in the snapshot, merge last-write-wins
/// like every item, their doses merge per natural id (the same dose logged
/// on two devices is one row, the newer log wins), and a deleted dose /
/// medicine travels as a tombstone.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/sync/snapshot.dart';
import 'package:focusflow/core/sync/snapshot_io.dart';
import 'package:focusflow/core/sync/snapshot_merger.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';
import 'sync_fixtures.dart';

void main() {
  late TestHarness h;
  late SnapshotIo io;
  late SnapshotMerger merger;
  late MedicinesRepository repo;
  late String id;
  final day = DateTime(2026, 1, 10);

  setUp(() async {
    h = await TestHarness.create(now: syncNow);
    io = SnapshotIo(h.db, deviceId: TestHarness.deviceId);
    merger = SnapshotMerger(
      db: h.db,
      io: io,
      items: h.read(itemsRepositoryProvider),
    );
    repo = h.read(medicinesRepositoryProvider);
    id = await repo.save(
      Medicine.draft(startDate: day, name: 'Metformin').copyWith(stockLeft: 10),
    );
    await repo.markTaken(id, day, 480);
  });

  tearDown(() => h.dispose());

  test('a snapshot carries medicines and their doses', () async {
    final s = await io.read();
    expect(s.rows('medicines').single['id'], id);
    expect(
      s.rows('medicine_doses').single['id'],
      DoseLog.idFor(id, '2026-01-10', 480),
    );
    expect(s.itemCounts['medicine'], 1);
    // And survives an encode / decode round trip.
    expect(DbSnapshot.decode(s.encode()).sameContentAs(s), isTrue);
  });

  test('replace restore brings them back exactly', () async {
    final s = await io.read();
    await h.read(itemsRepositoryProvider).deleteForever([
      (await repo.getMedicine(id))!.ref,
    ]);
    expect(await repo.getMedicine(id), isNull);
    await io.replaceAll(s);
    expect((await repo.getMedicine(id))!.stockLeft, 9);
    expect((await repo.doseLog(id, day, 480))!.isTaken, isTrue);
  });

  test('the newer dose log wins; a new one is added', () async {
    final base = await io.read();
    final doseId = DoseLog.idFor(id, '2026-01-10', 480);
    final t0 = secs(syncNow);
    final incoming = mutate(base, (t) {
      rowOf(t, 'medicine_doses', doseId)
        ..['status'] = DoseStatus.skipped.index
        ..['updated_at'] = t0 + 60;
      t['medicine_doses']!.add({
        ...rowOf(t, 'medicine_doses', doseId),
        'id': DoseLog.idFor(id, '2026-01-10', 1200),
        'slot_minutes': 1200,
        'status': DoseStatus.taken.index,
      });
    });
    await merger.merge(incoming);
    expect((await repo.doseLog(id, day, 480))!.isSkipped, isTrue);
    expect((await repo.doseLog(id, day, 1200))!.isTaken, isTrue);

    // An older incoming log loses.
    final stale = mutate(await io.read(), (t) {
      rowOf(t, 'medicine_doses', doseId)
        ..['status'] = DoseStatus.taken.index
        ..['updated_at'] = t0 - 600;
    });
    await merger.merge(stale);
    expect((await repo.doseLog(id, day, 480))!.isSkipped, isTrue);
  });

  test('a cleared dose and a deleted medicine travel as tombstones', () async {
    final base = await io.read();
    // Elsewhere: the dose was un-logged (row deleted → tombstone).
    await repo.restoreDose(id, day, 480, null);
    final cleared = await io.read();
    expect(
      cleared.rows('tombstones').map((t) => t['entity']),
      contains('medicine_dose'),
    );
    // Back to the old state, then merge the device that cleared it.
    await io.replaceAll(base);
    expect(await repo.doseLog(id, day, 480), isNotNull);
    await merger.merge(cleared);
    expect(await repo.doseLog(id, day, 480), isNull);
  });
}
