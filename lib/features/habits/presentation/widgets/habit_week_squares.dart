/// ============================================================
/// HABIT WEEK SQUARES — the "M T W T F S S" footer of a habit card
/// ============================================================
///
/// Seven 18-pt squares for the week containing the card's day (week start
/// from settings). Done days are filled with the habit colour and a white
/// letter; skipped days get the soft tint; rest days (not scheduled — off
/// days of a specific-days habit, every-N-days gaps, an N× per week habit
/// after its weekly quota, days before the start date) are an outline only,
/// so they never read as misses; missed and future due days are the muted
/// surface with a faint letter (mockup 14). The letters don't scale with
/// text size — the squares are fixed — so the row carries one spoken
/// summary instead.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_colors.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/domain/entities/habit_frequency.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';

class HabitWeekSquares extends StatelessWidget {
  const HabitWeekSquares({required this.week, required this.colors, super.key});

  final List<HabitDayCell> week;
  final ModuleColors colors;

  /// The look of one cell.
  static HabitSquareKind kindOf(HabitDayCell c) {
    if (c.isDone && !c.isFuture) return HabitSquareKind.done;
    if (c.isSkipped) return HabitSquareKind.skipped;
    if (!c.isScheduled) return HabitSquareKind.rest;
    return HabitSquareKind.open;
  }

  /// "This week: done Mon, Wed, Thu" (or "nothing done yet"), plus
  /// "; rest days Sat, Sun" when the week has any.
  static String semanticsFor(List<HabitDayCell> week) {
    final done = [
      for (final c in week)
        if (kindOf(c) == HabitSquareKind.done)
          HabitFrequency.shortName(c.day.weekday),
    ];
    final rest = [
      for (final c in week)
        if (kindOf(c) == HabitSquareKind.rest)
          HabitFrequency.shortName(c.day.weekday),
    ];
    final base = done.isEmpty
        ? tr('This week: nothing done yet')
        : tr('This week: done {days}', {'days': done.join(', ')});
    return rest.isEmpty
        ? base
        : tr('{base}; rest days {days}', {
            'base': base,
            'days': rest.join(', '),
          });
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final brightness = Theme.of(context).brightness;
    return Semantics(
      label: semanticsFor(week),
      excludeSemantics: true,
      child: MediaQuery.withNoTextScaling(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < week.length; i++) ...[
              if (i > 0) const SizedBox(width: HabitDimens.weekSquareGap),
              _square(ff, brightness, week[i]),
            ],
          ],
        ),
      ),
    );
  }

  Widget _square(FFColors ff, Brightness brightness, HabitDayCell cell) {
    // The narrow weekday of the active language ("M", "周一"…): one letter
    // cannot be a `tr` key — "T" would be both Tuesday and Thursday.
    final letter = DateFormats.of('EEEEE').format(cell.day);
    return switch (kindOf(cell)) {
      HabitSquareKind.done => _Square(
        letter: letter,
        fill: colors.solid,
        ink: HabitAccents.onColor,
      ),
      HabitSquareKind.skipped => _Square(
        letter: letter,
        fill: colors.softFor(brightness),
        ink: colors.inkFor(brightness),
      ),
      HabitSquareKind.rest => _Square(
        letter: letter,
        fill: Colors.transparent,
        border: ff.chipBorder,
        ink: ff.inkFaint,
      ),
      HabitSquareKind.open => _Square(
        letter: letter,
        fill: ff.surfaceMuted,
        ink: ff.inkFaint,
      ),
    };
  }
}

/// How a week square is drawn.
enum HabitSquareKind {
  /// Done (build) / clean (quit): habit colour.
  done,

  /// Deliberately skipped: soft tint.
  skipped,

  /// Not scheduled: outline only.
  rest,

  /// Due — missed, in progress or still to come: muted surface.
  open,
}

class _Square extends StatelessWidget {
  const _Square({
    required this.letter,
    required this.fill,
    required this.ink,
    this.border,
  });

  final String letter;
  final Color fill;
  final Color ink;

  /// Outline (rest days); null = none.
  final Color? border;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: HabitDimens.weekSquare,
      height: HabitDimens.weekSquare,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: fill,
        border: border == null ? null : Border.all(color: border!),
        borderRadius: BorderRadius.circular(HabitDimens.weekSquareRadius),
      ),
      child: Text(
        letter,
        style: context.text.tag.copyWith(
          fontSize: HabitDimens.weekLetter,
          letterSpacing: 0,
          height: 1,
          color: ink,
        ),
      ),
    );
  }
}
