/// ============================================================
/// REMINDER TIMELINE ITEM — a [ReminderCard] wired to the app (screen 12)
/// ============================================================
///
/// What: tap → editor (13), long-press → shared actions sheet, swipe →
/// Archive / Delete / Snooze (Settings › Gestures via [ItemSwipe]),
/// toggle → enable / disable, inline SNOOZE (the reminder's own default
/// snooze) / MARK DONE / RESCHEDULE. Done rows still swipe to Archive /
/// Delete; only Complete / Snooze are hidden for them.
/// Why: the card stays pure presentation; this is the only place that
/// knows what a gesture means. Writes go through reminder_flows.dart
/// (the notification engine reacts to the database, never the UI).
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/features/reminders/presentation/reminder_tokens.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder_occurrence.dart';
import 'package:focusflow/features/reminders/presentation/reminder_flows.dart';
import 'package:focusflow/features/reminders/presentation/widgets/reminder_card.dart';
import 'package:focusflow/shared/item_actions/item_actions_sheet.dart';
import 'package:focusflow/shared/item_actions/item_swipe.dart';
import 'package:go_router/go_router.dart';

class ReminderTimelineItem extends ConsumerWidget {
  const ReminderTimelineItem({
    required this.occurrence,
    required this.now,
    this.use24h = false,
    this.isNext = false,
    this.isMissed = false,
    super.key,
  });

  final ReminderOccurrence occurrence;
  final DateTime now;
  final bool use24h;

  /// The next-due row (inline SNOOZE / MARK DONE).
  final bool isNext;

  /// A row of the MISSED section (RESCHEDULE / MARK DONE).
  final bool isMissed;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final r = occurrence.reminder;
    final snooze = r.snoozeMinutes;
    final pending = !occurrence.isDone;
    final row = ReminderCard(
      occurrence: occurrence,
      now: now,
      use24h: use24h,
      snoozeMinutes: snooze,
      actions: isMissed
          ? ReminderCardActions.missed
          : (isNext ? ReminderCardActions.next : ReminderCardActions.none),
      onTap: () => context.push(AppRoutes.reminder(r.id)),
      onLongPress: () => showItemActions(context, ref, r.ref),
      onToggle: (on) => setReminderEnabled(ref, r, on),
      onSnooze: () => snoozeReminder(
        context,
        ref,
        r,
        minutes: snooze,
        occurrence: occurrence.at,
      ),
      onDone: () =>
          markReminderDone(context, ref, r, occurrence: occurrence.at),
      onReschedule: () => rescheduleReminder(context, ref, r),
      // Only the card swipes; the time column stays put.
      wrapCard: (card) => ItemSwipe(
        item: r.ref,
        title: r.title,
        isPinned: r.isPinned,
        isFavorite: r.isFavorite,
        radius: AppRadii.card,
        completeLabel: 'Done',
        onComplete: pending
            ? () => markReminderDone(context, ref, r, occurrence: occurrence.at)
            : null,
        onSnooze: pending
            ? () => snoozeReminder(
                context,
                ref,
                r,
                minutes: snooze,
                occurrence: occurrence.at,
              )
            : null,
        child: card,
      ),
    );
    // The next-due row is emphasised: it pulls into the time gutter and
    // the screen gutter (design/12), still inside the screen.
    final bleed = isNext && !isMissed && pending;
    return Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        AppSpacing.screen - (bleed ? ReminderSizes.nextBleedStart : 0),
        0,
        AppSpacing.screen - (bleed ? ReminderSizes.nextBleedEnd : 0),
        AppSpacing.cardGap,
      ),
      child: row,
    );
  }
}
