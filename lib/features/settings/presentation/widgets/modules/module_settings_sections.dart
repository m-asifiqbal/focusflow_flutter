/// ============================================================
/// MODULE SETTINGS SECTIONS — the defaults of each module
/// ============================================================
///
/// What: one grouped section per module for Settings › Modules ›
///   Notes     — default view, sort, colour of new notes
///   Tasks     — smart lists, show completed, default list
///   Reminders — default snooze, reminder sound
///   Habits    — day resets at, week starts on
/// Why: the values feed the module screens / editors through
/// [settingsProvider]; every choice is written by [SettingsEditor] and
/// applies at once.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/settings/app_settings.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/library/presentation/providers/library_providers.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_alert_options.dart';
import 'package:focusflow/features/settings/domain/entities/settings_entry.dart';
import 'package:focusflow/features/settings/presentation/notifiers/settings_editor.dart';
import 'package:focusflow/features/settings/presentation/settings_style.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_root_actions.dart';
import 'package:focusflow/features/settings/presentation/widgets/root/settings_sections.dart';
import 'package:focusflow/features/settings/presentation/widgets/settings_option_sheet.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// Labels of [NoteColors.hexes], same order.
const noteColorNames = ['White', 'Mint', 'Amber', 'Blue', 'Pink', 'Violet'];

/// "White" for null / unknown, else the palette name.
String noteColorLabel(String? hex) {
  final i = NoteColors.hexes.indexOf((hex ?? 'FFFFFF').toUpperCase());
  return i < 0 ? 'White' : noteColorNames[i];
}

/// Snooze lengths offered (minutes).
const snoozeChoices = [5, 10, 15, 30, 60];

/// "Day resets at" choices (minutes after midnight).
const habitResetChoices = [0, 60, 120, 180, 240, 300];

Widget _tile(IconData icon, ModuleColors c) => settingsTile(icon, c);

class NotesDefaultsSection extends ConsumerWidget {
  const NotesDefaultsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final editor = ref.read(settingsEditorProvider);
    return FFGroupedList(
      label: 'Notes',
      footer: 'The view and sort can also be changed from the Notes list.',
      children: [
        FFListRow(
          leading: _tile(
            FontAwesomeIcons.tableCellsLarge,
            SettingsTints.emerald,
          ),
          title: 'Default view',
          value: SettingsLabels.notesView(s.notesView),
          onTap: () async {
            final v = await pickSetting<NotesView>(
              context,
              title: 'Default view',
              selected: s.notesView,
              options: [
                for (final n in NotesView.values)
                  option(n, SettingsLabels.notesView(n)),
              ],
            );
            if (v != null) await editor.setNotesView(v);
          },
        ),
        FFListRow(
          leading: _tile(
            FontAwesomeIcons.arrowDownWideShort,
            SettingsTints.blue,
          ),
          title: 'Sort by',
          value: SettingsLabels.notesSort(s.notesSort),
          onTap: () async {
            final v = await pickSetting<NotesSort>(
              context,
              title: 'Sort notes by',
              selected: s.notesSort,
              options: [
                for (final n in NotesSort.values)
                  option(n, SettingsLabels.notesSort(n)),
              ],
            );
            if (v != null) await editor.setNotesSort(v);
          },
        ),
        FFListRow(
          leading: _tile(FontAwesomeIcons.palette, SettingsTints.pink),
          title: 'Colour of new notes',
          value: noteColorLabel(s.notesDefaultColor),
          onTap: () async {
            final v = await pickSetting<String>(
              context,
              title: 'Colour of new notes',
              selected: (s.notesDefaultColor ?? 'FFFFFF').toUpperCase(),
              options: [
                for (var i = 0; i < NoteColors.hexes.length; i++)
                  option(NoteColors.hexes[i], noteColorNames[i]),
              ],
            );
            if (v != null) {
              await editor.setNotesDefaultColor(v == 'FFFFFF' ? null : v);
            }
          },
        ),
      ],
    );
  }
}

class TasksDefaultsSection extends ConsumerWidget {
  const TasksDefaultsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final editor = ref.read(settingsEditorProvider);
    final lists = ref.watch(libraryFoldersProvider(ItemType.task)).valueOrNull;
    final current = lists
        ?.where((f) => f.id == s.tasksDefaultListId)
        .firstOrNull;
    return FFGroupedList(
      label: 'Tasks',
      children: [
        FFListRow.toggle(
          leading: _tile(
            FontAwesomeIcons.wandMagicSparkles,
            SettingsTints.violet,
          ),
          title: 'Smart lists',
          subtitle: 'Today, Upcoming and Overdue strip · coming soon',
          value: s.tasksSmartLists,
          onChanged: editor.setTasksSmartLists,
        ),
        FFListRow.toggle(
          leading: _tile(FontAwesomeIcons.circleCheck, SettingsTints.emerald),
          title: 'Show completed',
          subtitle: 'Keep finished tasks visible in lists',
          value: s.tasksShowCompleted,
          onChanged: editor.setTasksShowCompleted,
        ),
        FFListRow(
          leading: _tile(FontAwesomeIcons.listUl, SettingsTints.blue),
          title: 'Default list',
          value: current?.name ?? 'None',
          onTap: () async {
            final v = await pickSetting<String>(
              context,
              title: 'Default list',
              subtitle: 'New tasks go here unless you pick another list.',
              selected: current?.id ?? '',
              options: [
                option('', 'None'),
                if (lists != null)
                  for (final f in lists) option(f.id, f.name),
              ],
            );
            if (v != null) {
              await editor.setTasksDefaultList(v.isEmpty ? null : v);
            }
          },
        ),
      ],
    );
  }
}

class RemindersDefaultsSection extends ConsumerWidget {
  const RemindersDefaultsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final editor = ref.read(settingsEditorProvider);
    return FFGroupedList(
      label: 'Reminders',
      footer: 'Each reminder can override these in its editor.',
      children: [
        FFListRow(
          leading: _tile(FontAwesomeIcons.solidClock, SettingsTints.orange),
          title: 'Default snooze',
          value: '${s.defaultSnoozeMinutes} min',
          onTap: () async {
            final v = await pickSetting<int>(
              context,
              title: 'Default snooze',
              selected: s.defaultSnoozeMinutes,
              options: [for (final m in snoozeChoices) option(m, '$m min')],
            );
            if (v != null) await editor.setDefaultSnooze(v);
          },
        ),
        FFListRow(
          leading: _tile(FontAwesomeIcons.solidBell, SettingsTints.amber),
          title: 'Reminder sound',
          value: ReminderAlertOptions.soundLabel(s.remindersDefaultSound),
          onTap: () async {
            final v = await pickSetting<String>(
              context,
              title: 'Reminder sound',
              selected: s.remindersDefaultSound,
              options: [
                for (final o in ReminderAlertOptions.sounds)
                  option(o.key, o.label),
              ],
            );
            if (v != null) await editor.setReminderSound(v);
          },
        ),
      ],
    );
  }
}

class HabitsDefaultsSection extends ConsumerWidget {
  const HabitsDefaultsSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(settingsProvider);
    final editor = ref.read(settingsEditorProvider);
    String time(int m) => SettingsLabels.clockTime(m, use24h: s.use24HourTime);
    return FFGroupedList(
      label: 'Habits',
      footer:
          'Check-ins made before the reset time count for the previous '
          'day — handy for night owls.',
      children: [
        FFListRow(
          leading: _tile(FontAwesomeIcons.rotate, ModuleStyle.habits.colors),
          title: 'Day resets at',
          value: time(s.habitResetMinutes),
          onTap: () async {
            final v = await pickSetting<int>(
              context,
              title: 'Day resets at',
              selected: s.habitResetMinutes,
              options: [
                for (final m in habitResetChoices)
                  option(m, m == 0 ? 'Midnight (${time(m)})' : time(m)),
              ],
            );
            if (v != null) await editor.setHabitResetMinutes(v);
          },
        ),
        FFListRow(
          leading: _tile(FontAwesomeIcons.solidCalendar, SettingsTints.violet),
          title: 'Week starts on',
          subtitle: 'Also used by the calendar and insights',
          value: SettingsLabels.weekday(s.weekStartsOn),
          onTap: () =>
              runRootAction(context, ref, SettingsRootAction.weekStart),
        ),
      ],
    );
  }
}
