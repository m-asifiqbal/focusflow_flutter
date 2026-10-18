/// ============================================================
/// CALENDAR FLOWS — the side effects of the calendar screen (screen 26)
/// ============================================================
///
/// What: Quick Add on a day, opening an agenda row's item, and the
/// week-view drag-to-reschedule with its Undo snackbar.
/// Why: shared by the header "+", day long-press, the empty-day "Add",
/// the agenda rows and the week cells, so every entry point behaves the
/// same (and widgets stay free of repository calls).
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/router/app_routes.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/calendar/domain/entities/calendar_entry.dart';
import 'package:focusflow/features/calendar/presentation/providers/calendar_providers.dart';
import 'package:focusflow/features/quick_add/presentation/quick_add.dart';
import 'package:go_router/go_router.dart';

/// Quick Add prefilled with [day].
Future<void> addOnCalendarDay(BuildContext context, DateTime day) =>
    showQuickAdd(context, date: day);

/// Opens the item behind an agenda row (editor or detail).
void openCalendarEntry(BuildContext context, CalendarEntry entry) {
  context.push(AppRoutes.open(entry.ref));
}

/// Moves a dragged task row to [day] and offers Undo (5 s).
Future<void> moveCalendarEntry(
  BuildContext context,
  WidgetRef ref,
  CalendarEntry entry,
  DateTime day,
) async {
  final rescheduler = ref.read(calendarReschedulerProvider);
  final previous = await rescheduler.move(entry, day);
  if (previous == null || !context.mounted) return;
  showUndoSnackbar(
    context,
    message: 'Moved to ${DateFormats.of('EEE, MMM d').format(day)}',
    icon: FontAwesomeIcons.calendarDay,
    onUndo: () => rescheduler.restore(entry, previous),
  );
}
