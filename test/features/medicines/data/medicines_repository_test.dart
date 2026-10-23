/// MedicinesRepository over the real encrypted database: saving, the day
/// plan, dose writes and the stock they move, undo, snooze, as-needed
/// doses, the planner's input, and the shared lifecycle (delete forever
/// takes the doses along).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../../helpers/test_container.dart';

void main() {
  late TestHarness h;
  late MedicinesRepository repo;
  final today = DateTime(2026, 10, 23);

  setUp(() async {
    h = await TestHarness.create(now: DateTime(2026, 10, 23, 9));
    repo = h.read(medicinesRepositoryProvider);
  });

  tearDown(() => h.dispose());

  Future<String> add({
    String name = 'Metformin',
    double? stock = 10,
    List<DoseTime> doses = const [DoseTime(8 * 60), DoseTime(20 * 60)],
    MedicineScheduleType schedule = MedicineScheduleType.everyDay,
  }) => repo.save(
    Medicine.draft(startDate: today, name: name).copyWith(
      doses: doses,
      schedule: schedule,
      stockLeft: stock,
      refillAt: 5,
      clearStock: stock == null,
    ),
  );

  test('save + read back, and the day plan', () async {
    final id = await add();
    final m = (await repo.getMedicine(id))!;
    expect(m.name, 'Metformin');
    expect(m.doses.map((d) => d.minutes), [480, 1200]);
    expect(m.stockLeft, 10);
    expect(m.packSize, 10);
    final day = await repo.watchDay(today).first;
    expect(day.medicines.single.id, id);
    expect(day.slots.map((s) => s.minutes), [480, 1200]);
  });

  test('taking a dose lowers the stock; undo gives it back', () async {
    final id = await add();
    await repo.markTaken(id, today, 480);
    expect((await repo.getMedicine(id))!.stockLeft, 9);
    // Taking it again changes nothing (no double count).
    await repo.markTaken(id, today, 480);
    expect((await repo.getMedicine(id))!.stockLeft, 9);
    // Skip after taken: the unit comes back.
    await repo.markSkipped(id, today, 480);
    expect((await repo.getMedicine(id))!.stockLeft, 10);
    expect((await repo.doseLog(id, today, 480))!.isSkipped, true);
    // Undo to "not logged".
    await repo.restoreDose(id, today, 480, null);
    expect(await repo.doseLog(id, today, 480), isNull);
    expect((await repo.getMedicine(id))!.stockLeft, 10);
  });

  test('the stock never goes below zero', () async {
    final id = await add(stock: 0.5);
    await repo.markTaken(id, today, 480);
    expect((await repo.getMedicine(id))!.stockLeft, 0);
  });

  test('snooze keeps the dose pending; taking clears the snooze', () async {
    final id = await add();
    final until = DateTime(2026, 10, 23, 8, 10);
    await repo.snooze(id, today, 480, until);
    var log = (await repo.doseLog(id, today, 480))!;
    expect(log.status, DoseStatus.pending);
    expect(log.snoozedUntil, until);
    await repo.markTaken(id, today, 480);
    log = (await repo.doseLog(id, today, 480))!;
    expect(log.isTaken, true);
    expect(log.snoozedUntil, isNull);
  });

  test('as-needed doses: log, show on the day, delete', () async {
    final id = await add(
      name: 'Ibuprofen',
      doses: const [],
      schedule: MedicineScheduleType.asNeeded,
    );
    final doseId = await repo.logAsNeeded(
      id,
      DateTime(2026, 10, 23, 14, 30),
      2,
    );
    expect((await repo.getMedicine(id))!.stockLeft, 8);
    final day = await repo.watchDay(today).first;
    expect(day.slots.single.isAsNeeded, true);
    expect(day.asNeeded.single.id, id);
    await repo.deleteAsNeeded(doseId);
    expect((await repo.getMedicine(id))!.stockLeft, 10);
    expect((await repo.watchDay(today).first).slots, isEmpty);
  });

  test('refill adds to the stock and remembers the pack size', () async {
    final id = await add(stock: 3);
    expect((await repo.watchDay(today).first).lowStock.single.id, id);
    await repo.refill(id, 30);
    final m = (await repo.getMedicine(id))!;
    expect(m.stockLeft, 33);
    expect(m.packSize, 30);
    expect((await repo.watchDay(today).first).lowStock, isEmpty);
  });

  test('editor saves never overwrite the stock unless asked', () async {
    final id = await add();
    final draft = (await repo.getMedicine(id))!;
    await repo.markTaken(id, today, 480); // stock 9, draft still says 10
    await repo.save(draft.copyWith(name: 'Metformin XR'));
    var m = (await repo.getMedicine(id))!;
    expect(m.name, 'Metformin XR');
    expect(m.stockLeft, 9);
    await repo.save(m.copyWith(stockLeft: 50), writeStock: true);
    m = (await repo.getMedicine(id))!;
    expect(m.stockLeft, 50);
  });

  test('schedulable: active, not paused, reminders on, with logs', () async {
    final a = await add(name: 'A');
    final b = await add(name: 'B');
    await add(
      name: 'C',
      doses: const [],
      schedule: MedicineScheduleType.asNeeded,
    );
    await repo.setPaused(b, true);
    await repo.markTaken(a, today, 480);
    final list = await repo.schedulable(today, today);
    expect(list.map((w) => w.medicine.name), ['A']);
    expect(list.single.logs.single.slotMinutes, 480);
  });

  test('delete forever removes the doses (and archive hides it)', () async {
    final id = await add();
    await repo.markTaken(id, today, 480);
    final items = h.read(itemsRepositoryProvider);
    final ref = ItemRef(ItemType.medicine, id);
    await items.archive([ref]);
    expect(await repo.watchMedicines(MedicinesScope.active).first, isEmpty);
    expect(
      (await repo.watchMedicines(MedicinesScope.archived).first).single.id,
      id,
    );
    await items.deleteForever([ref]);
    expect(await repo.getMedicine(id), isNull);
    expect(await h.db.select(h.db.medicineDoses).get(), isEmpty);
  });

  test('library counts include medicines and today\'s doses', () async {
    final id = await add();
    await repo.markTaken(id, today, 480);
    final c = await h
        .read(itemsRepositoryProvider)
        .watchLibraryCounts(now: DateTime(2026, 10, 23, 9))
        .first;
    expect(c.medicinesTotal, 1);
    expect(c.medicinesDueToday, 2);
    expect(c.medicinesTakenToday, 1);
  });
}
