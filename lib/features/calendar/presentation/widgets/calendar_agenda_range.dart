/// ============================================================
/// CALENDAR AGENDA RANGE — the Agenda view: 7 days grouped (screen 26)
/// ============================================================
///
/// What: "‹  Jun 13 – Jun 19  ›" then one [CalendarDayAgenda] group per
/// day, starting on the selected day. The chevrons move a week.
/// Why: a scrollable look-ahead without the grid; every group is live
/// over its own day provider, so edits anywhere update it.
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/calendar/presentation/calendar_tokens.dart';
import 'package:focusflow/features/calendar/presentation/widgets/calendar_day_agenda.dart';

class CalendarAgendaRange extends StatelessWidget {
  const CalendarAgendaRange({
    required this.start,
    required this.onShift,
    super.key,
  });

  /// First listed day (the selected day).
  final DateTime start;

  /// ±1 week.
  final ValueChanged<int> onShift;

  @override
  Widget build(BuildContext context) {
    final days = [
      for (var i = 0; i < CalendarDimens.agendaDays; i++)
        DateUtilsX.addDays(start, i),
    ];
    final fmt = DateFormats.of('MMM d');
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            FFRoundIconButton(
              icon: rtl
                  ? FontAwesomeIcons.chevronRight
                  : FontAwesomeIcons.chevronLeft,
              semanticLabel: 'Previous week',
              onPressed: () => onShift(-1),
            ),
            Expanded(
              child: Text(
                '${fmt.format(days.first)} – ${fmt.format(days.last)}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                textAlign: TextAlign.center,
                style: context.text.navTitle,
              ),
            ),
            FFRoundIconButton(
              icon: rtl
                  ? FontAwesomeIcons.chevronLeft
                  : FontAwesomeIcons.chevronRight,
              semanticLabel: 'Next week',
              onPressed: () => onShift(1),
            ),
          ],
        ),
        for (final day in days) ...[
          const SizedBox(height: CalendarDimens.sectionGap),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.xs,
            ),
            child: CalendarDayAgenda(
              key: ValueKey(DateUtilsX.dayKey(day)),
              day: day,
              dense: true,
            ),
          ),
        ],
      ],
    );
  }
}
