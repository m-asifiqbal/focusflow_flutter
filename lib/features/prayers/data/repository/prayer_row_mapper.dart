/// ============================================================
/// PRAYER ROW MAPPER — `prayers` / `prayer_logs` rows ⇄ entities
/// ============================================================
///
/// Unknown stored values (a kind or sun event written by a newer version,
/// an out-of-range priority) fall back to safe defaults instead of failing
/// the whole list.
/// ============================================================
library;

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer_log.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

abstract final class PrayerRowMapper {
  static SolarEvent? _event(String? name) =>
      name == null ? null : SolarEvent.values.asNameMap()[name];

  static int _minute(int m) => m.clamp(0, 24 * 60 - 1);

  /// Row + its tags → [Prayer].
  static Prayer prayer(PrayerRow r, List<Tag> tags) {
    final startEvent = _event(r.startEvent);
    final endEvent = _event(r.endEvent);
    final endMinutes = r.endMinutes;
    return Prayer(
      id: r.id,
      name: r.name,
      kind: PrayerKind.fromKey(r.kind),
      tradition: PrayerTradition.fromKey(r.tradition),
      start: startEvent == null
          ? PrayerTimeRule.fixed(_minute(r.startMinutes))
          : PrayerTimeRule.auto(
              startEvent,
              offset: r.startOffset,
              minutes: _minute(r.startMinutes),
            ),
      end: endEvent != null
          ? PrayerTimeRule.auto(
              endEvent,
              offset: r.endOffset,
              minutes: _minute(endMinutes ?? r.startMinutes + 60),
            )
          : endMinutes == null
          ? null
          : PrayerTimeRule.fixed(_minute(endMinutes)),
      weekdaysMask: r.weekdaysMask & 0x7F,
      startDate: r.startDate == null
          ? null
          : DateUtilsX.parseDayKey(r.startDate!),
      endDate: r.endDate == null ? null : DateUtilsX.parseDayKey(r.endDate!),
      priority: PrayerPriority.fromIndex(r.priority),
      remindBefore: r.remindBefore,
      remindBeforeEnd: r.remindBeforeEnd,
      sound: r.sound,
      snoozeMinutes: r.snoozeMinutes,
      place: r.place,
      note: r.note,
      targetCount: r.targetCount,
      jamaat: switch (r.jamaatMinutes) {
        null => null,
        final m when r.jamaatAfterStart => PrayerJamaat.afterStart(
          m.clamp(0, 24 * 60),
        ),
        final m => PrayerJamaat.at(_minute(m)),
      },
      remindBeforeJamaat: r.jamaatMinutes == null ? null : r.remindBeforeJamaat,
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
  }

  /// The columns the editor writes (not id / lifecycle / sync / order /
  /// pinned / favourite / paused).
  static PrayersCompanion content(Prayer p) {
    final end = p.end;
    return PrayersCompanion(
      name: Value(p.name.trim()),
      kind: Value(p.kind.key),
      tradition: Value(p.tradition.key),
      startEvent: Value(p.start.event?.name),
      startOffset: Value(p.start.offset),
      startMinutes: Value(_minute(p.start.minutes)),
      endEvent: Value(end?.event?.name),
      endOffset: Value(end?.offset ?? 0),
      endMinutes: Value(end == null ? null : _minute(end.minutes)),
      weekdaysMask: Value(p.weekdaysMask & 0x7F),
      startDate: Value(
        p.startDate == null ? null : DateUtilsX.dayKey(p.startDate!),
      ),
      endDate: Value(p.endDate == null ? null : DateUtilsX.dayKey(p.endDate!)),
      priority: Value(p.priority.index),
      remindBefore: Value(p.remindBefore),
      remindBeforeEnd: Value(p.remindBeforeEnd),
      sound: Value(p.sound),
      snoozeMinutes: Value(p.snoozeMinutes),
      place: Value(p.place.trim()),
      note: Value(p.note),
      targetCount: Value(p.targetCount),
      jamaatMinutes: Value(p.jamaat?.minutes),
      jamaatAfterStart: Value(p.jamaat?.afterStart ?? false),
      remindBeforeJamaat: Value(p.jamaat == null ? null : p.remindBeforeJamaat),
      colorHex: Value(p.colorHex),
    );
  }

  static PrayerLog log(PrayerLogRow r) => PrayerLog(
    prayerId: r.prayerId,
    day: DateUtilsX.parseDayKey(r.date),
    status: PrayerStatus.fromIndex(r.status),
    loggedAt: r.loggedAt,
    place: r.place,
    congregation: r.congregation,
    count: r.count,
    snoozedUntil: r.snoozedUntil,
    updatedAt: r.updatedAt,
  );
}
