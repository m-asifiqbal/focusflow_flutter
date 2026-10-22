/// ============================================================
/// HABIT CHECK-IN ACTIONS — UI feedback around HabitLogger writes
/// ============================================================
///
/// Shared by the habit card button, the swipe "Log" action and the
/// item-actions "Log today" row so all three feel the same: a light haptic
/// on progress (Settings › Haptics), a selection click on undo, and an
/// Undo snackbar when a quit habit's slip resets the streak.
/// ============================================================
library;

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/ff_snackbar.dart';
import 'package:focusflow/features/habits/domain/entities/habit_day_status.dart';
import 'package:focusflow/features/habits/presentation/providers/habit_logger_provider.dart';
import 'package:focusflow/shared/providers/settings_provider.dart';

/// The card's round button (tap): +1 / undo / toggle for [status].
Future<void> checkInHabit(
  BuildContext context,
  WidgetRef ref,
  HabitDayStatus status,
) async {
  final logger = ref.read(habitLoggerProvider);
  final before = status.log;
  final outcome = await logger.tap(status);
  habitHaptic(ref, outcome);
  if (outcome == HabitLogOutcome.slipped && context.mounted) {
    showUndoSnackbar(
      context,
      message: tr('Slip logged · "{name}" streak reset', {
        'name': status.habit.name,
      }),
      icon: FontAwesomeIcons.rotateLeft,
      onUndo: () => logger.undo(status.habit, before),
    );
  }
}

/// Swipe "Log" / sheet "Log today" for [habitId]. Never removes progress;
/// tells the user when there was nothing left to log.
Future<void> logHabitToday(
  BuildContext context,
  WidgetRef ref,
  String habitId,
) async {
  final outcome = await ref.read(habitLoggerProvider).logToday(habitId);
  habitHaptic(ref, outcome);
  if (!context.mounted) return;
  if (outcome == HabitLogOutcome.unchanged) {
    showFFToast(
      context,
      tr('Already done today'),
      icon: FontAwesomeIcons.solidCircleCheck,
    );
  }
}

/// Haptic feedback for a check-in [outcome], when haptics are enabled.
void habitHaptic(WidgetRef ref, HabitLogOutcome outcome) {
  if (!ref.read(settingsProvider).hapticsEnabled) return;
  switch (outcome) {
    case HabitLogOutcome.progressed:
      HapticFeedback.lightImpact();
    case HabitLogOutcome.reverted:
      HapticFeedback.selectionClick();
    case HabitLogOutcome.slipped:
      HapticFeedback.mediumImpact();
    case HabitLogOutcome.unchanged:
      break;
  }
}
