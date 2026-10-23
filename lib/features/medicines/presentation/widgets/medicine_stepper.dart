/// ============================================================
/// MEDICINE STEPPER — "−  1 tablet  +" for dose amounts and refills
/// ============================================================
///
/// Two round 44-pt buttons around the value; the value text rolls (slides
/// up for +, down for −) when it changes, and every step ticks a selection
/// haptic. Long-pressing a button repeats is not needed here: amounts are
/// small, and refills start from the last pack size.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_haptics.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/medicines/presentation/medicine_style.dart';

class MedicineStepper extends StatefulWidget {
  const MedicineStepper({
    required this.value,
    required this.onChanged,
    required this.label,
    this.step = 1,
    this.min = 0.5,
    this.max = 99,
    this.compact = false,
    super.key,
  });

  final double value;
  final ValueChanged<double> onChanged;

  /// The value as shown ("1 tablet").
  final String Function(double value) label;
  final double step;
  final double min;
  final double max;

  /// A smaller value text (rows of the editor).
  final bool compact;

  @override
  State<MedicineStepper> createState() => _MedicineStepperState();
}

class _MedicineStepperState extends State<MedicineStepper> {
  /// +1 after an increment, −1 after a decrement (roll direction).
  int _direction = 1;

  void _change(double delta) {
    final next = (widget.value + delta).clamp(widget.min, widget.max);
    if (next == widget.value) return;
    FFHaptics.selection(context);
    setState(() => _direction = delta > 0 ? 1 : -1);
    widget.onChanged(next.toDouble());
  }

  /// Steps of ½ below 1 unit (half a tablet), whole steps above.
  double get _down => widget.value <= 1 ? widget.step / 2 : widget.step;
  double get _up => widget.value < 1 ? widget.step / 2 : widget.step;

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final colors = MedicineStyle.colors;
    final text = widget.compact ? context.text.rowTitle : context.text.title;
    final label = widget.label(widget.value);
    final duration = context.reduceMotion ? Duration.zero : AppMotion.normal;
    Widget button(IconData icon, String semantic, VoidCallback? onTap) =>
        Semantics(
          button: true,
          label: semantic,
          child: FFPressable(
            onTap: onTap,
            child: SizedBox.square(
              dimension: AppSizes.minTap,
              child: Center(
                child: Container(
                  width: MedicineSizes.stepper,
                  height: MedicineSizes.stepper,
                  decoration: BoxDecoration(
                    color: onTap == null
                        ? ff.surfaceMuted
                        : colors.softFor(ff.brightness),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    icon,
                    size: AppSizes.tileGlyph,
                    color: onTap == null
                        ? ff.inkFaint
                        : colors.inkFor(ff.brightness),
                  ),
                ),
              ),
            ),
          ),
        );
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        button(
          FontAwesomeIcons.minus,
          tr('Less'),
          widget.value > widget.min ? () => _change(-_down) : null,
        ),
        Semantics(
          liveRegion: true,
          label: label,
          excludeSemantics: true,
          child: SizedBox(
            width: widget.compact
                ? MedicineSizes.stepperLabelCompact
                : MedicineSizes.stepperLabel,
            child: ClipRect(
              child: AnimatedSwitcher(
                duration: duration,
                transitionBuilder: (child, a) {
                  final incoming = child.key == ValueKey<String>(label);
                  final from = Offset(
                    0,
                    incoming ? 0.6 * _direction : -0.6 * _direction,
                  );
                  return SlideTransition(
                    position: Tween(begin: from, end: Offset.zero).animate(
                      CurvedAnimation(parent: a, curve: AppMotion.curve),
                    ),
                    child: FadeTransition(opacity: a, child: child),
                  );
                },
                child: FittedBox(
                  key: ValueKey(label),
                  fit: BoxFit.scaleDown,
                  child: Text(
                    label,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    style: text.copyWith(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ),
          ),
        ),
        button(
          FontAwesomeIcons.plus,
          tr('More'),
          widget.value < widget.max ? () => _change(_up) : null,
        ),
      ],
    );
  }
}
