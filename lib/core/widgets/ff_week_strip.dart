/// ============================================================
/// FF WEEK STRIP — day picker (home "June 2023" pills, reminders circles)
/// ============================================================
///
/// * pill   — horizontally scrolling "glass calendar" day tiles
///            (FFCalendarDayTile): little desk calendars with binder rings;
///            the selected day is the vivid accent calendar with a frosted
///            panel, the others are light paper calendars; a dot under days
///            that have items (screen 03).
/// * circle — 7 equal columns: "T" over "13"; selected day sits in a
///            filled accent circle; today's letter in the accent (screen 12,
///            orange). Wrap it in an [FFCard] like the mockup.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/widgets/ff_pressable.dart';
import 'package:focusflow/core/widgets/src/ff_calendar_day_tile.dart';
import 'package:focusflow/core/widgets/src/ff_token_gaps.dart';
import 'package:intl/intl.dart';

enum FFWeekStripStyle { pill, circle }

class FFWeekStrip extends StatefulWidget {
  const FFWeekStrip({
    required this.days,
    required this.selected,
    required this.onSelected,
    this.hasItems,
    this.accent,
    this.dotColor,
    this.style = FFWeekStripStyle.pill,
    this.today,
    this.padding = const EdgeInsetsDirectional.symmetric(
      horizontal: AppSpacing.screen,
    ),
    super.key,
  });

  final List<DateTime> days;
  final DateTime selected;
  final ValueChanged<DateTime> onSelected;

  /// Draws the dot under a day.
  final bool Function(DateTime day)? hasItems;

  /// Selected fill (defaults to primary; Reminders pass orange).
  final Color? accent;

  /// Item-dot colour (defaults to [accent] @70%).
  final Color? dotColor;
  final FFWeekStripStyle style;

  /// Defaults to `DateTime.now()`.
  final DateTime? today;

  /// Pill style: scroll padding. Circle style: outer padding.
  final EdgeInsetsGeometry padding;

  @override
  State<FFWeekStrip> createState() => _FFWeekStripState();
}

class _FFWeekStripState extends State<FFWeekStrip> {
  static const double _pillWidth = FFCalendarDayTile.width;
  static const double _pillGap = 10;
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _reveal());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _reveal() {
    if (!mounted || !_scroll.hasClients) return;
    final i = widget.days.indexWhere(
      (d) => DateUtils.isSameDay(d, widget.selected),
    );
    if (i < 0) return;
    // One full pill (plus its gap) stays visible before the selected day.
    final target = ((i - 1) * (_pillWidth + _pillGap)).clamp(
      0.0,
      _scroll.position.maxScrollExtent,
    );
    _scroll.jumpTo(target);
  }

  String _semantic(DateTime d, bool items) {
    final label = DateFormat('EEEE, MMMM d').format(d);
    return items ? '$label, has items' : label;
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final accent = widget.accent ?? ff.primary;
    final dot = widget.dotColor ?? accent.withValues(alpha: 0.7);
    final today = widget.today ?? DateTime.now();
    if (widget.style == FFWeekStripStyle.circle) {
      return Padding(
        padding: widget.padding,
        child: Row(
          children: [
            for (final d in widget.days)
              Expanded(child: _circleDay(context, d, accent, dot, today)),
          ],
        ),
      );
    }
    return SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      padding: widget.padding.add(
        const EdgeInsetsDirectional.only(top: 4, bottom: AppSpacing.md),
      ),
      child: Row(
        children: [
          for (var i = 0; i < widget.days.length; i++) ...[
            if (i > 0) const SizedBox(width: _pillGap),
            _pillDay(context, widget.days[i], accent, dot, today),
          ],
        ],
      ),
    );
  }

  Widget _pillDay(
    BuildContext context,
    DateTime d,
    Color accent,
    Color dot,
    DateTime today,
  ) {
    final selected = DateUtils.isSameDay(d, widget.selected);
    final items = widget.hasItems?.call(d) ?? false;
    return Semantics(
      button: true,
      selected: selected,
      label: _semantic(d, items),
      excludeSemantics: true,
      child: FFPressable(
        onTap: () => widget.onSelected(d),
        scale: 0.94,
        child: FFCalendarDayTile(
          day: d,
          selected: selected,
          isToday: DateUtils.isSameDay(d, today),
          accent: accent,
          dotColor: items ? dot : null,
        ),
      ),
    );
  }

  Widget _circleDay(
    BuildContext context,
    DateTime d,
    Color accent,
    Color dot,
    DateTime today,
  ) {
    final ff = context.ff;
    final selected = DateUtils.isSameDay(d, widget.selected);
    final isToday = DateUtils.isSameDay(d, today);
    final items = widget.hasItems?.call(d) ?? false;
    return Semantics(
      button: true,
      selected: selected,
      label: _semantic(d, items),
      excludeSemantics: true,
      child: FFPressable(
        onTap: () => widget.onSelected(d),
        scale: 0.95,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                DateFormat.E().format(d).substring(0, 1),
                maxLines: 1,
                softWrap: false,
                overflow: TextOverflow.clip,
                style: context.text.meta.copyWith(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: isToday || selected ? accent : ff.inkFaint,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              AnimatedContainer(
                duration: context.motion(AppMotion.fast),
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: selected ? accent : null,
                  shape: BoxShape.circle,
                  boxShadow: selected
                      ? [
                          BoxShadow(
                            offset: const Offset(0, 8),
                            blurRadius: 16,
                            spreadRadius: -6,
                            color: accent.withValues(alpha: 0.6),
                          ),
                        ]
                      : null,
                ),
                child: Text(
                  '${d.day}',
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.clip,
                  style: context.text.stat.copyWith(
                    fontSize: 17,
                    color: selected ? ff.onGradient : ff.ink,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              _Dot(color: items ? dot : null),
            ],
          ),
        ),
      ),
    );
  }
}

class _Dot extends StatelessWidget {
  const _Dot({this.color});

  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 5,
      height: 5,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
