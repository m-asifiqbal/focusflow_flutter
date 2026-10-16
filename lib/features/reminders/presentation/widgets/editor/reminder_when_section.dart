/// ============================================================
/// REMINDER WHEN + REPEAT — day chips, time wheel and repeat chips (13)
/// ============================================================
///
/// What:
///   * [ReminderDayChips] — Today · Tomorrow · Next week · Pick date (four
///     equal rounded tiles; the selected one is solid orange, "Pick date"
///     shows the chosen day when it is none of the others).
///   * [ReminderRepeatChips] — Once · Daily · Weekdays · Weekly · Monthly ·
///     Custom (opens the shared repeat sheet).
/// Why: both rows derive their selection from the draft ([WhenChoice] /
/// [RepeatPreset], pure) and only call the editor controller.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/presentation/notifiers/reminder_editor_controller.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_editor_state.dart';
import 'package:focusflow/features/tasks/presentation/providers/minute_clock.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/due_date_sheet.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/repeat_sheet.dart';
import 'package:focusflow/features/tasks/presentation/widgets/uniform_label_scale.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';
import 'package:intl/intl.dart';
import 'package:focusflow/features/reminders/presentation/reminder_tokens.dart';

class ReminderDayChips extends ConsumerWidget {
  const ReminderDayChips({
    required this.args,
    required this.reminder,
    super.key,
  });

  final ReminderEditorArgs args;

  /// The edited reminder (form draft).
  final Reminder reminder;

  /// Chip height and gap (mockup: 38 pt, 8 pt).
  static const double height = 38;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final today = ref.watch(todayProvider);
    final weekStartsOn = ref.watch(settingsProvider).weekStartsOn;
    final form = ref.read(reminderEditorControllerProvider(args).notifier);
    final day = reminder.triggerAt;
    final selected = WhenChoice.of(day, today, weekStartsOn);

    Future<void> pick() async {
      final picked = await showDueDateSheet(
        context,
        today: readFreshToday(ref),
        weekStartsOn: weekStartsOn,
        current: day,
        title: 'Pick date',
        allowNoDate: false,
      );
      final value = picked?.value;
      if (value != null) form.setDay(value);
    }

    final pickLabel = selected == WhenChoice.other
        ? DateFormat('EEE d MMM').format(day)
        : 'Pick date';
    const labels = ['Today', 'Tomorrow', 'Next week'];

    Widget chip(WhenChoice c, String label, TextScaler scaler) => Expanded(
      child: _ReminderChip(
        label: label,
        textScaler: scaler,
        selected: selected == c,
        link: c == WhenChoice.other && selected != c,
        onTap: c == WhenChoice.other
            ? pick
            : () => form.setDay(c.dayFor(readFreshToday(ref), weekStartsOn)!),
      ),
    );

    // One text scale for the four tiles: the widest label decides, so
    // "Next week" never renders smaller than "Today".
    return LayoutBuilder(
      builder: (context, box) {
        final tileWidth = (box.maxWidth - 3 * AppSpacing.sm) / 4;
        final scaler = uniformLabelScaler(
          context,
          labels: [...labels, pickLabel],
          style: context.text.reminderChip,
          maxWidth: tileWidth - 2 * AppSpacing.sm,
        );
        return Row(
          children: [
            chip(WhenChoice.today, labels[0], scaler),
            const SizedBox(width: AppSpacing.sm),
            chip(WhenChoice.tomorrow, labels[1], scaler),
            const SizedBox(width: AppSpacing.sm),
            chip(WhenChoice.nextWeek, labels[2], scaler),
            const SizedBox(width: AppSpacing.sm),
            chip(WhenChoice.other, pickLabel, scaler),
          ],
        );
      },
    );
  }
}

/// One WHEN tile ([pill] false: rounded rect, no border) or REPEAT pill
/// ([pill] true: mint border, muted teal label). Selected = solid orange.
/// Lighter than [FFChip] (medium 13 pt label, no glow), as in the mockup.
class _ReminderChip extends StatelessWidget {
  const _ReminderChip({
    required this.label,
    required this.selected,
    required this.onTap,
    this.link = false,
    this.pill = false,
    this.textScaler,
  });

  /// Shared row scale (WHEN tiles); null = the ambient scale.
  final TextScaler? textScaler;

  final String label;
  final bool selected;

  /// "Pick date" reads as an action (primary ink).
  final bool link;
  final bool pill;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final orange = ModuleStyle.reminders.solid;
    final fg = selected
        ? AppPalette.white
        : link
        ? ff.primary
        : pill
        ? Color.lerp(ff.primaryStrong, ff.inkMuted, 0.45)!
        : ff.ink;
    final text = Text(
      label,
      maxLines: 1,
      textScaler: textScaler,
      style: context.text.reminderChip.copyWith(color: fg),
    );
    return Semantics(
      button: true,
      selected: selected,
      label: label,
      onTap: onTap,
      excludeSemantics: true,
      child: FFPressable(
        onTap: onTap,
        scale: 0.96,
        child: AnimatedContainer(
          duration: context.motion(AppMotion.fast),
          curve: AppMotion.curve,
          constraints: BoxConstraints(
            minHeight: pill ? AppSizes.chip : ReminderDayChips.height,
            minWidth: pill ? ReminderSizes.pillMinWidth : 0,
          ),
          padding: EdgeInsetsDirectional.symmetric(
            horizontal: pill ? AppSpacing.md : AppSpacing.sm,
            vertical: ReminderSizes.chipVertical,
          ),
          alignment: pill ? null : Alignment.center,
          decoration: BoxDecoration(
            color: selected ? orange : ff.surface,
            borderRadius: BorderRadius.circular(
              pill ? AppRadii.pill : AppRadii.button,
            ),
            border: pill
                ? Border.all(
                    color: selected ? orange : ff.chipBorder,
                    width: ReminderSizes.chipBorder,
                  )
                : null,
          ),
          // A pill's label sits in a Row so it is centred in the pill's
          // minimum height on every font (a bare Text would hug the top
          // whenever the font's line is shorter than the slot).
          child: pill
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [Flexible(child: text)],
                )
              : FittedBox(fit: BoxFit.scaleDown, child: text),
        ),
      ),
    );
  }
}

class ReminderRepeatChips extends ConsumerWidget {
  const ReminderRepeatChips({
    required this.args,
    required this.reminder,
    super.key,
  });

  final ReminderEditorArgs args;
  final Reminder reminder;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final weekStartsOn = ref.watch(settingsProvider).weekStartsOn;
    final form = ref.read(reminderEditorControllerProvider(args).notifier);
    final start = reminder.triggerAt;
    final selected = RepeatPreset.of(reminder.repeatRule, start);

    Future<void> custom() async {
      final picked = await showRepeatSheet(
        context,
        current: reminder.repeatRule,
        start: start,
        weekStartsOn: weekStartsOn,
      );
      if (picked != null) form.setRepeat(picked.value);
    }

    return Wrap(
      spacing: AppSpacing.sm,
      runSpacing: 9,
      children: [
        for (final p in RepeatPreset.values)
          _ReminderChip(
            label: p.label,
            selected: p == selected,
            pill: true,
            onTap: p == RepeatPreset.custom
                ? custom
                : () => form.setRepeat(p.rule(start)),
          ),
      ],
    );
  }
}
