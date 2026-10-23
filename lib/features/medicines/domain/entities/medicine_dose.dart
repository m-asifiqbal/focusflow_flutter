/// ============================================================
/// MEDICINE DOSES — logged doses (DoseLog) and a day's slots (DoseSlot)
/// ============================================================
///
/// * [DoseLog] — one stored row: a dose taken, skipped, or snoozed (still
///   pending). Its id is the natural key `medicineId|yyyy-MM-dd|HH:mm`
///   ([DoseLog.idFor]); an as-needed dose uses `…|a<epoch seconds>`.
/// * [DoseSlot] — one dose *due* on a day (from the schedule), with its log
///   when there is one. The UI and the notification planner both work on
///   slots; [DoseSlot.stateAt] turns a slot + "now" into what the user sees
///   (taken, skipped, snoozed, due, upcoming or missed).
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/medicines/domain/entities/medicine.dart';

/// Stored in `medicine_doses.status` as the index — append only.
enum DoseStatus { pending, taken, skipped }

/// What a slot shows ([DoseSlot.stateAt]).
enum DoseState {
  /// Logged as taken.
  taken,

  /// Logged as skipped.
  skipped,

  /// Not logged, snoozed to a later time today.
  snoozed,

  /// Its time has come today and it is not logged yet.
  due,

  /// Later today or on a future day.
  upcoming,

  /// A past day's dose that was never logged.
  missed;

  /// Taken or skipped — nothing left to do.
  bool get isLogged => this == taken || this == skipped;

  /// Waiting for the user right now (due, or snoozed but due again).
  bool get needsAction => this == due || this == snoozed;
}

@immutable
class DoseLog {
  const DoseLog({
    required this.id,
    required this.medicineId,
    required this.dayKey,
    required this.slotMinutes,
    this.status = DoseStatus.pending,
    this.takenAt,
    this.quantity = 1,
    this.snoozedUntil,
    required this.createdAt,
    required this.updatedAt,
  });

  final String id;
  final String medicineId;

  /// Local day the dose belongs to (yyyy-MM-dd).
  final String dayKey;

  /// Scheduled minute of the day (as needed: the minute it was taken).
  final int slotMinutes;
  final DoseStatus status;

  /// When it was taken (or skipped).
  final DateTime? takenAt;
  final double quantity;
  final DateTime? snoozedUntil;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get isTaken => status == DoseStatus.taken;
  bool get isSkipped => status == DoseStatus.skipped;

  /// An as-needed dose (not tied to a scheduled time).
  bool get isAsNeeded => id.contains('|a');

  /// The natural id of the scheduled dose of [medicineId] on [dayKey] at
  /// [minutes].
  static String idFor(String medicineId, String dayKey, int minutes) =>
      '$medicineId|$dayKey|${DoseTime(minutes).hhmm}';

  /// The id of an as-needed dose taken at [at].
  static String asNeededId(String medicineId, String dayKey, DateTime at) =>
      '$medicineId|$dayKey|a${at.millisecondsSinceEpoch ~/ 1000}';

  DoseLog copyWith({
    DoseStatus? status,
    DateTime? takenAt,
    bool clearTakenAt = false,
    double? quantity,
    DateTime? snoozedUntil,
    bool clearSnooze = false,
    DateTime? updatedAt,
  }) => DoseLog(
    id: id,
    medicineId: medicineId,
    dayKey: dayKey,
    slotMinutes: slotMinutes,
    status: status ?? this.status,
    takenAt: clearTakenAt ? null : (takenAt ?? this.takenAt),
    quantity: quantity ?? this.quantity,
    snoozedUntil: clearSnooze ? null : (snoozedUntil ?? this.snoozedUntil),
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is DoseLog &&
      other.id == id &&
      other.medicineId == medicineId &&
      other.dayKey == dayKey &&
      other.slotMinutes == slotMinutes &&
      other.status == status &&
      other.takenAt == takenAt &&
      other.quantity == quantity &&
      other.snoozedUntil == snoozedUntil &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt;

  @override
  int get hashCode => Object.hash(
    id,
    medicineId,
    dayKey,
    slotMinutes,
    status,
    takenAt,
    quantity,
    snoozedUntil,
    createdAt,
    updatedAt,
  );

  @override
  String toString() => 'DoseLog($id, ${status.name})';
}

/// One dose on one day (scheduled, or an as-needed dose that was logged).
@immutable
class DoseSlot {
  const DoseSlot({
    required this.medicine,
    required this.day,
    required this.minutes,
    required this.quantity,
    this.log,
  });

  final Medicine medicine;

  /// Local midnight of the dose's day.
  final DateTime day;

  /// Minute of the day it is due.
  final int minutes;

  /// Amount due (the log's amount once taken).
  final double quantity;
  final DoseLog? log;

  String get dayKey => DateUtilsX.dayKey(day);

  /// The stored id of this dose ([DoseLog.idFor] / the as-needed log's).
  String get id => log?.id ?? DoseLog.idFor(medicine.id, dayKey, minutes);

  /// Local instant it is due.
  DateTime get at => DateUtilsX.atMinutes(day, minutes);

  /// A logged as-needed dose (no schedule behind it).
  bool get isAsNeeded => log?.isAsNeeded ?? false;

  /// What the slot shows at [now].
  DoseState stateAt(DateTime now) {
    final l = log;
    if (l != null && l.isTaken) return DoseState.taken;
    if (l != null && l.isSkipped) return DoseState.skipped;
    final today = DateUtilsX.dateOnly(now);
    final dayDiff = DateUtilsX.daysBetween(today, day);
    if (dayDiff < 0) return DoseState.missed;
    if (dayDiff > 0) return DoseState.upcoming;
    final snooze = l?.snoozedUntil;
    if (snooze != null && snooze.isAfter(now)) return DoseState.snoozed;
    return at.isAfter(now) ? DoseState.upcoming : DoseState.due;
  }

  @override
  bool operator ==(Object other) =>
      other is DoseSlot &&
      other.medicine == medicine &&
      other.day == day &&
      other.minutes == minutes &&
      other.quantity == quantity &&
      other.log == log;

  @override
  int get hashCode => Object.hash(medicine, day, minutes, quantity, log);

  @override
  String toString() =>
      'DoseSlot(${medicine.name} $dayKey ${DoseTime(minutes).hhmm})';
}
