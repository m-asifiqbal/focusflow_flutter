/// ============================================================
/// MEDICINE SCHEDULE — which days and times a medicine is due
/// ============================================================
///
/// Pure calendar logic shared by the lists, the detail stats and the
/// notification planner, so they all agree on what "due" means:
///   • never before [Medicine.startDate] or after [Medicine.endDate];
///   • never while paused (unless `ignorePause`: history ignores a pause,
///     so pausing never turns past doses into "not due");
///   • every day / specific weekdays / every N days from the start date;
///   • as-needed medicines are never "due" — their doses are only logged.
/// Day math works on integer day numbers ([DateUtilsX.dayNumber]), never on
/// `Duration`s between local midnights (DST).
/// ============================================================
library;

import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine_dose.dart';

abstract final class MedicineSchedule {
  /// Is [m] due on [day] at all (any dose time)?
  static bool isScheduledOn(
    Medicine m,
    DateTime day, {
    bool ignorePause = false,
  }) => isDueByNumber(m, DateUtilsX.dayNumber(day), ignorePause: ignorePause);

  /// [isScheduledOn] for a day number (see [DateUtilsX.dayNumber]).
  static bool isDueByNumber(Medicine m, int dayNo, {bool ignorePause = false}) {
    if (m.isAsNeeded || m.doses.isEmpty) return false;
    if (m.isPaused && !ignorePause) return false;
    final offset = dayNo - DateUtilsX.dayNumber(m.startDate);
    if (offset < 0) return false;
    final end = m.endDate;
    if (end != null && dayNo > DateUtilsX.dayNumber(end)) return false;
    return switch (m.schedule) {
      MedicineScheduleType.everyDay => true,
      MedicineScheduleType.specificDays =>
        // Day number 0 (1970-01-01) was a Thursday → Monday-based index.
        m.weekdaysMask & (1 << ((dayNo + 3) % 7)) != 0,
      MedicineScheduleType.everyNDays =>
        m.everyNDays <= 1 || offset % m.everyNDays == 0,
      MedicineScheduleType.asNeeded => false,
    };
  }

  /// The doses of [m] due on [day] (sorted by time), each with its log from
  /// [logsById] when one exists.
  static List<DoseSlot> slotsOn(
    Medicine m,
    DateTime day,
    Map<String, DoseLog> logsById, {
    bool ignorePause = false,
  }) {
    if (!isScheduledOn(m, day, ignorePause: ignorePause)) return const [];
    final date = DateUtilsX.dateOnly(day);
    final key = DateUtilsX.dayKey(date);
    final seen = <int>{};
    final out = <DoseSlot>[];
    for (final d in [...m.doses]..sort()) {
      if (!seen.add(d.minutes)) continue;
      final log = logsById[DoseLog.idFor(m.id, key, d.minutes)];
      out.add(
        DoseSlot(
          medicine: m,
          day: date,
          minutes: d.minutes,
          quantity: log?.isTaken ?? false ? log!.quantity : d.quantity,
          log: log,
        ),
      );
    }
    return out;
  }

  /// Every dose of [medicines] on [day], soonest first (ties by name):
  /// scheduled doses plus the as-needed doses logged that day.
  static List<DoseSlot> dayPlan(
    Iterable<Medicine> medicines,
    DateTime day,
    Iterable<DoseLog> logs,
  ) {
    final date = DateUtilsX.dateOnly(day);
    final key = DateUtilsX.dayKey(date);
    final byId = {
      for (final l in logs)
        if (l.dayKey == key) l.id: l,
    };
    final out = <DoseSlot>[];
    for (final m in medicines) {
      out.addAll(slotsOn(m, date, byId));
      for (final l in byId.values) {
        if (l.medicineId != m.id || !l.isAsNeeded || !l.isTaken) continue;
        out.add(
          DoseSlot(
            medicine: m,
            day: date,
            minutes: l.slotMinutes,
            quantity: l.quantity,
            log: l,
          ),
        );
      }
    }
    out.sort((a, b) {
      final t = a.minutes.compareTo(b.minutes);
      return t != 0
          ? t
          : a.medicine.name.toLowerCase().compareTo(
              b.medicine.name.toLowerCase(),
            );
    });
    return out;
  }

  /// Average units taken per day (for "about N days left"); null for as
  /// needed or when nothing is scheduled.
  static double? unitsPerDay(Medicine m) {
    if (m.isAsNeeded || m.doses.isEmpty) return null;
    final perDose = m.doses.fold<double>(0, (a, d) => a + d.quantity);
    final share = switch (m.schedule) {
      MedicineScheduleType.everyDay => 1.0,
      MedicineScheduleType.specificDays => _bits(m.weekdaysMask & 0x7F) / 7,
      MedicineScheduleType.everyNDays =>
        1 / (m.everyNDays < 1 ? 1 : m.everyNDays),
      MedicineScheduleType.asNeeded => 0.0,
    };
    final perDay = perDose * share;
    return perDay <= 0 ? null : perDay;
  }

  /// Whole days the stock lasts at the scheduled rate (null when unknown).
  static int? daysLeft(Medicine m) {
    final left = m.stockLeft;
    final rate = unitsPerDay(m);
    if (left == null || rate == null) return null;
    return (left / rate).floor();
  }

  static int _bits(int v) {
    var n = 0;
    for (var x = v; x != 0; x &= x - 1) {
      n++;
    }
    return n;
  }
}
