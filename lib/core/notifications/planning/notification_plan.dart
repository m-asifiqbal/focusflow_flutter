/// ============================================================
/// NOTIFICATION PLAN — what the planner produces, what the OS receives
/// ============================================================
///
/// * [NotificationCategory] — why a notification exists (reminder, alarm,
///   task, habit check-in, streak at risk, digest, security, sync). Each
///   maps to one Android channel ([NotificationChannelId]) and one settings
///   switch (screen 31).
/// * [NotificationButton] — action buttons on the OS notification.
/// * [NotificationPayload] — the compact JSON string carried by the OS
///   notification and handed back on tap / action (no secrets, no note
///   text — only keys and ids).
/// * [PlannedNotification] — one scheduled notification with its stable
///   id + key, fire time, content and the inbox entry it becomes once
///   delivered.
/// ============================================================
library;

import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/features/notifications_center/domain/entities/inbox_entry.dart';

/// Android notification channels (created at start-up).
///
/// A channel's importance and sound are fixed once the OS has created it —
/// later code changes never reach devices that already have it. So ids are
/// *versioned* (`_v2`): changing a channel's sound / importance means a new
/// id, and the old ids ([legacyIds]) are deleted once every pending
/// notification has been re-scheduled onto the new ones.
///
/// Reminder tones ([tone] = a `Reminder.sound` key shipped as
/// `res/raw/<tone>.wav`, see tool/sounds/) get one channel each, shared by
/// plain and task reminders; any other sound key uses the system default
/// sound of [reminders] / [tasks].
enum NotificationChannelId {
  reminders(
    'reminders_v2',
    'Reminders',
    'Your reminders at the time you set (system sound)',
  ),
  chime(
    'reminders_chime_v2',
    'Reminders · Chime',
    'Reminders that use the Chime sound',
    tone: 'chime',
  ),
  bell(
    'reminders_bell_v2',
    'Reminders · Bell',
    'Reminders that use the Bell sound',
    tone: 'bell',
  ),
  gentle(
    'reminders_gentle_v2',
    'Reminders · Gentle',
    'Reminders that use the Gentle sound',
    tone: 'gentle',
  ),
  pulse(
    'reminders_pulse_v2',
    'Reminders · Pulse',
    'Reminders that use the Pulse sound',
    tone: 'pulse',
  ),
  alarms('alarms_v2', 'Alarms', 'Alarm-style reminders shown full screen'),
  tasks('tasks_v2', 'Tasks', 'Task due and overdue alerts'),
  habits('habits_v2', 'Habits', "Habit check-ins and streaks at risk"),

  /// Reminders whose sound is "Silent" (Android channel sounds are fixed,
  /// so silence needs a channel of its own).
  silentReminders(
    'reminders_silent_v2',
    'Silent reminders',
    'Reminders set to Silent: shown without a sound',
    playSound: false,
  ),
  digests(
    'digests_v2',
    'Daily digest',
    'Morning briefing, evening review and '
        'weekly report',
  ),
  system(
    'system_v2',
    'Security & sync',
    'Vault security alerts and backup / '
        'sync status',
  );

  const NotificationChannelId(
    this.id,
    this.label,
    this.description, {
    this.tone,
    this.playSound = true,
  });

  final String id;
  final String label;
  final String description;

  /// Bundled sound (`res/raw/<tone>`, iOS `Library/Sounds/<tone>.wav`);
  /// null = the system default sound.
  final String? tone;
  final bool playSound;

  /// Channel ids of earlier versions (deleted by the gateway).
  static const List<String> legacyIds = [
    'reminders',
    'alarms',
    'tasks',
    'habits',
    'reminders_silent',
    'digests',
    'system',
  ];

  /// Sound keys that ship as a file (the tone channels above).
  static Set<String> get tones => {
    for (final c in values)
      if (c.tone != null) c.tone!,
  };

  /// The channel [n] is posted on: silent → [silentReminders], alarm →
  /// [alarms], a reminder / task notification with a bundled tone → that
  /// tone's channel, anything else → its category's channel.
  static NotificationChannelId forNotification(PlannedNotification n) {
    if (n.isSilent) return silentReminders;
    final category = n.category;
    if (category == NotificationCategory.alarm) return alarms;
    if (category == NotificationCategory.reminder ||
        category == NotificationCategory.task) {
      for (final c in values) {
        if (c.tone != null && c.tone == n.sound) return c;
      }
    }
    return category.channel;
  }
}

enum NotificationCategory {
  reminder(NotificationChannelId.reminders, InboxKind.reminder),
  alarm(NotificationChannelId.alarms, InboxKind.reminder),
  task(NotificationChannelId.tasks, InboxKind.task),
  habit(NotificationChannelId.habits, InboxKind.habit),
  streak(NotificationChannelId.habits, InboxKind.habit),
  digest(NotificationChannelId.digests, InboxKind.system),
  security(NotificationChannelId.system, InboxKind.security),
  sync(NotificationChannelId.system, InboxKind.sync);

  const NotificationCategory(this.channel, this.inboxKind);

  final NotificationChannelId channel;
  final InboxKind inboxKind;

  /// Alarm-style reminders ignore quiet hours (screen 31).
  bool get bypassesQuietHours => this == alarm;

  /// Ordering when several notifications share a minute and the rolling
  /// window must drop some (lower = more important).
  int get priority => index;

  static NotificationCategory? fromName(String? name) {
    for (final c in values) {
      if (c.name == name) return c;
    }
    return null;
  }
}

/// An action button on the OS notification.
enum NotificationButton {
  /// Mark the reminder (or its task) done.
  done('done'),

  /// Snooze the reminder by its snooze length.
  snooze('snooze'),

  /// Log one check-in for a habit.
  checkIn('checkin'),

  /// Open the item (brings the app to the foreground, like a body tap).
  open('open');

  const NotificationButton(this.id);

  /// Action id sent back by the OS.
  final String id;

  /// Whether tapping it must bring the app to the foreground. Every other
  /// button runs in the background isolate (the app is told to refresh).
  bool get showsUserInterface => this == open;

  static NotificationButton? fromId(String? id) {
    for (final b in values) {
      if (b.id == id) return b;
    }
    return null;
  }
}

/// The data a notification carries back to the app (tap / action).
@immutable
class NotificationPayload {
  const NotificationPayload({
    required this.key,
    required this.category,
    this.target,
    this.open,
    this.route,
    this.snoozeMinutes,
    this.day,
  });

  /// Stable plan key (`rem:<id>:<epoch>`, `hab:<id>:<day>:<minute>` …).
  final String key;
  final NotificationCategory category;

  /// The item an action applies to (reminder, habit).
  final ItemRef? target;

  /// The item a tap opens (a task-linked reminder opens the task).
  final ItemRef? open;

  /// Route a tap opens when there is no item (digests, overdue summary).
  final String? route;

  /// Snooze length for [NotificationButton.snooze].
  final int? snoozeMinutes;

  /// Habit day for [NotificationButton.checkIn] (`yyyy-MM-dd`).
  final String? day;

  String encode() => jsonEncode({
    'k': key,
    'c': category.name,
    if (target != null) 't': '${target!.type.key}/${target!.id}',
    if (open != null) 'o': '${open!.type.key}/${open!.id}',
    if (route != null) 'r': route,
    if (snoozeMinutes != null) 's': snoozeMinutes,
    if (day != null) 'd': day,
  });

  static NotificationPayload? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map) return null;
      final category = NotificationCategory.fromName(j['c'] as String?);
      final key = j['k'];
      if (category == null || key is! String) return null;
      return NotificationPayload(
        key: key,
        category: category,
        target: _ref(j['t']),
        open: _ref(j['o']),
        route: j['r'] is String ? j['r'] as String : null,
        snoozeMinutes: j['s'] is num ? (j['s'] as num).toInt() : null,
        day: j['d'] is String ? j['d'] as String : null,
      );
    } on FormatException {
      return null;
    }
  }

  static ItemRef? _ref(Object? v) {
    if (v is! String) return null;
    final i = v.indexOf('/');
    if (i <= 0) return null;
    final type = ItemType.fromKey(v.substring(0, i));
    return type == null ? null : ItemRef(type, v.substring(i + 1));
  }

  @override
  bool operator ==(Object other) =>
      other is NotificationPayload && other.encode() == encode();

  @override
  int get hashCode => encode().hashCode;
}

@immutable
class PlannedNotification {
  const PlannedNotification({
    required this.id,
    required this.key,
    required this.fireAt,
    required this.category,
    required this.title,
    this.body = '',
    required this.payload,
    this.buttons = const [],
    this.inboxActions = const [],
    this.inboxRef,
    this.badge,
    this.reminderId,
    this.sound,
  });

  /// The reminder's sound name (`Reminder.sound`: chime, bell, gentle,
  /// pulse — bundled tones — or silent; anything else / null = the system
  /// default sound).
  static const String silentSound = 'silent';

  /// Stable positive 31-bit OS id (reminders: `Reminder.notificationId`).
  final int id;

  /// Stable identity across re-plans (see [NotificationPayload.key]).
  final String key;

  /// When the OS shows it (quiet hours already applied).
  final DateTime fireAt;
  final NotificationCategory category;
  final String title;
  final String body;
  final NotificationPayload payload;
  final List<NotificationButton> buttons;

  /// Inline actions of the inbox entry it becomes ([InboxActions] keys).
  final List<String> inboxActions;

  /// Item the inbox entry points to.
  final ItemRef? inboxRef;

  /// App icon badge at delivery (null = leave unchanged).
  final int? badge;

  /// Reminder to stamp `lastFiredAt` on once delivered.
  final String? reminderId;

  /// Sound name (see [silentSound]); null = default.
  final String? sound;

  /// Shown without any sound (silent channel / no iOS sound).
  bool get isSilent => sound == silentSound;

  /// The bundled tone to play ([NotificationChannelId.tones]); null = the
  /// system default sound (or none when [isSilent]).
  String? get tone =>
      sound != null && NotificationChannelId.tones.contains(sound)
      ? sound
      : null;

  InboxKind get inboxKind => category.inboxKind;

  /// Changes whenever the OS copy must be replaced (time, text, actions,
  /// badge). A hash, so the persisted ledger never holds item text.
  String get fingerprint {
    final s = [
      id,
      fireAt.millisecondsSinceEpoch,
      category.name,
      title,
      body,
      payload.encode(),
      buttons.map((b) => b.id).join(','),
      badge ?? -1,
      sound ?? '',
      // The channel is part of the OS copy (channels are versioned).
      NotificationChannelId.forNotification(this).id,
    ].join('\u0001');
    return fnv1a32(s).toRadixString(16);
  }

  PlannedNotification copyWith({int? id, DateTime? fireAt, int? badge}) =>
      PlannedNotification(
        id: id ?? this.id,
        key: key,
        fireAt: fireAt ?? this.fireAt,
        category: category,
        title: title,
        body: body,
        payload: payload,
        buttons: buttons,
        inboxActions: inboxActions,
        inboxRef: inboxRef,
        badge: badge ?? this.badge,
        reminderId: reminderId,
        sound: sound,
      );

  @override
  String toString() => 'Planned($key @ $fireAt #$id)';
}

/// 32-bit FNV-1a of [s] (same family as reminders' notification ids).
int fnv1a32(String s) {
  var hash = 0x811c9dc5;
  for (final unit in s.codeUnits) {
    hash ^= unit;
    hash = (hash * 0x01000193) & 0xFFFFFFFF;
  }
  return hash;
}

/// Id of the silent iOS badge request (LocalNotificationsGateway); never
/// used for a planned notification (also skipped by RemindersDao).
const int reservedNotificationId = 0x7FFFFFF0;

/// A stable positive 31-bit notification id derived from a plan [key]
/// (never 0 nor [reservedNotificationId]).
int notificationIdForKey(String key) {
  final id = fnv1a32(key) & 0x7FFFFFFF;
  if (id == 0) return 1;
  return id == reservedNotificationId ? id + 1 : id;
}
