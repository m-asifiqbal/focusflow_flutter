/// ============================================================
/// REPEAT CUSTOM PANEL — "Custom" part of the Repeat sheet
/// ============================================================
///
/// What:
///   * [WeekdayToggleRow] — seven round day toggles (week start from
///     settings), used by "Weekly" and "Custom · weeks".
///   * [RepeatCustomPanel] — every N days/weeks/months/years, ends never /
///     on a date / after N times, with a live label preview.
///   * [CountStepper] — − N + stepper with a suffix ("3 weeks").
/// Why: the custom rule editor is big enough to live apart from the sheet;
/// it only edits a [RepeatDraft] and reports changes upward.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/utils/recurrence.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/repeat_draft.dart';
import 'package:focusflow/features/tasks/presentation/task_tokens.dart';

/// Seven round toggles, ordered from [weekStartsOn] (1 = Monday).
class WeekdayToggleRow extends StatelessWidget {
  const WeekdayToggleRow({
    required this.selected,
    required this.onToggle,
    this.weekStartsOn = DateTime.monday,
    super.key,
  });

  final Set<int> selected;
  final ValueChanged<int> onToggle;
  final int weekStartsOn;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final days = [for (var i = 0; i < 7; i++) (weekStartsOn - 1 + i) % 7 + 1];
    // 2024-01-01 was a Monday: weekday w → Jan w.
    String name(int w, String pattern) =>
        DateFormats.of(pattern).format(DateTime(2024, 1, w));
    return Row(
      children: [
        for (final w in days)
          Expanded(
            child: Semantics(
              button: true,
              selected: selected.contains(w),
              label: name(w, 'EEEE'),
              onTap: () => onToggle(w),
              child: ExcludeSemantics(
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () => onToggle(w),
                  child: SizedBox(
                    height: AppSizes.minTap,
                    child: Center(
                      child: AnimatedContainer(
                        duration: context.reduceMotion
                            ? Duration.zero
                            : AppMotion.fast,
                        width: TaskSizes.weekdayToggle,
                        height: TaskSizes.weekdayToggle,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: selected.contains(w)
                              ? ff.primary
                              : ff.surfaceMuted,
                        ),
                        child: Text(
                          name(w, 'E').substring(0, 2),
                          maxLines: 1,
                          style: context.text.weekdayToggle.copyWith(
                            color: selected.contains(w)
                                ? ff.onPrimary
                                : ff.inkMuted,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// `−  3 weeks  +`.
class CountStepper extends StatelessWidget {
  const CountStepper({
    required this.value,
    required this.label,
    required this.onChanged,
    this.min = 1,
    this.max = 999,
    super.key,
  });

  final int value;

  /// Text shown between the buttons ("3 weeks").
  final String label;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        FFRoundIconButton(
          icon: FontAwesomeIcons.minus,
          semanticLabel: tr('Decrease'),
          onPressed: value > min ? () => onChanged(value - 1) : null,
        ),
        Expanded(
          child: Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.rowTitle.copyWith(fontWeight: FontWeight.w700),
          ),
        ),
        FFRoundIconButton(
          icon: FontAwesomeIcons.plus,
          semanticLabel: tr('Increase'),
          onPressed: value < max ? () => onChanged(value + 1) : null,
        ),
      ],
    );
  }
}

/// Custom rule editor for [draft]; every change goes to [onChanged].
class RepeatCustomPanel extends StatefulWidget {
  const RepeatCustomPanel({
    required this.draft,
    required this.start,
    required this.onChanged,
    this.weekStartsOn = DateTime.monday,
    super.key,
  });

  final RepeatDraft draft;

  /// The task's day (label preview, earliest end date).
  final DateTime start;
  final ValueChanged<RepeatDraft> onChanged;
  final int weekStartsOn;

  @override
  State<RepeatCustomPanel> createState() => _RepeatCustomPanelState();
}

class _RepeatCustomPanelState extends State<RepeatCustomPanel> {
  bool _calendar = false;

  static const _units = [
    RecurrenceFrequency.daily,
    RecurrenceFrequency.weekly,
    RecurrenceFrequency.monthly,
    RecurrenceFrequency.yearly,
  ];

  /// Segment text of a unit (plural noun).
  static String _unitName(RecurrenceFrequency f) => switch (f) {
    RecurrenceFrequency.daily => tr('Days'),
    RecurrenceFrequency.weekly => tr('Weeks'),
    RecurrenceFrequency.monthly => tr('Months'),
    RecurrenceFrequency.yearly => tr('Years'),
  };

  /// Stepper text: "Every day" / "Every 2 weeks" (one key per unit so each
  /// language can inflect the noun).
  static String _everyLabel(RecurrenceFrequency f, int n) => switch (f) {
    RecurrenceFrequency.daily => tr(
      '{count, plural, one {Every day} other {Every # days}}',
      {'count': n},
    ),
    RecurrenceFrequency.weekly => tr(
      '{count, plural, one {Every week} other {Every # weeks}}',
      {'count': n},
    ),
    RecurrenceFrequency.monthly => tr(
      '{count, plural, one {Every month} other {Every # months}}',
      {'count': n},
    ),
    RecurrenceFrequency.yearly => tr(
      '{count, plural, one {Every year} other {Every # years}}',
      {'count': n},
    ),
  };

  @override
  Widget build(BuildContext context) {
    final d = widget.draft;
    void set(RepeatDraft next) => widget.onChanged(next);
    const gap = SizedBox(height: AppSpacing.md);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        FFSectionLabel(tr('Every')),
        FFSegmented<RecurrenceFrequency>(
          segments: [
            for (final u in _units) FFSegment(value: u, label: _unitName(u)),
          ],
          value: d.unit,
          onChanged: (u) => set(d.copyWith(unit: u)),
        ),
        gap,
        CountStepper(
          value: d.interval,
          label: _everyLabel(d.unit, d.interval),
          onChanged: (n) => set(d.copyWith(interval: n)),
        ),
        if (d.unit == RecurrenceFrequency.weekly) ...[
          gap,
          WeekdayToggleRow(
            selected: d.weekdays,
            weekStartsOn: widget.weekStartsOn,
            onToggle: (w) => set(d.toggleWeekday(w)),
          ),
        ],
        const SizedBox(height: AppSpacing.xl),
        FFSectionLabel(tr('Ends')),
        FFSegmented<RepeatEnd>(
          segments: [
            FFSegment(value: RepeatEnd.never, label: tr('Never')),
            FFSegment(value: RepeatEnd.onDate, label: tr('On date')),
            FFSegment(value: RepeatEnd.after, label: tr('After')),
          ],
          value: d.end,
          onChanged: (e) => set(d.copyWith(end: e)),
        ),
        if (d.end == RepeatEnd.onDate) ...[
          gap,
          FFGroupedList(
            children: [
              FFListRow(
                title: tr('End date'),
                value: DateFormats.of('EEE, MMM d, y').format(d.until),
                valueColor: context.ff.primaryStrong,
                onTap: () => setState(() => _calendar = !_calendar),
              ),
            ],
          ),
          if (_calendar) ...[
            const SizedBox(height: AppSpacing.sm),
            FFCard(
              padding: EdgeInsetsDirectional.zero,
              child: CalendarDatePicker(
                initialDate: d.until.isBefore(widget.start)
                    ? widget.start
                    : d.until,
                firstDate: widget.start,
                lastDate: DateTime(widget.start.year + 20),
                onDateChanged: (day) {
                  setState(() => _calendar = false);
                  set(d.copyWith(until: day));
                },
              ),
            ),
          ],
        ],
        if (d.end == RepeatEnd.after) ...[
          gap,
          CountStepper(
            value: d.count,
            label: tr('{count, plural, one {# time} other {# times}}', {
              'count': d.count,
            }),
            onChanged: (n) => set(d.copyWith(count: n)),
          ),
        ],
      ],
    );
  }
}
