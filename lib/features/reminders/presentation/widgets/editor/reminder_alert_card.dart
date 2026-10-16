/// ============================================================
/// REMINDER ALERT + LINK CARDS — ALERT and LINK TO groups of screen 13
/// ============================================================
///
/// What:
///   * [ReminderAlertCard] — Sound (option sheet) · Alarm-style (full
///     screen) switch · Default snooze (option sheet) · Location trigger
///     ("Off"; explains v1.1).
///   * [ReminderLinkCard] — "Task or note" (link picker; "None").
/// Why: rows reuse the task editor's [TaskEditorRow] so both editors look
/// the same; every choice only updates the editor form.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/features/reminders/presentation/reminder_tokens.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/presentation/notifiers/reminder_editor_controller.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_alert_options.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_editor_state.dart';
import 'package:focusflow/features/reminders/presentation/widgets/editor/reminder_link_sheet.dart';
import 'package:focusflow/features/tasks/presentation/widgets/editor/task_editor_row.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';

class ReminderAlertCard extends ConsumerWidget {
  const ReminderAlertCard({
    required this.args,
    required this.reminder,
    super.key,
  });

  final ReminderEditorArgs args;
  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.read(reminderEditorControllerProvider(args).notifier);
    final orange = ModuleStyle.reminders.colors;

    Future<void> pickSound() async {
      final picked = await showOptionSheet<String>(
        context,
        title: 'Sound',
        options: [
          for (final s in ReminderAlertOptions.sounds)
            OptionItem(
              value: s.key,
              label: s.label,
              icon: s.key == 'silent'
                  ? FontAwesomeIcons.volumeXmark
                  : FontAwesomeIcons.volumeHigh,
              colors: orange,
            ),
        ],
        selected: reminder.sound,
        accent: orange.solid,
      );
      if (picked != null) form.setSound(picked.value);
    }

    Future<void> pickSnooze() async {
      final picked = await showOptionSheet<int>(
        context,
        title: 'Default snooze',
        subtitle: 'Used by the Snooze button on the notification',
        options: [
          for (final m in ReminderAlertOptions.snoozeMinutes)
            OptionItem(
              value: m,
              label: ReminderAlertOptions.snoozeLabel(m),
              icon: FontAwesomeIcons.clockRotateLeft,
              colors: TagPalette.work,
            ),
        ],
        selected: reminder.snoozeMinutes,
        accent: orange.solid,
      );
      if (picked != null) form.setSnooze(picked.value);
    }

    final alarm = reminder.alertStyle == AlertStyle.alarm;
    return FFGroupedList(
      children: [
        TaskEditorRow(
          icon: FontAwesomeIcons.volumeHigh,
          colors: orange,
          title: 'Sound',
          value: ReminderAlertOptions.soundLabel(reminder.sound),
          onTap: pickSound,
        ),
        _SwitchRow(
          icon: FontAwesomeIcons.bellConcierge,
          colors: TagPalette.high,
          title: 'Alarm-style (full screen)',
          value: alarm,
          onChanged: form.setAlarm,
        ),
        TaskEditorRow(
          icon: FontAwesomeIcons.clockRotateLeft,
          colors: TagPalette.work,
          title: 'Default snooze',
          value: ReminderAlertOptions.snoozeLabel(reminder.snoozeMinutes),
          onTap: pickSnooze,
        ),
        TaskEditorRow(
          icon: FontAwesomeIcons.locationDot,
          colors: TagPalette.design,
          title: 'Location trigger',
          value: reminder.location?.label.isNotEmpty ?? false
              ? reminder.location!.label
              : 'Off',
          onTap: () => showLocationTriggerSheet(context),
        ),
      ],
    );
  }
}

class ReminderLinkCard extends ConsumerWidget {
  const ReminderLinkCard({
    required this.args,
    required this.reminder,
    super.key,
  });

  final ReminderEditorArgs args;
  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final form = ref.read(reminderEditorControllerProvider(args).notifier);
    final link = reminder.linkedRef;
    final title = reminder.linkedTitle?.trim();

    Future<void> pick() async {
      final picked = await showReminderLinkSheet(context, current: link);
      if (picked == null) return;
      final v = picked.value;
      form.setLink(v?.ref, v?.title);
    }

    final style = link?.type == ItemType.note
        ? ModuleStyle.notes
        : ModuleStyle.tasks;
    return FFGroupedList(
      children: [
        TaskEditorRow(
          icon: style.icon,
          colors: style.colors,
          title: link == null
              ? 'Task or note'
              : link.type == ItemType.note
              ? 'Note'
              : 'Task',
          value: link == null
              ? 'None'
              : (title == null || title.isEmpty ? 'Untitled' : title),
          onTap: pick,
        ),
      ],
    );
  }
}

/// [TaskEditorRow]'s layout with a trailing switch (the whole row toggles).
class _SwitchRow extends StatelessWidget {
  const _SwitchRow({
    required this.icon,
    required this.colors,
    required this.title,
    required this.value,
    required this.onChanged,
  });

  final IconData icon;
  final ModuleColors colors;
  final String title;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    return MergeSemantics(
      child: InkWell(
        onTap: () => onChanged(!value),
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: TaskEditorRow.minHeight),
          child: Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.lg,
              vertical: AppSpacing.sm,
            ),
            child: Row(
              children: [
                FFIconTile.soft(
                  icon: icon,
                  colors: colors,
                  size: TaskEditorRow.tileSize,
                ),
                const SizedBox(width: ReminderSizes.tileGap),
                Expanded(
                  child: Text(
                    title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.rowTitle.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: AppSpacing.sm),
                FFSwitch(
                  value: value,
                  onChanged: onChanged,
                  semanticLabel: title,
                  activeColor: ModuleStyle.reminders.solid,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
