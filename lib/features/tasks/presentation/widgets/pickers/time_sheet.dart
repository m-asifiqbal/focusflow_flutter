/// ============================================================
/// TIME SHEET — "Time" picker of the task / reminder editors (11, 13)
/// ============================================================
///
/// What: a FocusFlow bottom sheet with quick times (Morning · Noon ·
/// Afternoon · Evening), an iOS-style wheel and "All day". Resolves to a
/// [Picked] minutes-after-midnight (null value = all day), or null when
/// dismissed.
/// Why: the prompt asks for bottom-sheet pickers in FocusFlow style rather
/// than the raw Material time dialog; the 12/24 h setting is respected.
/// ============================================================
library;

import 'package:flutter/cupertino.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/features/tasks/presentation/task_tokens.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';

/// Quick choices (minutes after midnight).
const Map<String, int> kQuickTimes = {
  'Morning': 9 * 60,
  'Noon': 12 * 60,
  'Afternoon': 15 * 60,
  'Evening': 18 * 60,
};

/// Opens the time sheet seeded with [current] (minutes; null = all day).
/// [allowAllDay] adds the "All day" action (tasks; reminders need a time).
Future<Picked<int?>?> showTimeSheet(
  BuildContext context, {
  int? current,
  bool use24h = false,
  bool allowAllDay = true,
  String title = 'Time',
}) {
  return showFFBottomSheet<Picked<int?>>(
    context,
    wrap: false,
    builder: (_) => _TimeSheet(
      initial: current ?? 9 * 60,
      hadTime: current != null,
      use24h: use24h,
      allowAllDay: allowAllDay,
      title: title,
    ),
  );
}

class _TimeSheet extends StatefulWidget {
  const _TimeSheet({
    required this.initial,
    required this.hadTime,
    required this.use24h,
    required this.allowAllDay,
    required this.title,
  });

  final int initial;
  final bool hadTime;
  final bool use24h;
  final bool allowAllDay;
  final String title;

  @override
  State<_TimeSheet> createState() => _TimeSheetState();
}

class _TimeSheetState extends State<_TimeSheet> {
  late int _minutes = widget.initial;

  /// Rebuilds the wheel when a quick chip jumps to a new time.
  var _wheelKey = 0;

  void _pop(int? minutes) => Navigator.of(context).pop(Picked(minutes));

  void _quick(int minutes) => setState(() {
    _minutes = minutes;
    _wheelKey++;
  });

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final time = DateUtilsX.minutesToTime(_minutes, use24h: widget.use24h);
    return FFBottomSheet(
      footer: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          FFPrimaryButton(
            label: 'Set $time',
            icon: FontAwesomeIcons.solidClock,
            onPressed: () => _pop(_minutes),
          ),
          if (widget.allowAllDay) ...[
            const SizedBox(height: AppSpacing.sm),
            FFSecondaryButton(
              label: widget.hadTime ? 'Remove time (all day)' : 'All day',
              icon: FontAwesomeIcons.calendarDay,
              onPressed: () => _pop(null),
            ),
          ],
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          SheetHeader(widget.title),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.sm,
            children: [
              for (final e in kQuickTimes.entries)
                FFChip(
                  label:
                      '${e.key} · '
                      '${DateUtilsX.minutesToTime(e.value, use24h: widget.use24h)}',
                  selected: _minutes == e.value,
                  activeColor: ff.primary,
                  onTap: () => _quick(e.value),
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.lg),
          FFCard(
            padding: const EdgeInsetsDirectional.symmetric(
              vertical: AppSpacing.sm,
            ),
            child: SizedBox(
              height: TaskSizes.timePickerHeight,
              child: CupertinoTheme(
                data: CupertinoThemeData(
                  brightness: ff.isDark ? Brightness.dark : Brightness.light,
                  primaryColor: ff.primary,
                  textTheme: CupertinoTextThemeData(
                    dateTimePickerTextStyle: context.text.title.copyWith(
                      color: ff.ink,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                child: CupertinoDatePicker(
                  key: ValueKey(_wheelKey),
                  mode: CupertinoDatePickerMode.time,
                  use24hFormat: widget.use24h,
                  minuteInterval: 1,
                  initialDateTime: DateUtilsX.atMinutes(
                    DateTime(2000),
                    _minutes,
                  ),
                  onDateTimeChanged: (t) =>
                      setState(() => _minutes = t.hour * 60 + t.minute),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
