/// ============================================================
/// PRAYER CALENDAR SECTION — repeat by weekday or by a religious calendar
/// ============================================================
///
/// What: the editor's "Days" block. By default seven weekday chips; the
/// "Repeats on" row opens a sheet with the tradition's calendar rules
/// (Ramadan, Ekadashi, Lent, Hebrew fasts, Uposatha …) next to "Days of the
/// week". With a rule set, the chips give way to the next three dates, a
/// "approximate — confirm locally" note for moon-based rules and a one-day
/// nudge (earlier / as calculated / later) for the person's own almanac.
/// Why: a Ramadan fast or an Ekadashi does not repeat on weekdays, and the
/// moon-based days differ by a day between regions and almanacs — the
/// preview shows the dates so a wrong day is seen before it is saved.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/prayers/domain/entities/calendar_rule.dart';
import 'package:focusflow/features/prayers/domain/entities/prayer.dart';
import 'package:focusflow/features/prayers/domain/services/calendar_rules.dart';
import 'package:focusflow/features/prayers/presentation/prayer_style.dart';
import 'package:focusflow/features/tasks/presentation/widgets/pickers/picker_common.dart';

class PrayerCalendarSection extends StatelessWidget {
  const PrayerCalendarSection({
    required this.draft,
    required this.onChanged,
    required this.now,
    this.hijriAdjust = 0,
    super.key,
  });

  final Prayer draft;
  final ValueChanged<Prayer> onChanged;
  final DateTime now;
  final int hijriAdjust;

  /// The value of the "Days of the week" option in the sheet.
  static const String _weekdays = '';

  Future<void> _pick(BuildContext context) async {
    final rules = CalendarRules.choices(draft.tradition);
    final current = draft.calendar;
    final picked = await showOptionSheet<String>(
      context,
      title: tr('Repeats on'),
      options: [
        OptionItem(
          value: _weekdays,
          label: tr('Days of the week'),
          icon: FontAwesomeIcons.calendarWeek,
          colors: PrayerStyle.module,
        ),
        for (final r in rules)
          OptionItem(
            value: r.key,
            label: CalendarRules.describe(r),
            icon: FontAwesomeIcons.moon,
            colors: PrayerStyle.module,
          ),
        // A rule saved earlier that this tradition no longer lists.
        if (current != null && !rules.any((r) => r.key == current.key))
          OptionItem(
            value: current.key,
            label: CalendarRules.describe(current),
            icon: FontAwesomeIcons.moon,
            colors: PrayerStyle.module,
          ),
      ],
      selected: current?.key ?? _weekdays,
      accent: PrayerStyle.module.solid,
    );
    if (picked == null) return;
    if (picked.value == _weekdays) {
      onChanged(draft.copyWith(clearCalendar: true));
    } else if (picked.value != current?.key) {
      onChanged(draft.copyWith(calendar: CalendarRule(picked.value)));
    }
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final rule = draft.calendar;
    final days = [
      tr('Mon'),
      tr('Tue'),
      tr('Wed'),
      tr('Thu'),
      tr('Fri'),
      tr('Sat'),
      tr('Sun'),
    ];
    final fmt = DateFormats.of('EEE d MMM');
    final next = rule == null
        ? const <DateTime>[]
        : CalendarRules.nextDates(rule, now, hijriAdjust: hijriAdjust);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FFSectionLabel(tr('Days')),
        const SizedBox(height: AppSpacing.sm),
        if (rule == null) ...[
          Wrap(
            spacing: AppSpacing.xs,
            runSpacing: AppSpacing.xs,
            children: [
              for (var i = 0; i < 7; i++)
                FFChip(
                  label: days[i],
                  selected: draft.weekdaysMask & (1 << i) != 0,
                  onTap: () {
                    final mask = draft.weekdaysMask ^ (1 << i);
                    // At least one day stays on.
                    if (mask & 0x7F != 0) {
                      onChanged(draft.copyWith(weekdaysMask: mask));
                    }
                  },
                ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        FFGroupedList(
          children: [
            FFListRow(
              leading: FFIconTile.soft(
                icon: FontAwesomeIcons.moon,
                colors: PrayerStyle.module,
                size: AppSizes.iconTileSm,
              ),
              title: tr('Repeats on'),
              value: rule == null
                  ? tr('Days of the week')
                  : CalendarRules.describe(rule),
              chevron: true,
              onTap: () => _pick(context),
            ),
          ],
        ),
        if (rule != null) ...[
          const SizedBox(height: AppSpacing.sm),
          Text(
            next.isEmpty
                ? tr('No date in the next two years.')
                : tr('Next: {dates}', {
                    'dates': next.map(fmt.format).join(' · '),
                  }),
            style: text.meta.copyWith(
              color: ff.inkMuted,
              fontWeight: FontWeight.w400,
            ),
          ),
          if (rule.approximate) ...[
            const SizedBox(height: AppSpacing.xs),
            Text(
              tr(
                'Approximate — moon-based days differ by a day between '
                'places. Confirm with your local calendar and nudge it here.',
              ),
              style: text.meta.copyWith(
                color: ff.inkMuted,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FFSegmented<int>(
              segments: [
                FFSegment(value: -1, label: tr('A day earlier')),
                FFSegment(value: 0, label: tr('As calculated')),
                FFSegment(value: 1, label: tr('A day later')),
              ],
              value: rule.shift,
              onChanged: (s) =>
                  onChanged(draft.copyWith(calendar: rule.withShift(s))),
              height: 40,
            ),
          ],
        ],
      ],
    );
  }
}
