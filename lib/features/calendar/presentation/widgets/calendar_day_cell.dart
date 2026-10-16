/// ============================================================
/// CALENDAR DAY CELL — one day of the month grid / week row (screen 26)
/// ============================================================
///
/// What: the day number (today = filled accent circle, selected = soft
/// accent circle, other-month days faint) over up to 3 module dots.
/// Tap selects, long-press opens Quick Add for that day; in Week view the
/// cell is also a drop target for dragged agenda rows (reschedule).
/// Why: one widget so Month and Week views look and behave the same.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/features/calendar/domain/entities/calendar_entry.dart';
import 'package:focusflow/features/calendar/presentation/calendar_tokens.dart';
import 'package:intl/intl.dart';

class CalendarDayCell extends StatelessWidget {
  const CalendarDayCell({
    required this.day,
    required this.dots,
    required this.isToday,
    required this.isSelected,
    required this.onTap,
    required this.onLongPress,
    this.isOutside = false,
    this.onDrop,
    super.key,
  });

  final DateTime day;

  /// Module dots in legend order (≤ 3).
  final List<ItemType> dots;
  final bool isToday;
  final bool isSelected;

  /// Day of the previous / next month shown to fill the grid.
  final bool isOutside;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  /// Week view: an agenda row was dropped on this day.
  final ValueChanged<CalendarEntry>? onDrop;

  @override
  Widget build(BuildContext context) {
    final drop = onDrop;
    if (drop == null) return _cell(context, hovering: false);
    return DragTarget<CalendarEntry>(
      onWillAcceptWithDetails: (d) => d.data.canReschedule,
      onAcceptWithDetails: (d) => drop(d.data),
      builder: (context, candidates, _) =>
          _cell(context, hovering: candidates.isNotEmpty),
    );
  }

  Widget _cell(BuildContext context, {required bool hovering}) {
    final ff = context.ff;
    final Color? fill;
    final Color numberColor;
    if (isToday) {
      fill = ff.primary;
      numberColor = ff.onPrimary;
    } else if (isSelected || hovering) {
      fill = ff.primarySoft;
      numberColor = ff.primaryStrong;
    } else {
      fill = null;
      numberColor = isOutside ? ff.inkFaint : ff.ink;
    }
    final base = context.text.navTitle;
    final numberStyle = base.copyWith(
      fontSize: CalendarDimens.dayNumber,
      fontWeight: isOutside ? FontWeight.w400 : FontWeight.w700,
      color: numberColor,
      height: 1,
    );
    final label = StringBuffer(DateFormat('EEEE, MMMM d').format(day));
    if (isToday) label.write(', today');
    if (dots.isNotEmpty) {
      label.write(', ${dots.map((t) => t.plural.toLowerCase()).join(', ')}');
    }

    return Semantics(
      button: true,
      selected: isSelected,
      label: label.toString(),
      hint: 'Long press to add on this day',
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        onLongPress: onLongPress,
        child: SizedBox(
          height: CalendarDimens.rowHeight,
          child: Column(
            children: [
              SizedBox(
                height: CalendarDimens.dayCircleBox,
                child: Center(
                  child: Container(
                    width: CalendarDimens.dayCircle,
                    height: CalendarDimens.dayCircle,
                    alignment: Alignment.center,
                    decoration: fill == null
                        ? null
                        : BoxDecoration(color: fill, shape: BoxShape.circle),
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text('${day.day}', style: numberStyle),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: CalendarDimens.dotsTop),
              _Dots(types: dots, dimmed: isOutside),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dots extends StatelessWidget {
  const _Dots({required this.types, required this.dimmed});

  final List<ItemType> types;
  final bool dimmed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: CalendarDimens.dot,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          for (var i = 0; i < types.length; i++) ...[
            if (i > 0) const SizedBox(width: CalendarDimens.dotGap),
            Container(
              width: CalendarDimens.dot,
              height: CalendarDimens.dot,
              decoration: BoxDecoration(
                color: types[i].style.solid.withValues(alpha: dimmed ? 0.4 : 1),
                shape: BoxShape.circle,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// "● Tasks  ● Reminders  ● Habits  ● Notes" under the grid.
class CalendarLegend extends StatelessWidget {
  const CalendarLegend({required this.types, super.key});

  final List<ItemType> types;

  @override
  Widget build(BuildContext context) {
    final style = context.text.meta.copyWith(fontSize: 13);
    return Wrap(
      alignment: WrapAlignment.center,
      spacing: CalendarDimens.legendItemGap,
      runSpacing: AppSpacing.xs,
      children: [
        for (final t in types)
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: CalendarDimens.legendDot,
                height: CalendarDimens.legendDot,
                decoration: BoxDecoration(
                  color: t.style.solid,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: CalendarDimens.legendDotGap),
              Text(t.plural, style: style),
            ],
          ),
      ],
    );
  }
}
