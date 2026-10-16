/// ============================================================
/// REMINDER — a time (and later place) based nudge
/// ============================================================
///
/// Plain immutable entity. Timing model:
///   • [triggerAt]  — the *current pending occurrence* (for a repeating
///     reminder: the next one not yet marked done).
///   • [snoozedUntil] — overrides [triggerAt] while set ([effectiveTriggerAt]).
///   • [repeatRule] — RRULE anchored at [triggerAt]. `markDone` advances
///     [triggerAt] to the next occurrence and stores the acknowledged
///     occurrence in [completedAt]; when the series ends the rule is cleared
///     and the reminder becomes a completed one-time reminder.
///   • [completedAt] — one-time: when it was marked done ([isCompleted]);
///     repeating: the last occurrence marked done ([lastDoneAt]).
/// The notification scheduler uses [nextFireAfter]; lists use
/// ReminderOccurrence (see reminder_occurrence.dart).
/// ============================================================
library;

import 'package:collection/collection.dart';
import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/core/utils/recurrence.dart';

/// 0 notification · 1 alarm (full-screen intent / time-sensitive).
enum AlertStyle { notification, alarm }

/// Geofence trigger (v1.1 behind a flag; stored for sync).
@immutable
class ReminderLocation {
  const ReminderLocation({
    required this.lat,
    required this.lng,
    this.radiusMeters = 150,
    this.onEnter = true,
    this.label = '',
  });

  final double lat;
  final double lng;
  final double radiusMeters;

  /// true = when I arrive, false = when I leave.
  final bool onEnter;

  /// "Office", "Home".
  final String label;

  /// "When I leave office" / "When I arrive at Home".
  String get description {
    final place = label.isEmpty ? 'location' : label;
    return onEnter ? 'When I arrive at $place' : 'When I leave $place';
  }

  Map<String, Object?> toJson() => {
    'lat': lat,
    'lng': lng,
    'radius': radiusMeters,
    'onEnter': onEnter,
    'label': label,
  };

  static ReminderLocation? fromJson(Object? json) {
    if (json is! Map) return null;
    final lat = json['lat'];
    final lng = json['lng'];
    if (lat is! num || lng is! num) return null;
    final radius = json['radius'];
    return ReminderLocation(
      lat: lat.toDouble(),
      lng: lng.toDouble(),
      radiusMeters: radius is num ? radius.toDouble() : 150,
      onEnter: json['onEnter'] != false,
      label: json['label'] is String ? json['label'] as String : '',
    );
  }

  @override
  bool operator ==(Object other) =>
      other is ReminderLocation &&
      other.lat == lat &&
      other.lng == lng &&
      other.radiusMeters == radiusMeters &&
      other.onEnter == onEnter &&
      other.label == label;

  @override
  int get hashCode => Object.hash(lat, lng, radiusMeters, onEnter, label);
}

@immutable
class Reminder {
  const Reminder({
    required this.id,
    required this.title,
    this.note = '',
    required this.triggerAt,
    this.repeatRule,
    this.alertStyle = AlertStyle.notification,
    this.sound = 'chime',
    this.snoozeMinutes = 10,
    this.snoozedUntil,
    this.location,
    this.linkedRef,
    this.linkedTitle,
    this.isEnabled = true,
    this.lastFiredAt,
    this.completedAt,
    this.notificationId = 0,
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

  /// An unsaved reminder for the editor (empty id).
  factory Reminder.draft({
    required DateTime triggerAt,
    String title = '',
    String? repeatRule,
    ItemRef? linkedRef,
  }) => Reminder(
    id: '',
    title: title,
    triggerAt: triggerAt,
    repeatRule: repeatRule,
    linkedRef: linkedRef,
    createdAt: triggerAt,
    updatedAt: triggerAt,
  );

  final String id;
  final String title;
  final String note;
  final DateTime triggerAt;

  /// RFC 5545 RRULE (`FREQ=DAILY`); null = once.
  final String? repeatRule;
  final AlertStyle alertStyle;
  final String sound;

  /// Default snooze length for this reminder.
  final int snoozeMinutes;
  final DateTime? snoozedUntil;
  final ReminderLocation? location;

  /// The task / note / habit this reminder belongs to.
  final ItemRef? linkedRef;

  /// Title of [linkedRef] ("Linked task · Design Home v2").
  final String? linkedTitle;
  final bool isEnabled;
  final DateTime? lastFiredAt;
  final DateTime? completedAt;

  /// Stable positive 31-bit id for flutter_local_notifications (assigned
  /// on create; 0 for an unsaved draft).
  final int notificationId;
  final String? colorHex;
  final bool isPinned;
  final bool isFavorite;
  final List<Tag> tags;
  final double sortOrder;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? archivedAt;
  final DateTime? deletedAt;

  ItemRef get ref => ItemRef(ItemType.reminder, id);
  bool get isNew => id.isEmpty;
  bool get isRecurring => recurrence != null;
  bool get isArchived => archivedAt != null;
  bool get isDeleted => deletedAt != null;
  bool get isActive => archivedAt == null && deletedAt == null;
  bool get hasLocation => location != null;

  /// Parsed [repeatRule] (null when once or unparsable).
  RecurrenceRule? get recurrence => RecurrenceRule.tryParse(repeatRule);

  /// One-time reminder marked done. (Repeating reminders never complete;
  /// they advance — see [lastDoneAt].)
  bool get isCompleted => completedAt != null && !isRecurring;

  /// Last occurrence marked done of a repeating reminder.
  DateTime? get lastDoneAt => isRecurring ? completedAt : null;

  /// When the pending occurrence fires: [snoozedUntil] if set, else
  /// [triggerAt].
  DateTime get effectiveTriggerAt => snoozedUntil ?? triggerAt;

  bool isSnoozed(DateTime now) =>
      snoozedUntil != null && snoozedUntil!.isAfter(now);

  /// A one-time reminder whose time passed without being done (enabled
  /// only). Repeating reminders are never "missed" — they roll on.
  bool isMissed(DateTime now) =>
      isEnabled &&
      !isCompleted &&
      !isRecurring &&
      effectiveTriggerAt.isBefore(now);

  /// Next instant this reminder should fire strictly after [now], or null
  /// (disabled, done, or a one-time reminder in the past).
  DateTime? nextFireAfter(DateTime now) {
    if (!isEnabled || isCompleted) return null;
    final snooze = snoozedUntil;
    if (snooze != null && snooze.isAfter(now)) return snooze;
    if (triggerAt.isAfter(now)) return triggerAt;
    final rule = recurrence;
    return rule?.nextAfter(triggerAt, now);
  }

  /// "Weekly · Tue", "Daily", "Once".
  String get repeatLabel => Recurrence.label(repeatRule, start: triggerAt);

  Reminder copyWith({
    String? id,
    String? title,
    String? note,
    DateTime? triggerAt,
    String? repeatRule,
    bool clearRepeatRule = false,
    AlertStyle? alertStyle,
    String? sound,
    int? snoozeMinutes,
    DateTime? snoozedUntil,
    bool clearSnoozedUntil = false,
    ReminderLocation? location,
    bool clearLocation = false,
    ItemRef? linkedRef,
    String? linkedTitle,
    bool clearLink = false,
    bool? isEnabled,
    DateTime? lastFiredAt,
    DateTime? completedAt,
    bool clearCompletedAt = false,
    int? notificationId,
    String? colorHex,
    bool clearColor = false,
    bool? isPinned,
    bool? isFavorite,
    List<Tag>? tags,
    double? sortOrder,
    DateTime? createdAt,
    DateTime? updatedAt,
    DateTime? archivedAt,
    bool clearArchivedAt = false,
    DateTime? deletedAt,
    bool clearDeletedAt = false,
  }) => Reminder(
    id: id ?? this.id,
    title: title ?? this.title,
    note: note ?? this.note,
    triggerAt: triggerAt ?? this.triggerAt,
    repeatRule: clearRepeatRule ? null : (repeatRule ?? this.repeatRule),
    alertStyle: alertStyle ?? this.alertStyle,
    sound: sound ?? this.sound,
    snoozeMinutes: snoozeMinutes ?? this.snoozeMinutes,
    snoozedUntil: clearSnoozedUntil
        ? null
        : (snoozedUntil ?? this.snoozedUntil),
    location: clearLocation ? null : (location ?? this.location),
    linkedRef: clearLink ? null : (linkedRef ?? this.linkedRef),
    linkedTitle: clearLink ? null : (linkedTitle ?? this.linkedTitle),
    isEnabled: isEnabled ?? this.isEnabled,
    lastFiredAt: lastFiredAt ?? this.lastFiredAt,
    completedAt: clearCompletedAt ? null : (completedAt ?? this.completedAt),
    notificationId: notificationId ?? this.notificationId,
    colorHex: clearColor ? null : (colorHex ?? this.colorHex),
    isPinned: isPinned ?? this.isPinned,
    isFavorite: isFavorite ?? this.isFavorite,
    tags: tags ?? this.tags,
    sortOrder: sortOrder ?? this.sortOrder,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    archivedAt: clearArchivedAt ? null : (archivedAt ?? this.archivedAt),
    deletedAt: clearDeletedAt ? null : (deletedAt ?? this.deletedAt),
  );

  static const _tagsEq = ListEquality<Tag>();

  @override
  bool operator ==(Object other) =>
      other is Reminder &&
      other.id == id &&
      other.title == title &&
      other.note == note &&
      other.triggerAt == triggerAt &&
      other.repeatRule == repeatRule &&
      other.alertStyle == alertStyle &&
      other.sound == sound &&
      other.snoozeMinutes == snoozeMinutes &&
      other.snoozedUntil == snoozedUntil &&
      other.location == location &&
      other.linkedRef == linkedRef &&
      other.linkedTitle == linkedTitle &&
      other.isEnabled == isEnabled &&
      other.lastFiredAt == lastFiredAt &&
      other.completedAt == completedAt &&
      other.notificationId == notificationId &&
      other.colorHex == colorHex &&
      other.isPinned == isPinned &&
      other.isFavorite == isFavorite &&
      _tagsEq.equals(other.tags, tags) &&
      other.sortOrder == sortOrder &&
      other.createdAt == createdAt &&
      other.updatedAt == updatedAt &&
      other.archivedAt == archivedAt &&
      other.deletedAt == deletedAt;

  @override
  int get hashCode => Object.hashAll([
    id,
    title,
    note,
    triggerAt,
    repeatRule,
    alertStyle,
    sound,
    snoozeMinutes,
    snoozedUntil,
    location,
    linkedRef,
    linkedTitle,
    isEnabled,
    lastFiredAt,
    completedAt,
    notificationId,
    colorHex,
    isPinned,
    isFavorite,
    _tagsEq.hash(tags),
    sortOrder,
    createdAt,
    updatedAt,
    archivedAt,
    deletedAt,
  ]);

  @override
  String toString() =>
      'Reminder($id, $title, $triggerAt, ${repeatRule ?? 'once'})';
}
