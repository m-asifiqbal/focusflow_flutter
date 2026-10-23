/// Medicine dose notifications: one per dose time (doses due at the same
/// minute grouped), none once taken / skipped, a snoozed dose at its snooze
/// end under its own key, the "did you take it?" follow-up, alarm style,
/// the Medicine switch, quiet hours, and Taken / Snooze / Skip performed
/// from a notification against the real repository.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/notifications/notification_providers.dart';
import 'package:focusflow/core/notifications/planning/medicine_planner.dart';
import 'package:focusflow/core/notifications/planning/notification_plan.dart';
import 'package:focusflow/core/notifications/planning/notification_planner.dart';
import 'package:focusflow/core/notifications/planning/planner_input.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';
import 'package:focusflow/features/medicines/domain/repository/medicines_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

import '../../helpers/test_container.dart';
import 'planner_test_data.dart';

final _t0 = DateTime.utc(2026);

Medicine _med(
  String id, {
  String name = 'Metformin',
  List<DoseTime> doses = const [DoseTime(8 * 60), DoseTime(20 * 60)],
  bool alarm = false,
  int followUp = 30,
  double? stock,
  double? refillAt,
}) => Medicine(
  id: id,
  name: name,
  strength: '500 mg',
  doses: doses,
  startDate: DateTime(2026, 10, 1),
  alarmStyle: alarm,
  followUpMinutes: followUp,
  stockLeft: stock,
  refillAt: refillAt,
  createdAt: _t0,
  updatedAt: _t0,
);

DoseLog _log(
  Medicine m,
  String day,
  int minutes, {
  DoseStatus status = DoseStatus.taken,
  DateTime? snoozedUntil,
}) => DoseLog(
  id: DoseLog.idFor(m.id, day, minutes),
  medicineId: m.id,
  dayKey: day,
  slotMinutes: minutes,
  status: status,
  snoozedUntil: snoozedUntil,
  createdAt: _t0,
  updatedAt: _t0,
);

void main() {
  // 07:00 UTC on Oct 23 (the planner works in the UTC zone here).
  final now = DateTime.utc(2026, 10, 23, 7);
  final on = quiet.copyWith(notifyMedicines: true);

  PlannerInput medInput(
    List<MedicineWithDoses> meds, {
    AppSettings? settings,
    DateTime? at,
    int horizonDays = 1,
  }) => PlannerInput(
    now: at ?? now,
    calendar: zone('UTC'),
    settings: settings ?? on,
    medicines: meds,
    horizonDays: horizonDays,
    vitalHorizonDays: horizonDays,
  );

  List<PlannedNotification> plan(
    List<MedicineWithDoses> meds, {
    AppSettings? settings,
    DateTime? at,
  }) => MedicinePlanner.plan(
    medInput(meds, settings: settings, at: at),
    DateTime.utc(2026, 10, 24),
  );

  test('one notification per dose time, plus its follow-up', () {
    final m = _med('a');
    final out = plan([MedicineWithDoses(medicine: m, logs: const [])]);
    expect(out.map((n) => n.key).toList()..sort(), [
      'med:2026-10-23:1200',
      'med:2026-10-23:1200:f',
      'med:2026-10-23:480',
      'med:2026-10-23:480:f',
    ]);
    final dose = out.firstWhere((n) => n.key == 'med:2026-10-23:480');
    expect(dose.fireAt.toUtc(), DateTime.utc(2026, 10, 23, 8));
    expect(dose.category, NotificationCategory.medicine);
    expect(dose.title, 'Time for Metformin');
    expect(dose.body, '500 mg · 1 tablet');
    expect(dose.buttons, [
      NotificationButton.taken,
      NotificationButton.snooze,
      NotificationButton.skip,
    ]);
    expect(dose.payload.doses, ['a']);
    expect(dose.payload.day, '2026-10-23');
    expect(dose.inbox, isTrue);
    expect(NotificationPlanner.isVital(dose), isTrue);
    final follow = out.firstWhere((n) => n.key == 'med:2026-10-23:480:f');
    expect(follow.fireAt.toUtc(), DateTime.utc(2026, 10, 23, 8, 30));
    expect(follow.title, 'Did you take your 8:00 AM dose?');
    expect(follow.inbox, isFalse);
    expect(NotificationPlanner.isVital(follow), isFalse);
  });

  test('doses at the same minute share one notification', () {
    final a = _med('a', doses: const [DoseTime(480)], followUp: 0);
    final b = _med(
      'b',
      name: 'Vitamin D3',
      doses: const [DoseTime(480)],
      followUp: 0,
    );
    final out = plan([
      MedicineWithDoses(medicine: a, logs: const []),
      MedicineWithDoses(medicine: b, logs: const []),
    ]);
    expect(out, hasLength(1));
    expect(out.single.title, 'Time for 2 medicines');
    expect(out.single.payload.doses, unorderedEquals(['a', 'b']));
    expect(out.single.payload.open, isNull);
    expect(out.single.payload.route, isNotNull);
  });

  test('taken or skipped doses are not planned (nor their follow-up)', () {
    final m = _med('a');
    final out = plan([
      MedicineWithDoses(
        medicine: m,
        logs: [
          _log(m, '2026-10-23', 480),
          _log(m, '2026-10-23', 1200, status: DoseStatus.skipped),
        ],
      ),
    ]);
    expect(out, isEmpty);
  });

  test('a snoozed dose fires at the snooze end under its own key', () {
    final m = _med('a', doses: const [DoseTime(480)]);
    final until = DateTime.utc(2026, 10, 23, 8, 20);
    final out = plan([
      MedicineWithDoses(
        medicine: m,
        logs: [
          _log(
            m,
            '2026-10-23',
            480,
            status: DoseStatus.pending,
            snoozedUntil: until,
          ),
        ],
      ),
    ], at: DateTime.utc(2026, 10, 23, 8, 5));
    expect(out.map((n) => n.key), ['med:2026-10-23:480:s']);
    expect(out.single.fireAt.toUtc(), until);
    expect(NotificationPlanner.isVital(out.single), isTrue);
  });

  test('alarm style rings as an alarm; its follow-up does not', () {
    final m = _med('a', doses: const [DoseTime(480)], alarm: true);
    final out = plan([MedicineWithDoses(medicine: m, logs: const [])]);
    final byKey = {for (final n in out) n.key: n};
    expect(byKey['med:2026-10-23:480']!.category, NotificationCategory.alarm);
    expect(
      byKey['med:2026-10-23:480:f']!.category,
      NotificationCategory.medicine,
    );
  });

  test('low stock is mentioned in the dose text', () {
    final m = _med('a', doses: const [DoseTime(480)], stock: 3, refillAt: 5);
    final out = plan([MedicineWithDoses(medicine: m, logs: const [])]);
    expect(out.first.body, '500 mg · 1 tablet · 3 tablets left');
  });

  test('the Medicine switch turns them all off', () {
    final m = _med('a');
    expect(
      plan([MedicineWithDoses(medicine: m, logs: const [])], settings: quiet),
      isEmpty,
    );
  });

  test('doses ignore quiet hours', () {
    final m = _med('a', doses: const [DoseTime(23 * 60)], followUp: 0);
    final settings = on.copyWith(
      quietHours: true,
      quietStartMinutes: 22 * 60,
      quietEndMinutes: 7 * 60,
    );
    final out = NotificationPlanner.plan(
      medInput([
        MedicineWithDoses(medicine: m, logs: const []),
      ], settings: settings),
      until: DateTime.utc(2026, 10, 24),
    );
    expect(out.single.fireAt.toUtc(), DateTime.utc(2026, 10, 23, 23));
  });

  test('stillWanted follows the logs', () {
    final m = _med('a');
    final pending = medInput([MedicineWithDoses(medicine: m, logs: const [])]);
    final taken = medInput([
      MedicineWithDoses(medicine: m, logs: [_log(m, '2026-10-23', 480)]),
    ]);
    expect(
      NotificationPlanner.stillWanted(pending, 'med:2026-10-23:480'),
      isTrue,
    );
    expect(
      NotificationPlanner.stillWanted(taken, 'med:2026-10-23:480:f'),
      isFalse,
    );
  });

  group('actions', () {
    late TestHarness h;
    late MedicinesRepository repo;
    final day = DateTime(2026, 10, 23);

    setUp(() async {
      h = await TestHarness.create(now: DateTime(2026, 10, 23, 8, 2));
      repo = h.read(medicinesRepositoryProvider);
    });

    tearDown(() => h.dispose());

    Future<String> add(String name) => repo.save(
      Medicine.draft(startDate: day, name: name).copyWith(stockLeft: 10),
    );

    NotificationPayload payload(List<String> ids) => NotificationPayload(
      key: 'med:2026-10-23:480',
      category: NotificationCategory.medicine,
      target: ItemRef(ItemType.medicine, ids.first),
      day: '2026-10-23',
      snoozeMinutes: 10,
      doses: ids,
    );

    test('Taken marks every grouped dose and moves the stock', () async {
      final a = await add('A');
      final b = await add('B');
      final actions = h.read(notificationActionsProvider);
      expect(
        await actions.perform(NotificationButton.taken, payload([a, b])),
        isTrue,
      );
      expect((await repo.doseLog(a, day, 480))!.isTaken, isTrue);
      expect((await repo.doseLog(b, day, 480))!.isTaken, isTrue);
      expect((await repo.getMedicine(a))!.stockLeft, 9);
    });

    test('Snooze snoozes from now; Skip skips', () async {
      final a = await add('A');
      final actions = h.read(notificationActionsProvider);
      await actions.perform(NotificationButton.snooze, payload([a]));
      final log = (await repo.doseLog(a, day, 480))!;
      expect(log.status, DoseStatus.pending);
      expect(log.snoozedUntil, DateTime(2026, 10, 23, 8, 12));
      await actions.perform(NotificationButton.skip, payload([a]));
      expect((await repo.doseLog(a, day, 480))!.isSkipped, isTrue);
    });

    test('a deleted medicine is ignored', () async {
      final actions = h.read(notificationActionsProvider);
      expect(
        await actions.perform(NotificationButton.taken, payload(['gone'])),
        isFalse,
      );
    });
  });
}
