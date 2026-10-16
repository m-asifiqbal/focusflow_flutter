/// ============================================================
/// TASK SCHEDULE CARD — SCHEDULE group of screen 11
/// ============================================================
///
/// What: Date · Time · Repeat · Remind me rows. Each opens its FocusFlow
/// sheet (due date, time wheel, repeat incl. custom RRULE, remind offsets)
/// and writes the choice into the editor form.
/// Why: Date and Time show emerald when set (mockup); Repeat and Remind
/// need a day, so the controller anchors them on today when undated. The
/// linked reminder (and its notification) is synced by the repository on
/// Save.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/presentation/notifiers/task_editor_controller.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/features/tasks/presentation/state/task_editor_state.dart';
import 'package:focusflow/features/tasks/presentation/state/task_labels.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_editor_row.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/due_date_sheet.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/repeat_sheet.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/time_sheet.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

class TaskScheduleCard extends ConsumerWidget {
  const TaskScheduleCard({required this.args, required this.task, super.key});

  final TaskEditorArgs args;

  /// The edited task (form draft).
  final TaskItem task;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ff = context.ff;
    final today = ref.watch(todayProvider);
    final settings = ref.watch(settingsProvider);
    final use24h = settings.use24HourTime;
    final form = ref.read(taskEditorControllerProvider(args).notifier);
    final accent = ff.primary;

    Future<void> pickDate() async {
      final picked = await showDueDateSheet(
        context,
        today: readFreshToday(ref),
        weekStartsOn: settings.weekStartsOn,
        current: task.dueDate,
        title: 'Date',
      );
      if (picked != null) form.setDate(picked.value);
    }

    Future<void> pickTime() async {
      final picked = await showTimeSheet(
        context,
        current: task.dueTimeMinutes,
        use24h: use24h,
      );
      if (picked != null && context.mounted) {
        form.setTime(picked.value, today: readFreshToday(ref));
      }
    }

    Future<void> pickRepeat() async {
      final picked = await showRepeatSheet(
        context,
        current: task.repeatRule,
        start: task.dueDate ?? today,
        weekStartsOn: settings.weekStartsOn,
      );
      if (picked != null && context.mounted) {
        form.setRepeat(picked.value, today: readFreshToday(ref));
      }
    }

    Future<void> pickRemind() async {
      final picked = await showOptionSheet<int?>(
        context,
        title: 'Remind me',
        subtitle: task.dueDate == null
            ? 'The task will be scheduled for today'
            : task.dueTimeMinutes == null
            ? 'All-day tasks remind relative to 9:00 AM'
            : null,
        options: [
          OptionItem<int?>(
            value: null,
            label: 'None',
            icon: FontAwesomeIcons.bellSlash,
            colors: ActionTints.lock,
          ),
          for (final m in TaskLabels.remindOptions)
            OptionItem<int?>(
              value: m,
              label: TaskLabels.remindOffset(m),
              icon: FontAwesomeIcons.solidBell,
              colors: ModuleStyle.reminders.colors,
            ),
        ],
        selected: task.remindOffsetMinutes,
      );
      if (picked != null && context.mounted) {
        form.setRemind(picked.value, today: readFreshToday(ref));
      }
    }

    final hasDate = task.dueDate != null;
    return FFGroupedList(
      children: [
        TaskEditorRow(
          icon: FontAwesomeIcons.solidCalendar,
          colors: ModuleStyle.notes.colors,
          title: 'Date',
          value: TaskLabels.editorDate(task.dueDate, today),
          valueColor: hasDate ? accent : null,
          onTap: pickDate,
        ),
        TaskEditorRow(
          icon: FontAwesomeIcons.solidClock,
          colors: ModuleStyle.notes.colors,
          title: 'Time',
          value: hasDate
              ? TaskLabels.editorTime(task.dueTimeMinutes, use24h: use24h)
              : 'No time',
          valueColor: task.hasDueTime ? accent : null,
          onTap: pickTime,
        ),
        TaskEditorRow(
          icon: FontAwesomeIcons.arrowsRotate,
          colors: ModuleStyle.tasks.colors,
          title: 'Repeat',
          value: task.isRepeating ? task.repeatLabel : 'Never',
          onTap: pickRepeat,
        ),
        TaskEditorRow(
          icon: FontAwesomeIcons.solidBell,
          colors: ModuleStyle.reminders.colors,
          title: 'Remind me',
          value: TaskLabels.remindOffset(
            hasDate ? task.remindOffsetMinutes : null,
          ),
          onTap: pickRemind,
        ),
      ],
    );
  }
}
