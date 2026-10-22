/// ============================================================
/// CALENDAR GRID CARD — month grid / week row + legend (screen 26)
/// ============================================================
///
/// What: the white card with the weekday header (in Settings' week-start
/// order), the day cells with module dots, and the legend row.
///   • [CalendarMonthCard] — 4–6 week rows; swipe left / right for the
///     next / previous month (mirrored in RTL), animated unless reduce
///     motion is on. Screen readers get "Next / Previous month" actions.
///   • [CalendarWeekCard] — the selected day's week; swipe changes week,
///     and every cell is a drop target for dragged task rows.
/// Why: both views share the card, header, swipe and cell look, so they
/// live together; data comes in as plain values (no providers here).
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:focusflow/core/items/item_type.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/calendar/domain/entities/calendar_entry.dart';
import 'package:focusflow/features/calendar/domain/services/calendar_rules.dart';
import 'package:focusflow/features/calendar/presentation/calendar_tokens.dart';
import 'package:focusflow/features/calendar/presentation/widgets/calendar_day_cell.dart';
import 'package:intl/intl.dart' show DateFormat;

/// Day callbacks shared by both cards.
typedef CalendarDayCallback = void Function(DateTime day);

/// Month view card.
class CalendarMonthCard extends StatefulWidget {
  const CalendarMonthCard({
    required this.month,
    required this.weekStart,
    required this.today,
    required this.selectedDay,
    required this.dots,
    required this.onSelect,
    required this.onLongPress,
    required this.onShift,
    super.key,
  });

  /// First of the visible month.
  final DateTime month;
  final int weekStart;
  final DateTime today;
  final DateTime selectedDay;

  /// Day key → module dots (empty while loading).
  final Map<String, List<ItemType>> dots;
  final CalendarDayCallback onSelect;
  final CalendarDayCallback onLongPress;

  /// ±1 month.
  final ValueChanged<int> onShift;

  @override
  State<CalendarMonthCard> createState() => _CalendarMonthCardState();
}

class _CalendarMonthCardState extends State<CalendarMonthCard> {
  /// +1 when the last change went forward in time (slide in from the end).
  int _direction = 1;

  @override
  void didUpdateWidget(CalendarMonthCard old) {
    super.didUpdateWidget(old);
    if (old.month != widget.month) {
      _direction = widget.month.isAfter(old.month) ? 1 : -1;
    }
  }

  @override
  Widget build(BuildContext context) {
    final grid = CalendarRules.monthGrid(widget.month, widget.weekStart);
    final key = ValueKey(widget.month);
    // Its own layer: the month swipe fades and slides this subtree, and
    // without a boundary every frame of that animation repaints all 42 cells
    // (numbers, dots, semantics) instead of moving one cached picture.
    final rows = RepaintBoundary(
      key: key,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < grid.length; r += 7)
            Row(
              children: [
                for (final day in grid.sublist(r, r + 7))
                  Expanded(child: _cell(day)),
              ],
            ),
        ],
      ),
    );
    return _GridCard(
      weekStart: widget.weekStart,
      child: _Swipe(
        monthly: true,
        onShift: widget.onShift,
        child: AnimatedSwitcher(
          duration: context.motion(AppMotion.normal),
          switchInCurve: AppMotion.curve,
          switchOutCurve: AppMotion.curve,
          transitionBuilder: (child, animation) {
            final incoming = child.key == key;
            final dx = (incoming ? 1 : -1) * _direction * 0.12;
            return FadeTransition(
              opacity: animation,
              child: SlideTransition(
                textDirection: Directionality.of(context),
                position: Tween(
                  begin: Offset(dx, 0),
                  end: Offset.zero,
                ).animate(animation),
                child: child,
              ),
            );
          },
          layoutBuilder: (current, previous) => Stack(
            alignment: AlignmentDirectional.topCenter,
            children: [...previous, ?current],
          ),
          child: rows,
        ),
      ),
    );
  }

  Widget _cell(DateTime day) => CalendarDayCell(
    day: day,
    dots: widget.dots[DateUtilsX.dayKey(day)] ?? const [],
    isToday: DateUtilsX.isSameDay(day, widget.today),
    isSelected: DateUtilsX.isSameDay(day, widget.selectedDay),
    isOutside: day.month != widget.month.month,
    onTap: () => widget.onSelect(day),
    onLongPress: () => widget.onLongPress(day),
  );
}

/// Week view card: one row of 7 drop-target cells.
class CalendarWeekCard extends StatelessWidget {
  const CalendarWeekCard({
    required this.days,
    required this.weekStart,
    required this.today,
    required this.selectedDay,
    required this.dots,
    required this.onSelect,
    required this.onLongPress,
    required this.onShift,
    required this.onDrop,
    super.key,
  });

  /// The 7 days of the selected week.
  final List<DateTime> days;
  final int weekStart;
  final DateTime today;
  final DateTime selectedDay;
  final Map<String, List<ItemType>> dots;
  final CalendarDayCallback onSelect;
  final CalendarDayCallback onLongPress;

  /// ±1 week.
  final ValueChanged<int> onShift;

  /// A task row was dropped on a day.
  final void Function(CalendarEntry entry, DateTime day) onDrop;

  @override
  Widget build(BuildContext context) {
    return _GridCard(
      weekStart: weekStart,
      child: _Swipe(
        monthly: false,
        onShift: onShift,
        child: Row(
          children: [
            for (final day in days)
              Expanded(
                child: CalendarDayCell(
                  day: day,
                  dots: dots[DateUtilsX.dayKey(day)] ?? const [],
                  isToday: DateUtilsX.isSameDay(day, today),
                  isSelected: DateUtilsX.isSameDay(day, selectedDay),
                  onTap: () => onSelect(day),
                  onLongPress: () => onLongPress(day),
                  onDrop: (entry) => onDrop(entry, day),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// The card frame: weekday header, [child], divider and legend.
class _GridCard extends StatelessWidget {
  const _GridCard({required this.weekStart, required this.child});

  final int weekStart;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    return FFCard(
      padding: const EdgeInsetsDirectional.fromSTEB(
        CalendarDimens.gridPaddingH,
        CalendarDimens.gridPaddingTop,
        CalendarDimens.gridPaddingH,
        CalendarDimens.gridPaddingBottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _WeekdayRow(weekStart: weekStart),
          const SizedBox(height: CalendarDimens.weekdayGap),
          child,
          const SizedBox(height: AppSpacing.sm),
          Padding(
            padding: const EdgeInsetsDirectional.symmetric(
              horizontal: AppSpacing.md,
            ),
            child: Divider(height: 1, thickness: 1, color: ff.divider),
          ),
          const SizedBox(height: CalendarDimens.legendGapTop),
          const CalendarLegend(types: CalendarRules.modules),
        ],
      ),
    );
  }
}

/// "SUN MON TUE …" in Settings' week-start order.
class _WeekdayRow extends StatelessWidget {
  const _WeekdayRow({required this.weekStart});

  final int weekStart;

  @override
  Widget build(BuildContext context) {
    final style = context.text.sectionLabel.copyWith(
      fontSize: 12,
      letterSpacing: CalendarDimens.weekdayLetterSpacing,
      color: context.ff.inkMuted.withValues(alpha: 0.7),
    );
    // 1 Jan 2024 was a Monday, so day n of that month has weekday n.
    final format = DateFormat.E();
    return ExcludeSemantics(
      child: Row(
        children: [
          for (final weekday in CalendarRules.weekdayColumns(weekStart))
            Expanded(
              child: Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    format.format(DateTime(2024, 1, weekday)).toUpperCase(),
                    maxLines: 1,
                    style: style,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Horizontal swipe → previous / next month ([monthly]) or week; mirrored in RTL so the
/// content always follows the finger. Exposes the same moves as
/// semantics actions.
class _Swipe extends StatelessWidget {
  const _Swipe({
    required this.monthly,
    required this.onShift,
    required this.child,
  });

  final bool monthly;
  final ValueChanged<int> onShift;
  final Widget child;

  static const double _minVelocity = 200;

  @override
  Widget build(BuildContext context) {
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Semantics(
      customSemanticsActions: {
        CustomSemanticsAction(
          label: monthly ? tr('Next month') : tr('Next week'),
        ): () =>
            onShift(1),
        CustomSemanticsAction(
          label: monthly ? tr('Previous month') : tr('Previous week'),
        ): () =>
            onShift(-1),
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragEnd: (details) {
          final v = details.primaryVelocity ?? 0;
          if (v.abs() < _minVelocity) return;
          // Finger moving towards the start (left in LTR) → forward.
          final forward = rtl ? v > 0 : v < 0;
          onShift(forward ? 1 : -1);
        },
        child: child,
      ),
    );
  }
}
