/// ============================================================
/// MEDICINE ROW MAPPER — Drift rows ⇄ medicine domain entities
/// ============================================================
///
/// Storage details live here: dose times as a JSON array
/// `[{"t":"08:00","q":1}]`, days as `yyyy-MM-dd`, enums as their index
/// (clamped, so a value written by a newer app version never crashes).
/// ============================================================
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';

abstract final class MedicineRowMapper {
  /// Dose times from the stored JSON (bad entries dropped), sorted.
  static List<DoseTime> decodeDoses(String json) {
    try {
      final list = jsonDecode(json);
      if (list is! List) return const [];
      final out = <DoseTime>[];
      for (final e in list) {
        if (e is! Map) continue;
        final t = e['t'];
        final minutes = t is String ? DoseTime.parse(t) : null;
        if (minutes == null) continue;
        final q = e['q'];
        out.add(DoseTime(minutes, q is num && q > 0 ? q.toDouble() : 1));
      }
      return List.unmodifiable(out..sort());
    } on FormatException {
      return const [];
    }
  }

  static String encodeDoses(List<DoseTime> doses) => jsonEncode([
    for (final d in [...doses]..sort()) {'t': d.hhmm, 'q': d.quantity},
  ]);

  static T _enum<T>(List<T> values, int index) =>
      values[index.clamp(0, values.length - 1)];

  /// Row + its tags → [Medicine].
  static Medicine medicine(MedicineRow r, List<Tag> tags) => Medicine(
    id: r.id,
    name: r.name,
    strength: r.strength,
    form: _enum(MedicineForm.values, r.form),
    note: r.note,
    foodTiming: _enum(FoodTiming.values, r.foodTiming),
    schedule: _enum(MedicineScheduleType.values, r.scheduleType),
    weekdaysMask: r.weekdaysMask & 0x7F,
    everyNDays: r.everyNDays < 1 ? 1 : r.everyNDays,
    doses: decodeDoses(r.dosesJson),
    startDate: DateUtilsX.parseDayKey(r.startDate),
    endDate: r.endDate == null ? null : DateUtilsX.parseDayKey(r.endDate!),
    stockLeft: r.stockLeft,
    refillAt: r.refillAt,
    packSize: r.packSize,
    reminderEnabled: r.reminderEnabled,
    alarmStyle: r.alertStyle == 1,
    snoozeMinutes: r.snoozeMinutes,
    followUpMinutes: r.followUpMinutes,
    isPaused: r.isPaused,
    colorHex: r.colorHex,
    isPinned: r.isPinned,
    isFavorite: r.isFavorite,
    tags: tags,
    sortOrder: r.sortOrder,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
    archivedAt: r.archivedAt,
    deletedAt: r.deletedAt,
  );

  static DoseLog dose(MedicineDoseRow r) => DoseLog(
    id: r.id,
    medicineId: r.medicineId,
    dayKey: r.date,
    slotMinutes: r.slotMinutes,
    status: _enum(DoseStatus.values, r.status),
    takenAt: r.takenAt,
    quantity: r.quantity,
    snoozedUntil: r.snoozedUntil,
    createdAt: r.createdAt,
    updatedAt: r.updatedAt,
  );

  /// Every column of a new medicine (no id, timestamps or sync fields).
  static MedicinesCompanion content(Medicine m) => editorContent(m).copyWith(
    isPaused: Value(m.isPaused),
    isPinned: Value(m.isPinned),
    isFavorite: Value(m.isFavorite),
  );

  /// The columns the medicine editor owns. Updates write only these, so a
  /// stale editor draft never reverts a pause / pin / favourite changed
  /// meanwhile — nor the stock, which every dose taken changes.
  static MedicinesCompanion editorContent(Medicine m) => MedicinesCompanion(
    name: Value(m.name.trim()),
    strength: Value(m.strength.trim()),
    form: Value(m.form.index),
    note: Value(m.note.trim()),
    foodTiming: Value(m.foodTiming.index),
    scheduleType: Value(m.schedule.index),
    weekdaysMask: Value(m.weekdaysMask & 0x7F),
    everyNDays: Value(m.everyNDays < 1 ? 1 : m.everyNDays),
    dosesJson: Value(encodeDoses(m.isAsNeeded ? const [] : m.doses)),
    startDate: Value(DateUtilsX.dayKey(m.startDate)),
    endDate: Value(m.endDate == null ? null : DateUtilsX.dayKey(m.endDate!)),
    refillAt: Value(m.refillAt),
    reminderEnabled: Value(m.reminderEnabled),
    alertStyle: Value(m.alarmStyle ? 1 : 0),
    snoozeMinutes: Value(m.snoozeMinutes),
    followUpMinutes: Value(m.followUpMinutes),
    colorHex: Value(m.colorHex),
  );
}
