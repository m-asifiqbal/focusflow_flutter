/// ============================================================
/// REMINDER QUICK SHEET — "Set reminder" from the item actions sheet (09)
/// ============================================================
///
/// Quick presets (later today, this evening, tomorrow morning, this
/// weekend, next week) + "Pick date & time", "More options" (the full
/// reminder editor) and "Remove reminder" when one is set. A pure picker:
/// it returns a [ReminderQuickChoice]; shared/item_actions/item_pickers.dart
/// writes it through RemindersRepository.upsertLinkedReminder.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:intl/intl.dart';

/// What the user picked in [ReminderQuickSheet].
sealed class ReminderQuickChoice {
  const ReminderQuickChoice();
}

/// Fire at [at].
final class ReminderAt extends ReminderQuickChoice {
  const ReminderAt(this.at);
  final DateTime at;
}

/// Open the date + time pickers.
final class ReminderPickCustom extends ReminderQuickChoice {
  const ReminderPickCustom();
}

/// Open the full reminder editor (repeat, notes…).
final class ReminderMoreOptions extends ReminderQuickChoice {
  const ReminderMoreOptions();
}

/// Delete the linked reminder.
final class ReminderRemove extends ReminderQuickChoice {
  const ReminderRemove();
}

/// One preset of the sheet.
typedef ReminderPreset = ({String label, IconData icon, DateTime at});

/// The presets that still lie ahead of [now] (pure; unit-tested).
List<ReminderPreset> reminderPresets(DateTime now) {
  final today = DateTime(now.year, now.month, now.day);
  DateTime at(int days, int hour) =>
      DateTime(today.year, today.month, today.day + days, hour);
  final later = DateTime(now.year, now.month, now.day, now.hour + 3);
  final weekday = now.weekday; // Mon = 1 … Sun = 7
  return [
    if (DateUtilsX.isSameDay(later, now) && later.hour <= 21)
      (label: 'Later today', icon: FontAwesomeIcons.clock, at: later),
    if (now.hour < 17)
      (label: 'This evening', icon: FontAwesomeIcons.solidMoon, at: at(0, 18)),
    (label: 'Tomorrow morning', icon: FontAwesomeIcons.solidSun, at: at(1, 9)),
    if (weekday < DateTime.friday)
      (
        label: 'This weekend',
        icon: FontAwesomeIcons.mugHot,
        at: at(DateTime.saturday - weekday, 10),
      ),
    (
      label: 'Next week',
      icon: FontAwesomeIcons.calendarWeek,
      at: at(8 - weekday, 9),
    ),
  ];
}

/// "Fri, 9:00 AM" / "Today, 18:00".
String reminderWhenLabel(DateTime at, DateTime now, {bool use24h = false}) {
  final diff = DateUtilsX.daysBetween(now, at);
  final day = switch (diff) {
    0 => 'Today',
    1 => 'Tomorrow',
    _ when diff > 1 && diff < 7 => DateFormat('EEE').format(at),
    _ => DateFormat('MMM d').format(at),
  };
  final time = DateFormat(use24h ? 'HH:mm' : 'h:mm a').format(at);
  return '$day, $time';
}

class ReminderQuickSheet extends StatelessWidget {
  const ReminderQuickSheet({
    required this.now,
    this.current,
    this.use24h = false,
    super.key,
  });

  final DateTime now;

  /// Next trigger of the item's linked reminder, if any.
  final DateTime? current;
  final bool use24h;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final colors = ModuleStyle.reminders;
    void pop(ReminderQuickChoice c) =>
        Navigator.of(context).pop<ReminderQuickChoice>(c);
    final when = current;

    FFListRow row(
      IconData icon,
      String label, {
      String? value,
      ModuleColors? tint,
      bool destructive = false,
      required ReminderQuickChoice choice,
    }) => FFListRow(
      leading: FFIconTile.soft(icon: icon, colors: tint ?? colors.colors),
      title: label,
      value: value,
      destructive: destructive,
      onTap: () => pop(choice),
    );

    return FFBottomSheet(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text('Set reminder', style: context.text.title),
          ),
          if (when != null) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              'Currently ${reminderWhenLabel(when, now, use24h: use24h)}',
              style: context.text.meta.copyWith(color: ff.inkMuted),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FFGroupedList(
            children: [
              for (final p in reminderPresets(now))
                row(
                  p.icon,
                  p.label,
                  value: reminderWhenLabel(p.at, now, use24h: use24h),
                  choice: ReminderAt(p.at),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FFGroupedList(
            children: [
              row(
                FontAwesomeIcons.calendarDays,
                'Pick date & time',
                tint: TagPalette.work,
                choice: const ReminderPickCustom(),
              ),
              row(
                FontAwesomeIcons.sliders,
                'More options',
                tint: ActionTints.lock,
                choice: const ReminderMoreOptions(),
              ),
              if (when != null)
                row(
                  FontAwesomeIcons.bellSlash,
                  'Remove reminder',
                  tint: TagPalette.high,
                  destructive: true,
                  choice: const ReminderRemove(),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
