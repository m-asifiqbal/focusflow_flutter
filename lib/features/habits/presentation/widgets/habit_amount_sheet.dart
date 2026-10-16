/// ============================================================
/// HABIT AMOUNT SHEET — long-press on a card's "+" (screen 14)
/// ============================================================
///
/// "Long-press + → enter custom amount / skip today." A stepper sets
/// today's count exactly (check-ins, or slips for a quit habit); "Skip
/// today" marks a rest day that never breaks the streak; "Clear today"
/// removes the day's log. Writes go through HabitLogger. Anything that
/// takes progress away (skip, clear, a lower amount, a new slip) shows the
/// 5 s Undo snackbar on the list underneath, restoring the day's log.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/presentation/habit_style.dart';
import 'package:focusflow/features/habits/presentation/providers/habit_logger_provider.dart';

/// Opens the amount sheet for [status]. The Undo snackbar is shown in
/// [context] (the list), so it outlives the sheet.
Future<void> showHabitAmountSheet(
  BuildContext context,
  HabitDayStatus status,
) => showFFBottomSheet<void>(
  context,
  builder: (_) => HabitAmountSheet(status: status, hostContext: context),
);

class HabitAmountSheet extends ConsumerStatefulWidget {
  const HabitAmountSheet({
    required this.status,
    required this.hostContext,
    super.key,
  });

  final HabitDayStatus status;

  /// Where the Undo snackbar goes once the sheet has closed.
  final BuildContext hostContext;

  @override
  ConsumerState<HabitAmountSheet> createState() => _HabitAmountSheetState();
}

class _HabitAmountSheetState extends ConsumerState<HabitAmountSheet> {
  late int _count = widget.status.count;

  /// Upper bound of the stepper (generous: 10× the goal, at least 99).
  int get _max {
    final goal = widget.status.habit.targetCount * 10;
    return goal < 99 ? 99 : goal;
  }

  /// Closes the sheet, writes, and — when [undo] names the change — offers
  /// Undo back to the day's log as it was.
  Future<void> _run(
    Future<void> Function(HabitLogger l) write, {
    String? undo,
  }) async {
    final logger = ref.read(habitLoggerProvider);
    final status = widget.status;
    final before = status.log;
    Navigator.of(context).pop();
    await write(logger);
    final host = widget.hostContext;
    if (undo == null || !host.mounted) return;
    showUndoSnackbar(
      host,
      message: undo,
      icon: FontAwesomeIcons.rotateLeft,
      onUndo: () => logger.restoreDay(status.habit.id, status.day, before),
    );
  }

  /// Undo message for Save, when the new amount takes progress away.
  String? _saveUndo() {
    final s = widget.status;
    final name = s.habit.name;
    if (s.habit.isQuit) {
      return _count > s.count ? 'Slip logged · "$name" streak reset' : null;
    }
    return _count < s.count ? '"$name" set to $_count ${s.habit.unit}' : null;
  }

  @override
  Widget build(BuildContext context) {
    final ff = context.ff;
    final text = context.text;
    final habit = widget.status.habit;
    final colors = habit.colors;
    final unit = habit.isQuit ? 'slips' : habit.unit;

    Widget stepButton(IconData icon, String label, VoidCallback? onTap) =>
        FFRoundIconButton(
          icon: icon,
          semanticLabel: label,
          onPressed: onTap,
          iconColor: colors.solid,
        );

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          habit.name,
          textAlign: TextAlign.center,
          style: text.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          habit.isQuit
              ? 'Slips logged today'
              : 'Today · goal ${habit.goalLabel}',
          textAlign: TextAlign.center,
          style: text.bodySmall.copyWith(color: ff.inkMuted),
        ),
        const SizedBox(height: AppSpacing.xxl),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            stepButton(
              FontAwesomeIcons.minus,
              'Decrease',
              _count > 0 ? () => setState(() => _count--) : null,
            ),
            const SizedBox(width: AppSpacing.xxl),
            Flexible(
              child: Semantics(
                liveRegion: true,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('$_count', style: text.bigStat),
                    Text(
                      unit,
                      style: text.meta,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.xxl),
            stepButton(
              FontAwesomeIcons.plus,
              'Increase',
              _count < _max ? () => setState(() => _count++) : null,
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.xxl),
        FFPrimaryButton(
          label: 'Save',
          onPressed: () => _run(
            (l) => l.setAmount(widget.status, _count),
            undo: _saveUndo(),
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Row(
          children: [
            Expanded(
              child: FFSecondaryButton(
                label: 'Skip today',
                icon: FontAwesomeIcons.forward,
                onPressed: () => _run(
                  (l) => l.skip(widget.status),
                  undo: 'Skipped today · "${habit.name}"',
                ),
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: FFSecondaryButton(
                label: 'Clear today',
                icon: FontAwesomeIcons.eraser,
                variant: FFSecondaryVariant.outlined,
                onPressed: () => _run(
                  (l) => l.clear(widget.status),
                  undo: widget.status.log == null
                      ? null
                      : 'Cleared today · "${habit.name}"',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
