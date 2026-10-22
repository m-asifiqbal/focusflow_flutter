/// ============================================================
/// HABIT REMINDERS SECTION — Remind me · Times · Start date (15)
/// ============================================================
///
/// Only edits the draft's fields; the notification engine schedules one
/// reminder per time on due days once the habit is saved.
/// [HabitManageSection] is the edit-mode footer: Reset history, Archive,
/// Delete.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/presentation/habit_format.dart';
import 'package:focusflow/features/habits/presentation/notifiers/habit_editor_controller.dart';
import 'package:focusflow/features/habits/presentation/providers/habits_providers.dart';
import 'package:focusflow/features/habits/presentation/widgets/editor/habit_details_section.dart';
import 'package:focusflow/features/habits/presentation/widgets/editor/habit_editor_sheets.dart';

class HabitRemindersSection extends ConsumerWidget {
  const HabitRemindersSection({
    required this.args,
    required this.draft,
    super.key,
  });

  final HabitEditorArgs args;
  final Habit draft;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = ref.read(habitEditorControllerProvider(args).notifier);
    final today = ref.watch(habitTodayProvider);
    final orange = ModuleStyle.reminders.colors;

    Future<void> pickStart() async {
      // The window always contains the current start date (an imported or
      // old habit may start long ago), or the picker would assert.
      final start = draft.startDate;
      final early = DateUtilsX.addDays(today, -365 * 5);
      final late = DateUtilsX.addDays(today, 365);
      final picked = await showDatePicker(
        context: context,
        initialDate: start,
        firstDate: start.isBefore(early) ? start : early,
        lastDate: start.isAfter(late) ? start : late,
      );
      if (picked != null) c.setStartDate(picked);
    }

    return FFGroupedList(
      label: tr('Reminders'),
      children: [
        FFListRow.toggle(
          leading: HabitRowTile(FontAwesomeIcons.solidBell, colors: orange),
          title: tr('Remind me'),
          value: draft.reminderEnabled,
          onChanged: c.setReminderEnabled,
        ),
        FFListRow(
          leading: HabitRowTile(FontAwesomeIcons.solidClock, colors: orange),
          title: tr('Times'),
          value: draft.reminderTimes.isEmpty
              ? tr('Add a time')
              : HabitFormat.times(draft.reminderTimes),
          enabled: draft.reminderEnabled,
          onTap: () => showHabitTimesSheet(context, args),
        ),
        FFListRow(
          leading: HabitRowTile(
            FontAwesomeIcons.solidCalendarCheck,
            colors: ModuleStyle.habits.colors,
          ),
          title: tr('Start date'),
          value: DateUtilsX.relativeDay(draft.startDate, today),
          onTap: pickStart,
        ),
      ],
    );
  }
}

/// Edit mode only: Reset history · Archive habit · Delete habit.
class HabitManageSection extends StatelessWidget {
  const HabitManageSection({
    required this.onReset,
    required this.onArchive,
    required this.onDelete,
    super.key,
  });

  final VoidCallback onReset;
  final VoidCallback onArchive;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return FFGroupedList(
      label: tr('Manage'),
      children: [
        FFListRow(
          leading: const HabitRowTile(
            FontAwesomeIcons.rotateLeft,
            colors: ActionTints.lock,
          ),
          title: tr('Reset history'),
          subtitle: tr('Deletes every check-in, keeps the habit'),
          onTap: onReset,
        ),
        FFListRow(
          leading: HabitRowTile(
            FontAwesomeIcons.boxArchive,
            colors: ModuleStyle.vault.colors,
          ),
          title: tr('Archive habit'),
          onTap: onArchive,
        ),
        FFListRow(
          leading: const HabitRowTile(
            FontAwesomeIcons.trashCan,
            colors: TagPalette.high,
          ),
          title: tr('Delete habit'),
          destructive: true,
          onTap: onDelete,
        ),
      ],
    );
  }
}
