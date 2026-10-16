/// ============================================================
/// REMINDER CARD — one timeline row of screen 12 (presentation only)
/// ============================================================
///
/// What: the time column ("07:00" over "AM") and the card: 4 pt start
/// border in the reminder colour, soft icon tile, title, meta line and
/// the enable toggle. Done occurrences render at 45 % opacity, struck
/// through, with a check instead of the toggle. The next-due card shows
/// SNOOZE 10m / MARK DONE, a bolder time and a deeper shadow (its row
/// also bleeds into the gutters, see ReminderTimelineItem); missed cards
/// show RESCHEDULE / MARK DONE.
/// Why: pure widget (callbacks in, no providers) so it is easy to test
/// and reuse (calendar agenda, home "Up next").
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/reminders/presentation/reminder_style.dart';
import 'package:focusflow/features/reminders/presentation/state/reminder_labels.dart';
import 'package:focusflow/features/reminders/presentation/widgets/reminder_card_parts.dart';
import 'package:focusflow/features/reminders/presentation/reminder_tokens.dart';

/// Which inline actions a card shows.
enum ReminderCardActions { none, next, missed }

class ReminderCard extends StatelessWidget {
  const ReminderCard({
    required this.occurrence,
    required this.now,
    this.use24h = false,
    this.actions = ReminderCardActions.none,
    this.onTap,
    this.onLongPress,
    this.onToggle,
    this.onSnooze,
    this.onDone,
    this.onReschedule,
    this.snoozeMinutes = 10,
    this.wrapCard,
    super.key,
  });

  final ReminderOccurrence occurrence;
  final DateTime now;
  final bool use24h;
  final ReminderCardActions actions;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final ValueChanged<bool>? onToggle;
  final VoidCallback? onSnooze;
  final VoidCallback? onDone;
  final VoidCallback? onReschedule;
  final int snoozeMinutes;

  /// Wraps the card (not the time column), e.g. in swipe actions.
  final Widget Function(Widget card)? wrapCard;

  /// Width of the time column and the gap after it.
  static const double timeColumn = 54;
  static const double timeGap = 12;

  @override
  Widget build(BuildContext context) {
    final done = occurrence.isDone;
    final missed = actions == ReminderCardActions.missed;
    final next = actions == ReminderCardActions.next && !done;
    final row = Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: timeColumn,
          child: ReminderTimeLabel(
            at: occurrence.at,
            use24h: use24h,
            danger: missed,
            emphasis: next,
          ),
        ),
        const SizedBox(width: timeGap),
        Expanded(child: wrapCard?.call(_card(context)) ?? _card(context)),
      ],
    );
    return Semantics(
      label: ReminderLabels.semantics(occurrence, now, use24h: use24h),
      child: done ? Opacity(opacity: 0.45, child: row) : row,
    );
  }

  Widget _card(BuildContext context) {
    final ff = context.ff;
    final r = occurrence.reminder;
    final style = ReminderStyle.of(r);
    final done = occurrence.isDone;
    final title = r.title.trim().isEmpty ? 'Untitled reminder' : r.title;
    final showActions = actions != ReminderCardActions.none && !done;
    final texts = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.cardTitle.copyWith(
            decoration: done ? TextDecoration.lineThrough : null,
            decorationColor: ff.inkMuted,
            decorationThickness: 2,
            color: done ? ff.inkMuted : ff.ink,
          ),
        ),
        const SizedBox(height: ReminderSizes.hairGap),
        Text(
          ReminderLabels.meta(occurrence, now),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.reminderNote.copyWith(color: ff.inkFaint),
        ),
      ],
    );
    final trailing = done
        ? const ReminderDoneCheck()
        : FFSwitch(
            value: r.isEnabled,
            onChanged: onToggle,
            semanticLabel: r.isEnabled ? 'Turn off $title' : 'Turn on $title',
          );
    // The pills span under the toggle so both fit on one line.
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: texts),
            const SizedBox(width: AppSpacing.sm),
            trailing,
          ],
        ),
        if (showActions)
          Wrap(
            spacing: AppSpacing.sm,
            children: [
              if (actions == ReminderCardActions.missed)
                ReminderActionPill(
                  label: 'RESCHEDULE',
                  colors: ModuleStyle.reminders.colors,
                  onTap: onReschedule,
                )
              else
                ReminderActionPill(
                  label: 'SNOOZE ${snoozeMinutes}m',
                  colors: ModuleStyle.reminders.colors,
                  onTap: onSnooze,
                ),
              ReminderActionPill(
                label: 'MARK DONE',
                primary: true,
                onTap: onDone,
              ),
            ],
          ),
      ],
    );
    return ReminderCardFrame(
      accent: style.colors.solid,
      // The pills carry 10 pt of tap-target padding below them.
      bottomPadding: showActions
          ? ReminderSizes.cardBottomWithPills
          : ReminderSizes.cardVertical,
      elevated: actions == ReminderCardActions.next && !done,
      onTap: onTap,
      onLongPress: onLongPress,
      child: Row(
        children: [
          FFIconTile.soft(icon: style.icon, colors: style.colors),
          const SizedBox(width: AppSpacing.md),
          Expanded(child: content),
        ],
      ),
    );
  }
}
