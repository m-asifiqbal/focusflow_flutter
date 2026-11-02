/// ============================================================
/// PRAYER — a daily prayer / practice with a start-to-end window
/// ============================================================
///
/// What: the entity of the Prayer module (ItemType.prayer) — Fajr, a
/// morning prayer, a Ramadan fast, a dhikr goal. Each end of its window is a
/// [PrayerTimeRule]: either a sun event of the day (dawn, sunset … computed
/// offline from the saved location) ± minutes, or a fixed clock time. It
/// can repeat on chosen weekdays and optionally only within a date range.
/// Why: one model for every tradition — the kinds and presets give the words,
/// the rules give the times. Plain immutable data; scheduling, windows and
/// statistics are pure services in `domain/services/`.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/features/prayers/domain/entities/calendar_rule.dart';
import 'package:focusflow/features/prayers/domain/services/prayer_times.dart';

/// What kind of practice it is (words and defaults follow it).
enum PrayerKind {
  salah('salah'),
  nafl('nafl'),
  fasting('fasting'),
  dhikr('dhikr'),
  recitation('recitation'),
  meditation('meditation'),
  service('service'),
  custom('custom');

  const PrayerKind(this.key);

  final String key;

  String get label => switch (this) {
    salah => tr('Prayer (salah)'),
    nafl => tr('Voluntary prayer'),
    fasting => tr('Fasting'),
    dhikr => tr('Remembrance (dhikr)'),
    recitation => tr('Recitation or reading'),
    meditation => tr('Meditation'),
    service => tr('Service or worship'),
    custom => tr('Other'),
  };

  /// Short chip label.
  String get short => switch (this) {
    salah => tr('Salah'),
    nafl => tr('Nafl'),
    fasting => tr('Fasting'),
    dhikr => tr('Dhikr'),
    recitation => tr('Recitation'),
    meditation => tr('Meditation'),
    service => tr('Service'),
    custom => tr('Other'),
  };

  bool get isFast => this == fasting;

  /// Counted with a tally and a daily goal.
  bool get counts => this == dhikr;

  static PrayerKind fromKey(String? key) =>
      values.where((k) => k.key == key).firstOrNull ?? custom;
}

/// The tradition a prayer's preset came from (setup picker).
enum PrayerTradition {
  islam('islam'),
  christianity('christianity'),
  hinduism('hinduism'),
  buddhism('buddhism'),
  judaism('judaism'),
  custom('custom');

  const PrayerTradition(this.key);

  final String key;

  String get label => switch (this) {
    islam => tr('Islam'),
    christianity => tr('Christianity'),
    hinduism => tr('Hinduism'),
    buddhism => tr('Buddhism'),
    judaism => tr('Judaism'),
    custom => tr('Your own practice'),
  };

  /// The tradition uses sun-based times (Islamic prayer windows).
  bool get solar => this == islam;

  static PrayerTradition fromKey(String? key) =>
      values.where((t) => t.key == key).firstOrNull ?? custom;
}

/// How loudly a prayer reminds.
enum PrayerPriority {
  /// A quiet notification.
  low,

  /// A normal notification.
  normal,

  /// A real alarm (rings, full screen, auto-snooze).
  high;

  String get label => switch (this) {
    low => tr('Low'),
    normal => tr('Normal'),
    high => tr('High'),
  };

  static PrayerPriority fromIndex(int i) =>
      values[i.clamp(0, values.length - 1)];
}

/// One end of a prayer's window: a sun event ± [offset] minutes ([event]
/// set, "auto"), or the fixed minute of the day [minutes] ("manual"). An
/// auto rule keeps [minutes] as its fallback while no location is saved.
@immutable
class PrayerTimeRule {
  const PrayerTimeRule.auto(
    SolarEvent this.event, {
    this.offset = 0,
    this.minutes = 0,
  });
  const PrayerTimeRule.fixed(this.minutes) : event = null, offset = 0;

  final SolarEvent? event;
  final int offset;
  final int minutes;

  bool get isAuto => event != null;

  /// The instant on [day] (only its y/m/d count): the sun event of [sun]
  /// plus the offset, or the fixed time — also when [sun] is null (no
  /// location yet).
  DateTime on(DateTime day, SolarDay? sun) {
    final e = event;
    if (e != null && sun != null) {
      return sun.at(e).add(Duration(minutes: offset));
    }
    return DateTime(day.year, day.month, day.day, 0, minutes);
  }

  PrayerTimeRule withOffset(int offset) => event == null
      ? this
      : PrayerTimeRule.auto(event!, offset: offset, minutes: minutes);

  @override
  bool operator ==(Object other) =>
      other is PrayerTimeRule &&
      other.event == event &&
      other.offset == offset &&
      other.minutes == minutes;

  @override
  int get hashCode => Object.hash(event, offset, minutes);

  @override
  String toString() => event == null
      ? 'fixed($minutes)'
      : 'auto(${event!.name}${offset == 0 ? '' : '$offset'})';
}

/// When the congregation prays (the mosque's jamaat, a church service):
/// a set clock time, a number of minutes after the window opens (Maghrib
/// "10 minutes after the adhan" follows the sun by itself), or — for the
/// five daily prayers — an offline estimate of a typical mosque's time
/// (PrayerJamaatEstimate), which moves with the seasons too.
@immutable
class PrayerJamaat {
  /// At [minutes] after midnight.
  const PrayerJamaat.at(this.minutes) : afterStart = false, estimated = false;

  /// [minutes] after the window's start.
  const PrayerJamaat.afterStart(this.minutes)
    : afterStart = true,
      estimated = false;

  /// A typical time for this daily prayer, worked out each day. Stored as
  /// "after start, 0" plus a flag, so an app without the flag still shows
  /// a jamaat (at the start) rather than none.
  const PrayerJamaat.estimated()
    : minutes = 0,
      afterStart = true,
      estimated = true;

  final int minutes;
  final bool afterStart;
  final bool estimated;

  @override
  bool operator ==(Object other) =>
      other is PrayerJamaat &&
      other.minutes == minutes &&
      other.afterStart == afterStart &&
      other.estimated == estimated;

  @override
  int get hashCode => Object.hash(minutes, afterStart, estimated);

  @override
  String toString() => estimated
      ? 'jamaat(~)'
      : afterStart
      ? 'jamaat(+$minutes)'
      : 'jamaat(@$minutes)';
}

@immutable
class Prayer {
  const Prayer({
    required this.id,
    required this.name,
    this.kind = PrayerKind.custom,
    this.tradition = PrayerTradition.custom,
    required this.start,
    this.end,
    this.weekdaysMask = everyDay,
    this.startDate,
    this.endDate,
    this.calendar,
    this.priority = PrayerPriority.normal,
    this.remindBefore = 0,
    this.remindBeforeEnd,
    this.sound = 'chime',
    this.snoozeMinutes = 10,
    this.place = '',
    this.note = '',
    this.targetCount,
    this.jamaat,
    this.remindBeforeJamaat,
    this.isPaused = false,
    this.colorHex,
    this.isPinned = false,
    this.isFavorite = false,
    this.tags = const [],
    this.sortOrder = 0,
    required this.createdAt,
    required this.updatedAt,
    this.archivedAt,
    this.deletedAt,
  });

  /// An unsaved prayer for the editor (empty id).
  factory Prayer.draft({
    String name = '',
    PrayerKind kind = PrayerKind.salah,
    PrayerTradition tradition = PrayerTradition.custom,
    PrayerTimeRule start = const PrayerTimeRule.fixed(6 * 60),
    PrayerTimeRule? end = const PrayerTimeRule.fixed(7 * 60),
    required DateTime now,
  }) => Prayer(
    id: '',
    name: name,
    kind: kind,
    tradition: tradition,
    start: start,
    end: end,
    createdAt: now,
    updatedAt: now,
  );

  static const int everyDay = 127;

  final String id;
  final String name;
  final PrayerKind kind;
  final PrayerTradition tradition;
  final PrayerTimeRule start;

  /// Null = no end (a moment, not a window).
  final PrayerTimeRule? end;

  /// Bit 0 = Monday … bit 6 = Sunday.
  final int weekdaysMask;

  /// Optional inclusive date range (date only).
  final DateTime? startDate;
  final DateTime? endDate;

  /// Repeats on the days of a religious calendar instead of by weekday
  /// (Ramadan, an Ekadashi, Lent …); null = by [weekdaysMask].
  final CalendarRule? calendar;
  final PrayerPriority priority;

  /// Reminder this many minutes before the start; null = none.
  final int? remindBefore;

  /// Reminder this many minutes before the end while not marked; null =
  /// off. For a fast: the Iftar reminder (0 = at the end).
  final int? remindBeforeEnd;
  final String sound;
  final int snoozeMinutes;
  final String place;
  final String note;

  /// Daily goal of a counting practice (dhikr); null = no goal.
  final int? targetCount;

  /// The congregation's time (jamaat); null = none set.
  final PrayerJamaat? jamaat;

  /// Reminder this many minutes before [jamaat]; null = off.
  final int? remindBeforeJamaat;
  final bool isPaused;
  final String? colorHex;
  final bool isPinned;
  final bool isFavorite;
  final List<Tag> tags;
  final double sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;

  bool get isNew => id.isEmpty;
  ItemRef get ref => ItemRef(ItemType.prayer, id);
  bool get isActive => archivedAt == null && deletedAt == null;
  bool get isArchived => archivedAt != null && deletedAt == null;
  bool get alarm => priority == PrayerPriority.high;

  /// Uses a sun event at either end (needs the saved location).
  bool get usesSun => start.isAuto || (end?.isAuto ?? false);

  /// The display name ("Untitled prayer" when blank). A practice added from
  /// a tradition is saved under its English name ("Fajr", "Rosary"); it is
  /// shown in the active language, while a name the person typed or changed
  /// is shown as it is.
  String get displayName {
    final n = name.trim();
    if (n.isEmpty) return tr('Untitled prayer');
    if (tradition != PrayerTradition.custom && L10n.has(n)) {
      return L10n.translate(n);
    }
    return n;
  }

  Prayer copyWith({
    String? name,
    PrayerKind? kind,
    PrayerTradition? tradition,
    PrayerTimeRule? start,
    PrayerTimeRule? end,
    bool clearEnd = false,
    int? weekdaysMask,
    DateTime? startDate,
    DateTime? endDate,
    bool clearDates = false,
    CalendarRule? calendar,
    bool clearCalendar = false,
    PrayerPriority? priority,
    int? remindBefore,
    bool clearRemindBefore = false,
    int? remindBeforeEnd,
    bool clearRemindBeforeEnd = false,
    String? sound,
    int? snoozeMinutes,
    String? place,
    String? note,
    int? targetCount,
    bool clearTarget = false,
    PrayerJamaat? jamaat,
    bool clearJamaat = false,
    int? remindBeforeJamaat,
    bool clearRemindBeforeJamaat = false,
    bool? isPaused,
    String? colorHex,
    bool clearColor = false,
    bool? isPinned,
    bool? isFavorite,
    List<Tag>? tags,
    double? sortOrder,
    DateTime? updatedAt,
    DateTime? archivedAt,
    DateTime? deletedAt,
  }) => Prayer(
    id: id,
    name: name ?? this.name,
    kind: kind ?? this.kind,
    tradition: tradition ?? this.tradition,
    start: start ?? this.start,
    end: clearEnd ? null : (end ?? this.end),
    weekdaysMask: weekdaysMask ?? this.weekdaysMask,
    startDate: clearDates ? null : (startDate ?? this.startDate),
    endDate: clearDates ? null : (endDate ?? this.endDate),
    calendar: clearCalendar ? null : (calendar ?? this.calendar),
    priority: priority ?? this.priority,
    remindBefore: clearRemindBefore
        ? null
        : (remindBefore ?? this.remindBefore),
    remindBeforeEnd: clearRemindBeforeEnd
        ? null
        : (remindBeforeEnd ?? this.remindBeforeEnd),
    sound: sound ?? this.sound,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    place: place ?? this.place,
    note: note ?? this.note,
    targetCount: clearTarget ? null : (targetCount ?? this.targetCount),
    jamaat: clearJamaat ? null : (jamaat ?? this.jamaat),
    remindBeforeJamaat: clearRemindBeforeJamaat || clearJamaat
        ? null
        : (remindBeforeJamaat ?? this.remindBeforeJamaat),
    isPaused: isPaused ?? this.isPaused,
    colorHex: clearColor ? null : (colorHex ?? this.colorHex),
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    tags: tags ?? this.tags,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: archivedAt ?? this.archivedAt,
    deletedAt: deletedAt ?? this.deletedAt,
  );

  @override
  bool operator ==(Object other) =>
      other is Prayer &&
      other.id == id &&
      other.name == name &&
      other.kind == kind &&
      other.tradition == tradition &&
      other.start == start &&
      other.end == end &&
      other.weekdaysMask == weekdaysMask &&
      other.startDate == startDate &&
      other.endDate == endDate &&
      other.calendar == calendar &&
      other.priority == priority &&
      other.remindBefore == remindBefore &&
      other.remindBeforeEnd == remindBeforeEnd &&
      other.sound == sound &&
      other.snoozeMinutes == snoozeMinutes &&
      other.place == place &&
      other.note == note &&
      other.targetCount == targetCount &&
      other.jamaat == jamaat &&
      other.remindBeforeJamaat == remindBeforeJamaat &&
      other.isPaused == isPaused &&
      other.colorHex == colorHex &&
      other.isPinned == isPinned &&
      other.isFavorite == isFavorite &&
      listEquals(other.tags, tags) &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.archivedAt == archivedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    name,
    kind,
    tradition,
    start,
    end,
    weekdaysMask,
    startDate,
    endDate,
    calendar,
    priority,
    remindBefore,
    remindBeforeEnd,
    sound,
    snoozeMinutes,
    place,
    note,
    targetCount,
    jamaat,
    remindBeforeJamaat,
    isPaused,
    colorHex,
    isPinned,
    isFavorite,
    Object.hashAll(tags),
    sortOrder,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
  ]);

  @override
  String toString() => 'Prayer($id, $displayName)';
}
