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
import 'package:focusflow/core/l10n/app_language.dart';
import 'package:focusflow/core/l10n/tr.dart';
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
  /// The language's own name ("Deutsch"), as the picker shows it.
  static String language(String code) => AppLanguage.fromCode(code).nativeName;

  static String startScreen(StartScreen s) => switch (s) {
    StartScreen.home => tr('Home'),
    StartScreen.library => tr('Library'),
    StartScreen.insights => tr('Insights'),
  };

  /// [day] is DateTime.monday (1) … DateTime.sunday (7).
  static String weekday(int day) => switch ((day - 1).clamp(0, 6)) {
    0 => tr('Monday'),
    1 => tr('Tuesday'),
    2 => tr('Wednesday'),
    3 => tr('Thursday'),
    4 => tr('Friday'),
    5 => tr('Saturday'),
    _ => tr('Sunday'),
  };

  static String timeFormat({required bool use24h}) =>
      use24h ? tr('24-hour') : tr('12-hour');

  static String theme(ThemeMode m) => switch (m) {
    ThemeMode.system => tr('System'),
    ThemeMode.light => tr('Light'),
    ThemeMode.dark => tr('Dark'),
  };

  static String notesView(NotesView v) => switch (v) {
    NotesView.grid => tr('Grid'),
    NotesView.list => tr('List'),
  };

  static String notesSort(NotesSort s) => switch (s) {
    NotesSort.lastEdited => tr('Last edited'),
    NotesSort.created => tr('Created'),
    NotesSort.titleAz => tr('Title A–Z'),
    NotesSort.colour => tr('Colour'),
    NotesSort.manual => tr('Manual'),
  };

  static String density(ListDensity d) => switch (d) {
    ListDensity.comfortable => tr('Comfortable'),
    ListDensity.compact => tr('Compact'),
  };

  static String performance(PerformanceMode m) => switch (m) {
    PerformanceMode.auto => tr('Automatic'),
    PerformanceMode.full => tr('Full'),
    PerformanceMode.reduced => tr('Reduced'),
  };

  static String performanceHint(PerformanceMode m) => switch (m) {
    PerformanceMode.auto => tr(
      'Lighter effects on phones that struggle, full on the rest.',
    ),
    PerformanceMode.full => tr(
      'Frosted tab bar, cards that open into their page, shimmering placeholders.',
    ),
    PerformanceMode.reduced => tr(
      'A plain tab bar, pages that slide in and still placeholders — smoother on older phones.',
    ),
  };

  /// "30 s", "1 min", "Never".
  static String clipboard(int seconds) {
    if (seconds <= 0) return tr('Never');
    if (seconds < 60) return tr('{seconds} s', {'seconds': seconds});
    return tr('{minutes} min', {'minutes': seconds ~/ 60});
  }

  /// "Reset 12:00 AM" / "Reset 00:00" for the habit day roll-over.
  static String clockTime(int minutes, {required bool use24h}) {
    final h = (minutes ~/ 60) % 24;
    final m = (minutes % 60).toString().padLeft(2, '0');
    if (use24h) return '${h.toString().padLeft(2, '0')}:$m';
    final h12 = h % 12 == 0 ? 12 : h % 12;
    return '$h12:$m ${h < 12 ? tr('AM') : tr('PM')}';
  }

  static String swipe(SwipeAction a) => switch (a) {
    SwipeAction.none => tr('Nothing'),
    SwipeAction.archive => tr('Archive'),
    SwipeAction.delete => tr('Delete'),
    SwipeAction.complete => tr('Complete'),
    SwipeAction.pin => tr('Pin'),
    SwipeAction.favourite => tr('Favourite'),
    SwipeAction.snooze => tr('Snooze'),
  };

  /// Where a swipe action applies (the option sheet's subtitles).
  static String swipeHint(SwipeAction a) => switch (a) {
    SwipeAction.none => tr('Swiping does nothing'),
    SwipeAction.archive => tr('Every module · Undo for 5 s'),
    SwipeAction.delete => tr('Moves to Recently deleted · Undo for 5 s'),
    SwipeAction.complete => tr('Tasks, reminders & habits · others pin'),
    SwipeAction.pin => tr('Notes, tasks, reminders & habits'),
    SwipeAction.favourite => tr('Every module'),
    SwipeAction.snooze => tr('Reminders · others pin'),
  };

  static String homeSection(HomeSection s) => switch (s) {
    HomeSection.focus => tr("Today's focus"),
    HomeSection.week => tr('Week strip'),
    HomeSection.upNext => tr('Up next'),
    HomeSection.tasks => tr("Today's tasks"),
    HomeSection.notes => tr('Recent notes'),
    HomeSection.habits => tr('Habit tracker'),
  };

  static String homeSectionHint(HomeSection s) => switch (s) {
    HomeSection.focus => tr('Progress and daily stats'),
    HomeSection.week => tr('This week with item dots'),
    HomeSection.upNext => tr('Your next reminder'),
    HomeSection.tasks => tr('Up to 5 tasks due today'),
    HomeSection.notes => tr('Your latest notes'),
    HomeSection.habits => tr("Today's habit rings"),
  };

  /// Sync pill text, sentence case: "Synced 2 min ago", "Synced just now".
  static String syncedAgo(DateTime? at, DateTime now) {
    if (at == null) return tr('Not synced yet');
    final d = now.difference(at);
    if (d.inMinutes < 1) return tr('Synced just now');
    if (d.inHours < 1) {
      return tr('Synced {minutes} min ago', {'minutes': d.inMinutes});
    }
    if (d.inDays < 1) return tr('Synced {hours} h ago', {'hours': d.inHours});
    if (d.inDays == 1) return tr('Synced yesterday');
    return tr('Synced {days} days ago', {'days': d.inDays});
  }
}
