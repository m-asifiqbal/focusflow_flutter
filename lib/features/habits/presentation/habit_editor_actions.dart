/// ============================================================
/// HABIT EDITOR ACTIONS — the editor's confirmations + Undo (screen 15)
/// ============================================================
///
/// What: the dialogs around edits that change what existing history means:
///   changeHabitKind        build ⇄ quit; with history it is only possible
///                          by resetting the history (explicit confirm +
///                          Undo) — a log is a check-in for a build habit
///                          but a slip for a quit habit
///   confirmScheduleChange  new target / frequency / start date on a habit
///                          with history: past days get re-evaluated
///   resetHabitHistory      Manage › Reset history (confirm + Undo)
/// Why here: the screen stays layout-only, and the Undo closures capture
/// the repository + removed logs — never the auto-disposed controller,
/// which is gone once the editor closes (the snackbar outlives it).
/// ============================================================
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/core/l10n/tr.dart';
import 'package:focusflow/core/theme/fa_icons.dart';
import 'package:focusflow/core/widgets/widgets.dart';
import 'package:focusflow/features/habits/domain/entities/habit.dart';
import 'package:focusflow/features/habits/domain/entities/habit_log.dart';
import 'package:focusflow/features/habits/domain/repository/habits_repository.dart';
import 'package:focusflow/features/habits/presentation/notifiers/habit_editor_controller.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Body of the "Change habit type?" dialog for switching [name] to [kind].
String habitKindChangeMessage(String name, HabitKind kind) =>
    kind == HabitKind.quit
    ? tr(
        'A quit habit counts every log as a slip, so the check-ins of "{name}" would turn into slips and its streaks and stats would change. To switch type, its history is reset (you can undo right after).',
        {'name': name},
      )
    : tr(
        'A build habit counts every log as a check-in, so the slips of "{name}" would turn into check-ins and its streaks and stats would change. To switch type, its history is reset (you can undo right after).',
        {'name': name},
      );

/// Body of the "Apply to past days?" dialog ([changes] from
/// HabitEditorState.scheduleChanges).
String habitScheduleChangeMessage(String name, List<String> changes) {
  final list = switch (changes.length) {
    0 => tr('schedule'),
    1 => changes.single,
    2 => tr('{a} and {b}', {'a': changes[0], 'b': changes[1]}),
    _ => tr('{a}, {b} and {c}', {
      'a': changes.sublist(0, changes.length - 2).join(', '),
      'b': changes[changes.length - 2],
      'c': changes.last,
    }),
  };
  return tr(
    'Streaks and stats of "{name}" are recalculated from its history, so past days will be measured against the new {list}. Your check-ins themselves stay as they are.',
    {'name': name, 'list': list},
  );
}

/// Habit type picked in the editor. A new habit, a habit without logs or a
/// switch back to the stored type applies directly; otherwise the user must
/// confirm resetting the history first. Returns whether the draft now has
/// [kind].
Future<bool> changeHabitKind(
  BuildContext context,
  WidgetRef ref,
  HabitEditorArgs args,
  HabitKind kind,
) async {
  final p = habitEditorControllerProvider(args);
  final c = ref.read(p.notifier);
  final original = ref.read(p).valueOrNull?.original;
  if (original == null || kind == original.kind) return c.setKind(kind);
  if (!await c.refreshHistory()) return c.setKind(kind);
  if (!context.mounted) return false;
  final ok = await showFFConfirm(
    context,
    title: tr('Change habit type?'),
    message: habitKindChangeMessage(original.name, kind),
    confirmLabel: tr('Reset & change'),
    destructive: true,
    icon: FontAwesomeIcons.rotateLeft,
  );
  if (!ok || !context.mounted) return false;
  final repo = ref.read(habitsRepositoryProvider);
  final removed = await c.resetHistoryAndSetKind(kind);
  if (context.mounted) {
    _showResetUndo(context, repo, removed, original.name);
  }
  return true;
}

/// Before saving: asks whether past days may be re-evaluated when the
/// goal / schedule / start date of a habit with history changed. True =
/// go ahead (also when nothing needs confirming).
Future<bool> confirmScheduleChange(
  BuildContext context,
  WidgetRef ref,
  HabitEditorArgs args,
) async {
  final p = habitEditorControllerProvider(args);
  final before = ref.read(p).valueOrNull;
  if (before == null || before.scheduleChanges.isEmpty) return true;
  await ref.read(p.notifier).refreshHistory();
  final s = ref.read(p).valueOrNull;
  if (s == null || !s.needsScheduleConfirm) return true;
  if (!context.mounted) return false;
  return showFFConfirm(
    context,
    title: tr('Apply to past days?'),
    message: habitScheduleChangeMessage(
      s.original?.name ?? s.draft.name,
      s.scheduleChanges,
    ),
    confirmLabel: tr('Save'),
    icon: FontAwesomeIcons.calendarCheck,
  );
}

/// Manage › Reset history: confirm, reset, Undo snackbar.
Future<void> resetHabitHistory(
  BuildContext context,
  WidgetRef ref,
  HabitEditorArgs args,
  String name,
) async {
  final ok = await showFFConfirm(
    context,
    title: tr('Reset history?'),
    message: tr('Every check-in of "{name}" will be removed.', {'name': name}),
    confirmLabel: tr('Reset'),
    destructive: true,
    icon: FontAwesomeIcons.rotateLeft,
  );
  if (!ok || !context.mounted) return;
  final repo = ref.read(habitsRepositoryProvider);
  final removed = await ref
      .read(habitEditorControllerProvider(args).notifier)
      .resetHistory();
  if (context.mounted) _showResetUndo(context, repo, removed, name);
}

/// Undo restores [removed] through [repo] in one transaction — independent
/// of the editor (it may be closed when Undo is tapped).
void _showResetUndo(
  BuildContext context,
  HabitsRepository repo,
  List<HabitLog> removed,
  String name,
) => showUndoSnackbar(
  context,
  message: tr('History of "{name}" reset', {'name': name}),
  icon: FontAwesomeIcons.rotateLeft,
  onUndo: () => repo.restoreLogs(removed),
);
