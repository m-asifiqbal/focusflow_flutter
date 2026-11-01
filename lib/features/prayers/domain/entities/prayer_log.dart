/// ============================================================
/// PRAYER LOG — what happened to one prayer on one day
/// ============================================================
///
/// What: [PrayerStatus] (on time / late / made up / missed / excused, or
/// pending while snoozed) plus where it was prayed, whether in
/// congregation, and a tally for counting practices. For a fast the same
/// statuses read "Fasted" / "Broken" / "Made up" / "Not fasted" / "Excused".
/// Why: the id is the natural key `prayerId|yyyy-MM-dd`, so one day logged
/// on two devices merges into one row (last write wins), like medicine
/// doses. A day without a row is "not marked" — the UI shows it as missed
/// once the window has ended, without writing anything.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';

enum PrayerStatus {
  /// Logged but not done yet (snoozed from a notification).
  pending,
  onTime,
  late,
  madeUp,
  missed,
  excused;

  /// Counts as done (on time, late or made up).
  bool get done => this == onTime || this == late || this == madeUp;

  String labelFor(PrayerKind kind) => kind.isFast
      ? switch (this) {
          pending => tr('Not marked'),
          onTime => tr('Fasted'),
          late => tr('Broken early'),
          madeUp => tr('Made up'),
          missed => tr('Not fasted'),
          excused => tr('Excused'),
        }
      : switch (this) {
          pending => tr('Not marked'),
          onTime => tr('On time'),
          late => tr('Late'),
          madeUp => tr('Made up'),
          missed => tr('Missed'),
          excused => tr('Excused'),
        };

  static PrayerStatus fromIndex(int i) => values[i.clamp(0, values.length - 1)];
}

@immutable
class PrayerLog {
  const PrayerLog({
    required this.prayerId,
    required this.day,
    required this.status,
    this.loggedAt,
    this.place,
    this.congregation = false,
    this.count = 0,
    this.snoozedUntil,
    this.updatedAt,
  });

  final String prayerId;

  /// Local day (date only).
  final DateTime day;
  final PrayerStatus status;
  final DateTime? loggedAt;

  /// Where it was prayed (null = the prayer's usual place).
  final String? place;
  final bool congregation;

  /// Tally of a counting practice.
  final int count;
  final DateTime? snoozedUntil;
  final DateTime? updatedAt;

  String get id => idFor(prayerId, DateUtilsX.dayKey(day));

  /// Natural key of a prayer's day.
  static String idFor(String prayerId, String dayKey) => '$prayerId|$dayKey';

  PrayerLog copyWith({
    PrayerStatus? status,
    DateTime? loggedAt,
    String? place,
    bool clearPlace = false,
    bool? congregation,
    int? count,
    DateTime? snoozedUntil,
    bool clearSnooze = false,
  }) => PrayerLog(
    prayerId: prayerId,
    day: day,
    status: status ?? this.status,
    loggedAt: loggedAt ?? this.loggedAt,
    place: clearPlace ? null : (place ?? this.place),
    congregation: congregation ?? this.congregation,
    count: count ?? this.count,
    snoozedUntil: clearSnooze ? null : (snoozedUntil ?? this.snoozedUntil),
    updatedAt: updatedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is PrayerLog &&
      other.prayerId == prayerId &&
      other.day == day &&
      other.status == status &&
      other.loggedAt == loggedAt &&
      other.place == place &&
      other.congregation == congregation &&
      other.count == count &&
      other.snoozedUntil == snoozedUntil;

  @override
  int get hashCode => Object.hash(
    prayerId,
    day,
    status,
    loggedAt,
    place,
    congregation,
    count,
    snoozedUntil,
  );

  @override
  String toString() => 'PrayerLog($id, ${status.name})';
}
