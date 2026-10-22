/// ============================================================
/// REMINDER TIME WHEEL — the inline iOS-style time picker of screen 13
/// ============================================================
///
/// What: a card with hour · minute (5-minute steps) · AM/PM wheels (hour ·
/// minute in 24 h mode) over an orange highlight band. The centred row is
/// bold orange; rows fade and shrink with their distance from the centre.
/// Reports minutes after midnight on every settled change.
/// Why: the mockup shows a flat wheel with its own band and type scale —
/// CupertinoDatePicker can't be styled that way. Each column exposes
/// increase / decrease semantics actions for screen readers.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/module_style.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/reminders/presentation/reminder_tokens.dart';

class ReminderTimeWheel extends StatefulWidget {
  const ReminderTimeWheel({
    required this.minutes,
    required this.onChanged,
    this.use24h = false,
    super.key,
  });

  /// Initial time (minutes after midnight); read once.
  final int minutes;
  final ValueChanged<int> onChanged;
  final bool use24h;

  /// Row pitch and visible rows (mockup: 42 pt, five rows).
  static const double itemExtent = 42;
  static const int visibleRows = 5;

  /// Highlight band height and inset from the card edge.
  static const double bandHeight = 43;
  static const double bandInset = AppSpacing.lg;

  @override
  State<ReminderTimeWheel> createState() => _ReminderTimeWheelState();
}

class _ReminderTimeWheelState extends State<ReminderTimeWheel> {
  late int _hour = widget.minutes ~/ 60;
  late int _minute = widget.minutes % 60;

  /// 5-minute steps unless the stored minute is off-grid (then 1 minute).
  late final int _step = _minute % 5 == 0 ? 5 : 1;

  void _emit() => widget.onChanged(_hour * 60 + _minute);

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final band = Color.lerp(
      ModuleStyle.reminders.colors.softFor(Theme.of(context).brightness),
      ff.surface,
      ff.isDark ? 0.2 : 0.55,
    )!;
    final minuteItems = [
      for (var m = 0; m < 60; m += _step) m.toString().padLeft(2, '0'),
    ];
    final hourItems = widget.use24h
        ? [for (var h = 0; h < 24; h++) h.toString().padLeft(2, '0')]
        : [for (var h = 1; h <= 12; h++) h.toString().padLeft(2, '0')];
    final h12 = _hour % 12 == 0 ? 12 : _hour % 12;
    final pm = _hour >= 12;
    const height = ReminderTimeWheel.itemExtent * ReminderTimeWheel.visibleRows;
    return FFCard(
      padding: const EdgeInsetsDirectional.symmetric(
        vertical: ReminderSizes.wheelVertical,
      ),
      child: SizedBox(
        height: height,
        child: Stack(
          alignment: Alignment.center,
          children: [
            PositionedDirectional(
              start: ReminderTimeWheel.bandInset,
              end: ReminderTimeWheel.bandInset,
              top: (height - ReminderTimeWheel.bandHeight) / 2,
              height: ReminderTimeWheel.bandHeight,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  color: band,
                  borderRadius: BorderRadius.circular(AppRadii.tile),
                ),
              ),
            ),
            Row(
              children: [
                Expanded(
                  child: _WheelColumn(
                    label: tr('Hour'),
                    items: hourItems,
                    initial: widget.use24h ? _hour : h12 - 1,
                    looping: true,
                    onSelected: (i) {
                      _hour = widget.use24h
                          ? i
                          : ((i + 1) % 12) + (_hour >= 12 ? 12 : 0);
                      _emit();
                    },
                  ),
                ),
                Expanded(
                  child: _WheelColumn(
                    label: tr('Minute'),
                    items: minuteItems,
                    initial: _minute ~/ _step,
                    looping: true,
                    onSelected: (i) {
                      _minute = i * _step;
                      _emit();
                    },
                  ),
                ),
                if (!widget.use24h)
                  Expanded(
                    child: _WheelColumn(
                      label: tr('AM or PM'),
                      items: [tr('AM'), tr('PM')],
                      initial: pm ? 1 : 0,
                      looping: false,
                      onSelected: (i) {
                        _hour = _hour % 12 + (i == 1 ? 12 : 0);
                        _emit();
                      },
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// One scrolling column. Looping columns use a long finite list centred on
/// the initial item (the builder delegate has no negative indices).
class _WheelColumn extends StatefulWidget {
  const _WheelColumn({
    required this.label,
    required this.items,
    required this.initial,
    required this.looping,
    required this.onSelected,
  });

  final String label;
  final List<String> items;
  final int initial;
  final bool looping;

  /// Index into [items].
  final ValueChanged<int> onSelected;

  @override
  State<_WheelColumn> createState() => _WheelColumnState();
}

class _WheelColumnState extends State<_WheelColumn> {
  static const _loops = 200;

  int get _n => widget.items.length;

  late final FixedExtentScrollController _controller =
      FixedExtentScrollController(
        initialItem: widget.looping
            ? _n * (_loops ~/ 2) + widget.initial
            : widget.initial,
      );

  late int _selected = widget.initial;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _step(int delta) {
    final target = _controller.selectedItem + delta;
    if (!widget.looping && (target < 0 || target >= _n)) return;
    if (context.reduceMotion) {
      _controller.jumpToItem(target);
    } else {
      _controller.animateToItem(
        target,
        duration: AppMotion.fast,
        curve: AppMotion.curve,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final accent = Color.lerp(
      ModuleStyle.reminders.solid,
      ModuleStyle.reminders.colors.inkFor(Theme.of(context).brightness),
      ff.isDark ? 0 : 0.3,
    )!;
    // iOS-wheel depth: rows fade towards the card surface with distance
    // (≈ 100 % in the band, ≈ 75 % one row out, ≈ 20 % at the edges).
    final near = Color.lerp(ff.inkFaint, ff.surface, ff.isDark ? 0.1 : 0.25)!;
    final far = Color.lerp(ff.inkFaint, ff.surface, ff.isDark ? 0.72 : 0.8)!;

    TextStyle styleAt(double d) {
      final color = d <= 1
          ? Color.lerp(accent, near, d)
          : Color.lerp(near, far, (d - 1).clamp(0.0, 1.0));
      return context.text.wheelDigit(d).copyWith(color: color);
    }

    final count = widget.looping ? _n * _loops : _n;
    return Semantics(
      label: widget.label,
      value: widget.items[_selected],
      increasedValue: widget.items[(_selected + 1) % _n],
      decreasedValue: widget.items[(_selected - 1 + _n) % _n],
      onIncrease: () => _step(1),
      onDecrease: () => _step(-1),
      excludeSemantics: true,
      child: ListWheelScrollView.useDelegate(
        controller: _controller,
        itemExtent: ReminderTimeWheel.itemExtent,
        physics: const FixedExtentScrollPhysics(),
        diameterRatio: 40,
        perspective: 0.0001,
        onSelectedItemChanged: (i) {
          final index = i % _n;
          setState(() => _selected = index);
          widget.onSelected(index);
        },
        childDelegate: ListWheelChildBuilderDelegate(
          childCount: count,
          builder: (context, i) => AnimatedBuilder(
            animation: _controller,
            builder: (context, _) {
              final offset = _controller.hasClients
                  ? _controller.offset / ReminderTimeWheel.itemExtent
                  : _controller.initialItem.toDouble();
              final d = (i - offset).abs();
              return Center(
                child: Text(
                  widget.items[i % _n],
                  maxLines: 1,
                  textScaler: TextScaler.linear(
                    MediaQuery.textScalerOf(context).scale(1).clamp(0.85, 1.2),
                  ),
                  style: styleAt(d),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
