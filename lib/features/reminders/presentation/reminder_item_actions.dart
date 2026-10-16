/// ============================================================
/// REMINDER ITEM ACTIONS — reminder rows of the shared actions sheet (09)
/// ============================================================
///
/// What: Snooze (by the reminder's own default snooze; pending reminders),
/// Mark done, and Disable / Enable, shown above the generic rows of the
/// long-press sheet.
/// Why: owned by the reminders feature (see
/// shared/item_actions/module_item_actions.dart); the flows themselves
/// (Undo snackbars) live in reminder_flows.dart so the list, the swipe
/// actions and the sheet behave identically. Only the database is
/// written — the notification engine reschedules / cancels.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_summary.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/ff_action_sheet.dart';
import 'package:focusflow/features/reminders/presentation/reminder_flows.dart';
import 'package:focusflow/shared/item_actions/module_item_actions.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Module rows for [item]. Each row's onTap runs after the sheet closes.
Future<ModuleItemActions> reminderItemActions(
  BuildContext context,
  WidgetRef ref,
  ItemSummary item,
) async {
  final r = await ref
      .read(remindersRepositoryProvider)
      .getReminder(item.ref.id);
  if (r == null || !r.isActive) return ModuleItemActions.none;
  final minutes = r.snoozeMinutes;
  final pending = r.isEnabled && !r.isCompleted;
  return ModuleItemActions(
    leading: [
      if (pending)
        FFActionItem(
          icon: FontAwesomeIcons.solidClock,
          label: 'Snooze $minutes min',
          colors: ModuleStyle.reminders.colors,
          onTap: () {
            if (context.mounted) {
              snoozeReminder(context, ref, r, minutes: minutes);
            }
          },
        ),
      if (pending)
        FFActionItem(
          icon: FontAwesomeIcons.solidCircleCheck,
          label: 'Mark done',
          colors: ModuleStyle.notes.colors,
          onTap: () {
            if (context.mounted) markReminderDone(context, ref, r);
          },
        ),
      FFActionItem(
        icon: r.isEnabled
            ? FontAwesomeIcons.solidBellSlash
            : FontAwesomeIcons.solidBell,
        label: r.isEnabled ? 'Disable' : 'Enable',
        colors: r.isEnabled ? ActionTints.lock : ModuleStyle.reminders.colors,
        onTap: () => setReminderEnabled(ref, r, !r.isEnabled),
      ),
    ],
  );
}
