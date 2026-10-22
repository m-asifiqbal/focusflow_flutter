/// ============================================================
/// RESTORE RESCHEDULE — "This reminder's time has passed" after a restore
/// ============================================================
///
/// What: after Archive / Recently Deleted restore reminders, any one-time
/// reminder whose time already passed (Reminder.isMissed) would come back
/// stale and never fire. Prompt 23: "reminders ask to reschedule if past".
/// This offers: pick a new date + time (rescheduleReminder, screen 10/13
/// sheets), open the reminder editor (screen 13), or keep it as is.
/// Why here: item_lifecycle_actions.dart is the one restore path for every
/// screen, so the rule holds wherever items are restored.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/features/library/presentation/widgets/choice_sheets.dart';
import 'package:focusflow/features/reminders/domain/entities/reminder.dart';
import 'package:focusflow/features/reminders/presentation/reminder_flows.dart';
import 'package:focusflow/shared/providers/core_providers.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';
import 'package:go_router/go_router.dart';

/// Choices of the "Reschedule?" sheet.
enum RestoreRescheduleChoice { pickTime, openEditor, keep }

/// The restored reminders among [refs] whose (one-time) time has passed.
Future<List<Reminder>> pastRemindersAmong(
  WidgetRef ref,
  List<ItemRef> refs,
) async {
  final ids = refs.where((r) => r.type == ItemType.reminder).map((r) => r.id);
  if (ids.isEmpty) return const [];
  final repo = ref.read(remindersRepositoryProvider);
  final now = ref.read(clockProvider).now();
  final past = <Reminder>[];
  for (final id in ids) {
    final r = await repo.getReminder(id);
    if (r != null && r.isActive && r.isMissed(now)) past.add(r);
  }
  return past;
}

/// Asks to reschedule each restored reminder in [refs] whose time passed.
/// Does nothing when none did.
Future<void> offerRescheduleAfterRestore(
  BuildContext context,
  WidgetRef ref,
  List<ItemRef> refs,
) async {
  final past = await pastRemindersAmong(ref, refs);
  for (final r in past) {
    if (!context.mounted) return;
    final title = r.title.trim().isEmpty ? tr('Reminder') : r.title.trim();
    final picked = await showChoiceSheet<RestoreRescheduleChoice>(
      context,
      title: tr('Reschedule "{title}"?', {'title': title}),
      options: [
        ChoiceOption(
          value: RestoreRescheduleChoice.pickTime,
          label: tr('Pick a new time'),
          subtitle: tr('Its time has already passed'),
          icon: FontAwesomeIcons.calendarDays,
          colors: ModuleStyle.reminders.colors,
        ),
        ChoiceOption(
          value: RestoreRescheduleChoice.openEditor,
          label: tr('Edit reminder'),
          icon: FontAwesomeIcons.penToSquare,
          colors: ModuleStyle.reminders.colors,
        ),
        ChoiceOption(
          value: RestoreRescheduleChoice.keep,
          label: tr('Keep as is'),
          icon: FontAwesomeIcons.check,
          colors: ModuleStyle.reminders.colors,
        ),
      ],
    );
    if (!context.mounted) return;
    switch (picked?.value) {
      case RestoreRescheduleChoice.pickTime:
        await rescheduleReminder(context, ref, r);
      case RestoreRescheduleChoice.openEditor:
        await context.push(AppRoutes.reminder(r.id));
      case RestoreRescheduleChoice.keep || null:
        break;
    }
  }
}
