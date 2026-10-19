/// ============================================================
/// SETTINGS STYLE — row tile tints + value labels (screens 30 & 32)
/// ============================================================
///
/// What: the icon-tile colour trio of every Settings row, and formatters
/// that turn stored values into the muted row values ("Saturday",
/// "12-hour", "Grid · Last edited", "30 s").
/// Why: the mockup gives each row its own tile colour; naming them here
/// (built from [AppPalette] / module trios) keeps raw colours out of the
/// widgets and gives one place to retune. Labels are shared by the rows,
/// their option sheets and the tests.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/module_style.dart';

ModuleColors _trio(Color solid, Color soft, Color ink) =>
    ModuleColors(solid: solid, soft: soft, ink: ink);

/// Solid icon-tile fills of the Settings rows (white glyphs).
abstract final class SettingsTints {
  static final sky = TagPalette.travel;
  static final emerald = ModuleStyle.notes.colors;
  static final emeraldDeep = _trio(
    AppPalette.emerald600,
    AppPalette.emerald100,
    AppPalette.emerald800,
  );
  static final violet = TagPalette.design;
  static final violetDeep = _trio(
    AppPalette.violet600,
    AppPalette.violet100,
    AppPalette.violet700,
  );
  static final slate = ActionTints.lock;
  static final slateDeep = _trio(
    AppPalette.slate700,
    AppPalette.slate200,
    AppPalette.slate700,
  );
  static final red = TagPalette.high;
  static final indigo = ModuleStyle.habits.colors;
  static final blue = ModuleStyle.tasks.colors;
  static final blueDeep = _trio(
    AppPalette.blue600,
    AppPalette.blue100,
    AppPalette.blue700,
  );
  static final teal = ActionTints.share;
  static final amber = ModuleStyle.vault.colors;
  static final pink = TagPalette.personal;
  static final orange = ModuleStyle.reminders.colors;
  static final rose = _trio(
    AppPalette.rose500,
    AppPalette.rose100,
    AppPalette.rose700,
  );
}

/// Human labels for stored setting values.
abstract final class SettingsLabels {
  static const languages = {'en': 'English'};

  static String language(String code) => languages[code] ?? code;

  static String startScreen(StartScreen s) => switch (s) {
    StartScreen.home => 'Home',
    StartScreen.library => 'Library',
    StartScreen.insights => 'Insights',
  };

  static const _weekdays = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];

  /// [day] is DateTime.monday (1) … DateTime.sunday (7).
  static String weekday(int day) => _weekdays[(day - 1).clamp(0, 6)];

  static String timeFormat({required bool use24h}) =>
      use24h ? '24-hour' : '12-hour';

  static String theme(ThemeMode m) => switch (m) {
    ThemeMode.system => 'System',
    ThemeMode.light => 'Light',
    ThemeMode.dark => 'Dark',
  };

  static String notesView(NotesView v) => switch (v) {
    NotesView.grid => 'Grid',
    NotesView.list => 'List',
  };

  static String notesSort(NotesSort s) => switch (s) {
    NotesSort.lastEdited => 'Last edited',
    NotesSort.created => 'Created',
    NotesSort.titleAz => 'Title A–Z',
    NotesSort.colour => 'Colour',
    NotesSort.manual => 'Manual',
  };

  static String density(ListDensity d) => switch (d) {
    ListDensity.comfortable => 'Comfortable',
    ListDensity.compact => 'Compact',
  };

  static String performance(PerformanceMode m) => switch (m) {
    PerformanceMode.auto => 'Automatic',
    PerformanceMode.full => 'Full',
    PerformanceMode.reduced => 'Reduced',
  };

  static String performanceHint(PerformanceMode m) => switch (m) {
    PerformanceMode.auto =>
      'Lighter effects on phones that struggle, full on the rest.',
    PerformanceMode.full =>
      'Frosted tab bar, cards that open into their page, shimmering placeholders.',
    PerformanceMode.reduced =>
      'A plain tab bar, pages that slide in and still placeholders — smoother '
          'on older phones.',
  };

  /// "30 s", "1 min", "Never".
  static String clipboard(int seconds) {
    if (seconds <= 0) return 'Never';
    if (seconds < 60) return '$seconds s';
    return '${seconds ~/ 60} min';
  }

  /// "Reset 12:00 AM" / "Reset 00:00" for the habit day roll-over.
  static String clockTime(int minutes, {required bool use24h}) {
    final h = (minutes ~/ 60) % 24;
    final m = (minutes % 60).toString().padLeft(2, '0');
    if (use24h) return '${h.toString().padLeft(2, '0')}:$m';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m ${h < 12 ? 'AM' : 'PM'}';
  }

  static String swipe(SwipeAction a) => switch (a) {
    SwipeAction.none => 'Nothing',
    SwipeAction.archive => 'Archive',
    SwipeAction.delete => 'Delete',
    SwipeAction.complete => 'Complete',
    SwipeAction.pin => 'Pin',
    SwipeAction.favourite => 'Favourite',
    SwipeAction.snooze => 'Snooze',
  };

  /// Where a swipe action applies (the option sheet's subtitles).
  static String swipeHint(SwipeAction a) => switch (a) {
    SwipeAction.none => 'Swiping does nothing',
    SwipeAction.archive => 'Every module · Undo for 5 s',
    SwipeAction.delete => 'Moves to Recently deleted · Undo for 5 s',
    SwipeAction.complete => 'Tasks, reminders & habits · others pin',
    SwipeAction.pin => 'Notes, tasks, reminders & habits',
    SwipeAction.favourite => 'Every module',
    SwipeAction.snooze => 'Reminders · others pin',
  };

  static String homeSection(HomeSection s) => switch (s) {
    HomeSection.focus => "Today's focus",
    HomeSection.week => 'Week strip',
    HomeSection.upNext => 'Up next',
    HomeSection.tasks => "Today's tasks",
    HomeSection.notes => 'Recent notes',
    HomeSection.habits => 'Habit tracker',
  };

  static String homeSectionHint(HomeSection s) => switch (s) {
    HomeSection.focus => 'Progress and daily stats',
    HomeSection.week => 'This week with item dots',
    HomeSection.upNext => 'Your next reminder',
    HomeSection.tasks => 'Up to 5 tasks due today',
    HomeSection.notes => 'Your latest notes',
    HomeSection.habits => "Today's habit rings",
  };

  /// Uppercase sync pill text: "SYNCED 2 MIN AGO", "SYNCED JUST NOW".
  static String syncedAgo(DateTime? at, DateTime now) {
    if (at == null) return 'NOT SYNCED YET';
    final d = now.difference(at);
    if (d.inMinutes < 1) return 'SYNCED JUST NOW';
    if (d.inHours < 1) return 'SYNCED ${d.inMinutes} MIN AGO';
    if (d.inDays < 1) return 'SYNCED ${d.inHours} H AGO';
    if (d.inDays == 1) return 'SYNCED YESTERDAY';
    return 'SYNCED ${d.inDays} DAYS AGO';
  }
}
