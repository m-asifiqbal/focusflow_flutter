/// ============================================================
/// NOTIFICATION SETTINGS STYLE — tile tints + value labels (screen 31)
/// ============================================================
///
/// What: the icon-tile colour trios of every row on Settings ›
/// Notifications & Reminders, and the formatters that turn stored setting
/// values into the muted row values ("8:00 AM", "Sun", "Title only").
/// Why: the mockup gives each row its own tile colour; keeping them as
/// named [ModuleColors] built from [AppPalette] tokens (or the module
/// trios) means no raw colours in the widgets, and one place to retune.
/// ============================================================
library;

import 'package:flutter/foundation.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_alert_options.dart';

/// Icon-tile tints of the rows (solid tile, white glyph).
abstract final class NotificationTints {
  /// Text / glyphs on the primary gradient of the permission card: white in
  /// both modes because the gradient never changes (FFColors.onPrimary is
  /// dark in dark mode, made for the lighter dark-mode primary).
  static const onGradient = AppPalette.white;

  /// Morning briefing — amber sun.
  static const morning = ModuleColors(
    solid: AppPalette.amber500,
    soft: AppPalette.amber100,
    ink: AppPalette.amber700,
  );

  /// Evening review / quiet hours — indigo moon.
  static const night = ModuleColors(
    solid: AppPalette.indigo500,
    soft: AppPalette.indigo100,
    ink: AppPalette.indigo700,
  );

  /// Weekly report / backup & sync — sky.
  static const sky = TagPalette.travel;

  /// Streak at risk — red flame.
  static const streak = ModuleColors(
    solid: AppPalette.red500,
    soft: AppPalette.red100,
    ink: AppPalette.red700,
  );

  /// Vault security alerts — deep emerald shield.
  static const security = ModuleColors(
    solid: AppPalette.emerald600,
    soft: AppPalette.emerald100,
    ink: AppPalette.emerald800,
  );

  /// Default snooze — slate.
  static const snooze = ActionTints.lock;

  /// Show on lock screen — teal.
  static const lockScreen = ActionTints.share;

  /// Repeat until done — amber.
  static const repeat = NotificationTints.morning;

  /// App icon badge — pink.
  static const badge = TagPalette.personal;

  /// Module rows reuse the module trios.
  static ModuleColors get reminders => ModuleStyle.reminders.colors;
  static ModuleColors get tasks => ModuleStyle.tasks.colors;
  static ModuleColors get habits => ModuleStyle.habits.colors;
}

/// Display strings for the stored notification settings.
abstract final class NotificationLabels {
  /// "8:00 AM" / "08:00" for minutes after midnight.
  static String time(int minutes, {required bool use24h}) {
    final t = DateTime(2000, 1, 1, minutes ~/ 60, minutes % 60);
    return DateFormats.of(use24h ? 'HH:mm' : 'h:mm a').format(t);
  }

  /// "Sun" for [DateTime.sunday] (1 = Monday … 7 = Sunday).
  static String weekdayShort(int weekday) => DateFormats.of(
    'EEE',
  ).format(DateTime(2024, 1, weekday)); // 2024-01-01 = Mon

  /// "Sunday".
  static String weekdayLong(int weekday) =>
      DateFormats.of('EEEE').format(DateTime(2024, 1, weekday));

  /// The seven weekdays starting at [weekStartsOn].
  static List<int> orderedWeekdays(int weekStartsOn) => [
    for (var i = 0; i < 7; i++) (weekStartsOn - 1 + i) % 7 + 1,
  ];

  /// "Off", "Every 10 min", "Every 2 hours".
  static String repeat(int minutes) => minutes <= 0
      ? 'Never'
      : 'Every ${ReminderAlertOptions.snoozeLabel(minutes)}';

  /// "3 times".
  static String repeatCount(int n) => n == 1 ? 'Once' : '$n times';

  static String lockScreen(LockScreenVisibility v) => switch (v) {
    LockScreenVisibility.full => 'Full content',
    LockScreenVisibility.titleOnly => 'Title only',
    LockScreenVisibility.hidden => 'Hidden',
  };

  /// What each mode really does (LocalNotificationsGateway): Android has
  /// no "title only" lock-screen copy, so it hides the whole content while
  /// locked; iOS keeps the title when it hides previews; Hidden replaces
  /// the text with a generic "Reminder" everywhere.
  static String lockScreenHint(
    LockScreenVisibility v, {
    TargetPlatform? platform,
  }) {
    final android =
        (platform ?? defaultTargetPlatform) == TargetPlatform.android;
    return switch (v) {
      LockScreenVisibility.full => 'Title and details are visible',
      LockScreenVisibility.titleOnly =>
        android
            ? 'Contents stay hidden until unlocked'
            : 'Details stay hidden until unlocked',
      LockScreenVisibility.hidden =>
        android
            ? 'Nothing shows while locked; alerts just say "Reminder"'
            : 'Alerts just say "Reminder" — details stay in the app',
    };
  }

  static String badge(BadgeMode m) => switch (m) {
    BadgeMode.overdue => 'Overdue count',
    BadgeMode.today => 'Due today',
    BadgeMode.none => 'Off',
  };

  static String badgeHint(BadgeMode m) => switch (m) {
    BadgeMode.overdue => 'Open tasks that are past due',
    BadgeMode.today => 'Overdue plus open tasks due today',
    BadgeMode.none => 'No number on the app icon',
  };
}
