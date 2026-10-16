/// ============================================================
/// HABIT DAY LOG SHEET — edit one day of a habit (detail heatmap / history)
/// ============================================================
///
/// "Tap heatmap cell → bottom sheet to edit that day's log (count / skip /
/// note)." A stepper sets the count (check-ins, or slips for a quit
/// habit), a switch marks the day skipped, and a note field keeps a short
/// note ("travel day"); while skipped the stepper is disabled. Save writes
/// through saveHabitDay (an all-empty day removes the log) and offers Undo
/// back to the day as it was.
/// ============================================================
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/theme/app_spacing.dart';
import 'package:focusflow/core/theme/app_theme.dart';
import 'package:focusflow/core/utils/date_utils.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/presentation/habit_detail_actions.dart';
import 'package:focusflow/features/habits/presentation/widgets/editor/habit_stepper.dart';

/// Opens the editor for [day] of [habit] ([log] = its current log).
Future<void> showHabitDayLogSheet(
  BuildContext context, {
  required Habit habit,
  required DateTime day,
  required DateTime today,
  HabitLog? log,
}) => showFFBottomSheet<void>(
  context,
  builder: (_) => HabitDayLogSheet(
    habit: habit,
    day: day,
    today: today,
    log: log,
    hostContext: context,
  ),
);

class HabitDayLogSheet extends ConsumerStatefulWidget {
  const HabitDayLogSheet({
    required this.habit,
    required this.day,
    required this.today,
    required this.hostContext,
    this.log,
    super.key,
  });

  final Habit habit;
  final DateTime day;
  final DateTime today;
  final HabitLog? log;

  /// Where the Undo snackbar goes once the sheet has closed.
  final BuildContext hostContext;

  @override
  ConsumerState<HabitDayLogSheet> createState() => _HabitDayLogSheetState();
}

class _HabitDayLogSheetState extends ConsumerState<HabitDayLogSheet> {
  late int _count = widget.log?.count ?? 0;
  late bool _skipped = widget.log?.skipped ?? false;
  late final _note = TextEditingController(text: widget.log?.note ?? '');

  int get _max {
    final goal = widget.habit.targetCount * 10;
    return goal < 99 ? 99 : goal;
  }

  @override
  void dispose() {
    _note.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    // The detail screen underneath hosts the Undo snackbar.
    final host = widget.hostContext;
    Navigator.of(context).pop();
    await saveHabitDay(
      host,
      ref,
      widget.habit,
      widget.day,
      count: _skipped ? 0 : _count,
      skipped: _skipped,
      note: _note.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final habit = widget.habit;
    final text = context.text;
    final unit = habit.isQuit ? 'Slips' : 'Count (${habit.unit})';
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          DateUtilsX.relativeDay(widget.day, widget.today),
          style: text.title,
        ),
        const SizedBox(height: AppSpacing.xs),
        Text(
          habit.isQuit
              ? '${habit.name} · slips that day'
              : '${habit.name} · goal ${habit.targetCount} ${habit.unit}',
          style: text.bodySmall,
        ),
        const SizedBox(height: AppSpacing.lg),
        FFGroupedList(
          children: [
            Padding(
              padding: const EdgeInsetsDirectional.symmetric(
                horizontal: AppSpacing.lg,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Expanded(child: Text(unit, style: text.rowTitle)),
                  HabitStepper(
                    value: _count,
                    min: 0,
                    max: _max,
                    semanticLabel: unit,
                    onChanged: _skipped
                        ? null
                        : (v) => setState(() => _count = v),
                  ),
                ],
              ),
            ),
            FFListRow.toggle(
              title: 'Skipped (rest day)',
              value: _skipped,
              onChanged: (v) => setState(() => _skipped = v),
            ),
          ],
        ),
        const SizedBox(height: AppSpacing.lg),
        TextField(
          controller: _note,
          maxLength: 120,
          textCapitalization: TextCapitalization.sentences,
          decoration: const InputDecoration(hintText: 'Note (optional)'),
        ),
        const SizedBox(height: AppSpacing.md),
        FFPrimaryButton(label: 'Save', onPressed: _save),
      ],
    );
  }
}
