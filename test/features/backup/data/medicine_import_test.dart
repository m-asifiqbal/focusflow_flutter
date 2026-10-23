/// Medicines survive a FocusFlow JSON / CSV export → import round trip:
/// the schedule, stock and dose history come back, the stock is not
/// counted down again by the imported doses, and importing twice skips
/// the duplicate.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/sync/snapshot_io.dart';
import 'package:focusflow/features/backup/domain/entities/export_options.dart';
import 'package:focusflow/features/backup/domain/services/export_writers.dart';
import 'package:focusflow/features/backup/domain/services/importers/focusflow_importer.dart';
import 'package:focusflow/features/backup/domain/services/importers/import_detector.dart';
import 'package:focusflow/features/backup/domain/services/importers/medicine_importer.dart';
import 'package:focusflow/features/backup/presentation/providers/backup_providers.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  final now = DateTime(2026, 10, 23, 9);
  final day = DateTime(2026, 10, 23);

  Future<TestHarness> source() async {
    final h = await TestHarness.create(now: now);
    final repo = h.read(medicinesRepositoryProvider);
    final id = await repo.save(
      Medicine.draft(
        startDate: DateTime(2026, 10, 1),
        name: 'Metformin',
      ).copyWith(
        strength: '500 mg',
        form: MedicineForm.capsule,
        foodTiming: FoodTiming.afterFood,
        doses: const [DoseTime(8 * 60), DoseTime(20 * 60, 0.5)],
        stockLeft: 20,
        refillAt: 5,
      ),
    );
    await repo.markTaken(id, day, 480); // stock 19
    await repo.markSkipped(id, DateTime(2026, 10, 22), 1200);
    return h;
  }

  Future<void> expectImported(MedicinesRepository repo) async {
    final m = (await repo.watchMedicines(MedicinesScope.active).first).single;
    expect(m.name, 'Metformin');
    expect(m.strength, '500 mg');
    expect(m.form, MedicineForm.capsule);
    expect(m.foodTiming, FoodTiming.afterFood);
    expect(m.doses, const [DoseTime(8 * 60), DoseTime(20 * 60, 0.5)]);
    expect(m.startDate, DateTime(2026, 10, 1));
    expect(m.stockLeft, 19); // as exported, not counted down again
    expect(m.refillAt, 5);
    expect((await repo.doseLog(m.id, day, 480))?.isTaken, isTrue);
  }

  test('JSON round trip, then a second import is a duplicate', () async {
    final from = await source();
    addTearDown(from.dispose);
    final snapshot = await SnapshotIo(
      from.db,
      deviceId: TestHarness.deviceId,
    ).read();
    final json = ExportWriters.json(snapshot, {
      ExportModule.medicines,
    }, now: now);
    final bundle = FocusFlowImporter.fromJson(utf8.decode(json));
    expect(bundle.medicines, hasLength(1));
    expect(bundle.medicines.single.doses, hasLength(2));

    final to = await TestHarness.create(now: now);
    addTearDown(to.dispose);
    final writer = to.read(importWriterProvider);
    var result = await writer.write(bundle);
    expect(result.imported, 1);
    expect(result.failed, 0);
    final repo = to.read(medicinesRepositoryProvider);
    await expectImported(repo);
    final m = (await repo.watchMedicines(MedicinesScope.active).first).single;
    expect(
      (await repo.doseLog(m.id, DateTime(2026, 10, 22), 1200))?.isSkipped,
      isTrue,
    );

    result = await writer.write(bundle);
    expect(result.imported, 0);
    expect(result.duplicates, 1);
  });

  test('CSV round trip', () async {
    final from = await source();
    addTearDown(from.dispose);
    final snapshot = await SnapshotIo(
      from.db,
      deviceId: TestHarness.deviceId,
    ).read();
    final csv = ExportWriters.csvFiles(snapshot, {
      ExportModule.medicines,
    })[ExportModule.medicines]!;
    final bundle = FocusFlowImporter.fromCsv(csv);
    expect(bundle.medicines, hasLength(1));

    final to = await TestHarness.create(now: now);
    addTearDown(to.dispose);
    final result = await to.read(importWriterProvider).write(bundle);
    expect(result.imported, 1);
    await expectImported(to.read(medicinesRepositoryProvider));
  });

  test('a zipped multi-module CSV export keeps its medicines', () async {
    final from = await source();
    addTearDown(from.dispose);
    final snapshot = await SnapshotIo(
      from.db,
      deviceId: TestHarness.deviceId,
    ).read();
    final zip = ExportWriters.csv(snapshot, {
      ExportModule.tasks,
      ExportModule.medicines,
    });
    expect(zip.extension, 'zip');
    final bundle = ImportDetector.parse('export.zip', zip.bytes);
    expect(bundle.medicines, hasLength(1));
  });

  test('lenient time parsing', () {
    expect(MedicineImporter.times('08:00×1; 20:00×0.5'), [
      (480, 1.0),
      (1200, 0.5),
    ]);
    expect(MedicineImporter.times('7:30, 21:00x2, nonsense'), [
      (450, 1.0),
      (1260, 2.0),
    ]);
  });
}
