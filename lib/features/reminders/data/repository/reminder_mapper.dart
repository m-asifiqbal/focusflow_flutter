/// ============================================================
/// REMINDER MAPPER — reminders rows ⇄ Reminder entities
/// ============================================================
library;

import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:focusflow/core/database/app_database.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/items/tag.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';

abstract final class ReminderMapper {
  static Reminder fromRow(
    ReminderRow r, {
    String? linkedTitle,
    List<Tag> tags = const [],
  }) {
    final linkType = ItemType.fromKey(r.linkedItemType);
    ReminderLocation? location;
    final json = r.locationJson;
    if (json != null && json.isNotEmpty) {
      try {
        location = ReminderLocation.fromJson(jsonDecode(json));
      } on FormatException {
        location = null;
      }
    }
    return Reminder(
      id: r.id,
      title: r.title,
      note: r.note,
      triggerAt: r.triggerAt,
      repeatRule: (r.repeatRule?.isEmpty ?? true) ? null : r.repeatRule,
      alertStyle: r.alertStyle == 1
          ? AlertStyle.alarm
          : AlertStyle.notification,
      sound: r.sound,
      snoozeMinutes: r.snoozeMinutes,
      snoozedUntil: r.snoozedUntil,
      location: location,
      linkedRef: linkType == null || r.linkedItemId == null
          ? null
          : ItemRef(linkType, r.linkedItemId!),
      linkedTitle: linkedTitle,
      isEnabled: r.isEnabled,
      lastFiredAt: r.lastFiredAt,
      completedAt: r.completedAt,
      notificationId: r.notificationId,
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

  /// Editable columns of [r] (not id / created / sync / lifecycle /
  /// notificationId / sortOrder).
  static RemindersCompanion contentCompanion(Reminder r) => RemindersCompanion(
    title: Value(r.title.trim()),
    note: Value(r.note),
    triggerAt: Value(r.triggerAt),
    repeatRule: Value(r.repeatRule),
    alertStyle: Value(r.alertStyle.index),
    sound: Value(r.sound),
    snoozeMinutes: Value(r.snoozeMinutes),
    snoozedUntil: Value(r.snoozedUntil),
    locationJson: Value(
      r.location == null ? null : jsonEncode(r.location!.toJson()),
    ),
    linkedItemId: Value(r.linkedRef?.id),
    linkedItemType: Value(r.linkedRef?.type.key),
    isEnabled: Value(r.isEnabled),
    lastFiredAt: Value(r.lastFiredAt),
    completedAt: Value(r.completedAt),
    colorHex: Value(r.colorHex),
    isPinned: Value(r.isPinned),
    isFavorite: Value(r.isFavorite),
  );
}
