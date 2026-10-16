/// ============================================================
/// DUE DATE SHEET — "Reschedule all" / "Change due date" (screens 09, 10)
/// ============================================================
///
/// What: a bottom sheet with the quick choices Today · Tomorrow · Next week
/// · Pick a date… (inline calendar) and optionally "No date". Resolves to a
/// [Picked] local day (null value = "No date"), or null when dismissed.
/// Why: the Tasks list ("Reschedule all"), the item actions sheet ("Change
/// due date") and the editor share the same quick choices; "Next week"
/// follows the user's week start (Settings › General).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';
import 'package:intl/intl.dart';

/// The quick choices relative to [today] (local midnight).
abstract final class DueDateChoices {
  static DateTime today(DateTime today) => DateUtilsX.dateOnly(today);

  static DateTime tomorrow(DateTime today) =>
      DateUtilsX.addDays(DateUtilsX.dateOnly(today), 1);

  /// The first day of next week (per [weekStartsOn]).
  static DateTime nextWeek(DateTime today, int weekStartsOn) =>
      DateUtilsX.addDays(DateUtilsX.startOfWeek(today, weekStartsOn), 7);
}

/// Opens the due date sheet. [current] marks the selected row (and seeds
/// the calendar).
Future<Picked<DateTime?>?> showDueDateSheet(
  BuildContext context, {
  required DateTime today,
  required int weekStartsOn,
  DateTime? current,
  String title = 'Reschedule',
  String? subtitle,
  bool allowNoDate = true,
}) {
  return showFFBottomSheet<Picked<DateTime?>>(
    context,
    builder: (sheetContext) => _DueDateSheet(
      today: DateUtilsX.dateOnly(today),
      weekStartsOn: weekStartsOn,
      current: current == null ? null : DateUtilsX.dateOnly(current),
      title: title,
      subtitle: subtitle,
      allowNoDate: allowNoDate,
    ),
  );
}

class _DueDateSheet extends StatefulWidget {
  const _DueDateSheet({
    required this.today,
    required this.weekStartsOn,
    required this.current,
    required this.title,
    required this.subtitle,
    required this.allowNoDate,
  });

  final DateTime today;
  final int weekStartsOn;
  final DateTime? current;
  final String title;
  final String? subtitle;
  final bool allowNoDate;

  @override
  State<_DueDateSheet> createState() => _DueDateSheetState();
}

class _DueDateSheetState extends State<_DueDateSheet> {
  bool _calendar = false;

  void _pop(DateTime? day) => Navigator.of(context).pop(Picked(day));

  @override
  Widget build(BuildContext context) {
    final today = widget.today;
    final tomorrow = DueDateChoices.tomorrow(today);
    final nextWeek = DueDateChoices.nextWeek(today, widget.weekStartsOn);
    final current = widget.current;
    bool isCurrent(DateTime d) =>
        current != null && DateUtilsX.isSameDay(current, d);
    final quick = {today, tomorrow, nextWeek};
    final pickedOther = current != null && !quick.any(isCurrent);
    final dayFmt = DateFormat('EEE, MMM d');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SheetHeader(widget.title, subtitle: widget.subtitle),
        FFGroupedList(
          dividerIndent: AppSpacing.lg,
          children: [
            OptionRow(
              label: 'Today',
              subtitle: dayFmt.format(today),
              icon: FontAwesomeIcons.solidSun,
              colors: TagPalette.finance,
              selected: isCurrent(today),
              onTap: () => _pop(today),
            ),
            OptionRow(
              label: 'Tomorrow',
              subtitle: dayFmt.format(tomorrow),
              icon: FontAwesomeIcons.cloudSun,
              colors: TagPalette.work,
              selected: isCurrent(tomorrow),
              onTap: () => _pop(tomorrow),
            ),
            OptionRow(
              label: 'Next week',
              subtitle: dayFmt.format(nextWeek),
              icon: FontAwesomeIcons.calendarWeek,
              colors: TagPalette.design,
              selected: isCurrent(nextWeek),
              onTap: () => _pop(nextWeek),
            ),
            OptionRow(
              label: 'Pick a date…',
              subtitle: pickedOther ? dayFmt.format(current) : null,
              icon: FontAwesomeIcons.calendarDays,
              colors: TagPalette.ideas,
              selected: pickedOther,
              onTap: () => setState(() => _calendar = !_calendar),
            ),
            if (widget.allowNoDate)
              OptionRow(
                label: 'No date',
                icon: FontAwesomeIcons.calendarXmark,
                colors: ActionTints.lock,
                selected: false,
                onTap: () => _pop(null),
              ),
          ],
        ),
        if (_calendar) ...[
          const SizedBox(height: AppSpacing.md),
          FFCard(
            padding: EdgeInsetsDirectional.zero,
            child: CalendarDatePicker(
              initialDate: current ?? today,
              firstDate: DateTime(today.year - 5),
              lastDate: DateTime(today.year + 10),
              onDateChanged: _pop,
            ),
          ),
        ],
      ],
    );
  }
}
