/// ============================================================
/// TASK ACTIONS CONTROLLER — completing, rescheduling, reordering tasks
/// ============================================================
///
/// What: the write side of the Tasks list (screen 10), shared by rows,
/// swipe actions, the long-press sheet and the board:
///   * [TaskCompletionController] — "Tap check → complete (strike + move to
///     Completed after 1.2 s)". The row shows the pending id as done right
///     away; the repository write happens after the delay. Undo cancels a
///     pending completion or reopens the task, discarding the next
///     occurrence a repeating task spawned.
///   * [TaskActions] — reschedule (with undo data), priority, manual
///     reorder inside a section, board column moves.
/// Why: CLAUDE.md rule 5 — no business logic in widgets. Widgets call these
/// and only show snackbars / sheets.
/// ============================================================
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:focusflow/features/tasks/presentation/state/tasks_filter.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Ids of tasks that are visibly "done" but not written yet.
class TaskCompletionController extends Notifier<Set<String>> {
  /// How long a checked row stays in place before it moves to Completed.
  static const Duration delay = Duration(milliseconds: 1200);

  final Map<String, Timer> _timers = {};
  final Map<String, Future<TaskCompletion>> _inFlight = {};
  final Map<String, TaskCompletion> _results = {};

  /// Subtasks the user ticked just before a completion that is waiting to be
  /// written (ticking the last open subtask completes the task): they are
  /// part of the gesture, so Undo gives them back too.
  final Map<String, List<String>> _tickedBefore = {};

  late TasksRepository _repo;

  @override
  Set<String> build() {
    _repo = ref.watch(tasksRepositoryProvider);
    ref.onDispose(() {
      for (final t in _timers.values) {
        t.cancel();
      }
      _timers.clear();
    });
    return const {};
  }

  bool isPending(String id) => state.contains(id);

  /// Completes the open task [id]. With a non-zero [after] the row shows as
  /// done first and the write happens later (pass zero under reduce motion).
  /// [tickedBefore] are subtasks the same gesture has just ticked (the last
  /// open one): Undo and [reopen] give them back with the completion.
  void complete(
    String id, {
    Duration after = delay,
    List<String> tickedBefore = const [],
  }) {
    if (_timers.containsKey(id) || _inFlight.containsKey(id)) return;
    if (tickedBefore.isNotEmpty) _tickedBefore[id] = tickedBefore;
    state = {...state, id};
    if (after == Duration.zero) {
      _write(id);
    } else {
      _timers[id] = Timer(after, () => _write(id));
    }
  }

  Future<void> _write(String id) async {
    _timers.remove(id);
    // Idempotent: if the task was completed elsewhere before the timer
    // fired, this writes nothing (a toggle would reopen it) and Undo then
    // leaves it alone (result.completed is false).
    final future = _repo.complete(id);
    _inFlight[id] = future;
    try {
      final result = await future;
      final ticked = _tickedBefore.remove(id);
      _results[id] = ticked == null ? result : result.withSubtasks(ticked);
    } finally {
      _inFlight.remove(id);
      _tickedBefore.remove(id);
      state = {...state}..remove(id);
    }
  }

  /// Undo of [complete]: cancels a pending completion, or reopens the task
  /// and removes the next occurrence its completion spawned.
  Future<void> undo(String id) async {
    final timer = _timers.remove(id);
    if (timer != null) {
      timer.cancel();
      state = {...state}..remove(id);
      // Nothing was completed yet: only the subtask tick that started the
      // gesture (if any) is given back.
      for (final subtaskId in _tickedBefore.remove(id) ?? const <String>[]) {
        await _repo.setSubtaskDone(subtaskId, false);
      }
      return;
    }
    final inFlight = _inFlight[id];
    if (inFlight != null) await inFlight;
    final result = _results.remove(id);
    if (result != null && !result.completed) return;
    await _repo.uncomplete(
      id,
      discardNextOccurrenceId: result?.nextOccurrenceId,
      reopenSubtaskIds: result?.completedSubtaskIds ?? const [],
    );
  }

  /// Completes [id] right away (board "→ Done") and remembers the result,
  /// so a later [reopen] discards the next occurrence it spawned.
  Future<TaskCompletion> completeNow(String id) async {
    final result = await _repo.complete(id);
    if (result.completed) _results[id] = result;
    return result;
  }

  /// Reopens a completed task (tap on a filled check, swipe Undo, "Mark as
  /// not done", board "Done → To do"). When this session completed a repeating task, the next
  /// occurrence that completion spawned is discarded too — as long as it
  /// is still open and active — so reopening never leaves two open copies.
  ///
  /// Subtasks the completion ticked are un-ticked again, unless [subtasks]
  /// names exactly which ones to open (un-ticking one subtask of a done
  /// task reopens it with only that subtask open).
  Future<void> reopen(String id, {List<String>? subtasks}) async {
    final result = _results.remove(id);
    final spawnedId = result?.nextOccurrenceId;
    String? discard;
    if (spawnedId != null) {
      final spawned = await _repo.getTask(spawnedId);
      if (spawned != null && spawned.isActive && !spawned.isCompleted) {
        discard = spawnedId;
      }
    }
    await _repo.uncomplete(
      id,
      discardNextOccurrenceId: discard,
      reopenSubtaskIds: subtasks ?? result?.completedSubtaskIds ?? const [],
    );
  }
}

final taskCompletionProvider =
    NotifierProvider<TaskCompletionController, Set<String>>(
      TaskCompletionController.new,
    );

/// Previous due dates of rescheduled tasks, for Undo.
typedef RescheduleUndo = Future<void> Function();

/// What a tap on a subtask's check circle did (see
/// [TaskActions.toggleSubtask]).
enum SubtaskOutcome {
  /// Only that subtask changed.
  toggled,

  /// It was the last open subtask: the task is being completed (with the
  /// usual delay), and Undo gives the subtask back too.
  completedTask,

  /// The task was done: it is open again with only that subtask open.
  reopenedTask,

  /// The task is settling after its own completion; nothing was done.
  ignored,
}

class TaskActions {
  const TaskActions(this._repo, this._completion);

  final TasksRepository _repo;

  /// Shared with the list rows, so a board move back out of Done
  /// discards the next occurrence its completion spawned (like Undo).
  final TaskCompletionController _completion;

  /// Moves [tasks] to [day] (time of day kept; null clears the date) and
  /// returns a function restoring their previous dates.
  Future<RescheduleUndo> reschedule(List<TaskItem> tasks, DateTime? day) async {
    final previous = <DateTime?, List<String>>{};
    for (final t in tasks) {
      (previous[t.dueDate] ??= []).add(t.id);
    }
    await _repo.reschedule([for (final t in tasks) t.id], day);
    return () async {
      for (final e in previous.entries) {
        await _repo.reschedule(e.value, e.key);
      }
    };
  }

  Future<void> setPriority(String id, TaskPriority priority) =>
      _repo.setPriority(id, priority);

  /// Ticks / un-ticks [subtask] of [task] from a row or board card. A task
  /// is done exactly when all its subtasks are, so:
  ///  * ticking the last open subtask completes the task — after
  ///    [completeAfter], like a tap on its own check;
  ///  * un-ticking a subtask of a done task (every subtask shows ticked)
  ///    reopens it with just that subtask open;
  ///  * anything else only flips the subtask.
  /// "Last open" is decided by the repository inside the write, never from
  /// [task] (a list snapshot can be a moment stale).
  Future<SubtaskOutcome> toggleSubtask(
    TaskItem task,
    Subtask subtask, {
    Duration completeAfter = TaskCompletionController.delay,
  }) async {
    if (_completion.isPending(task.id)) return SubtaskOutcome.ignored;
    if (task.isCompleted) {
      await _completion.reopen(task.id, subtasks: [subtask.id]);
      return SubtaskOutcome.reopenedTask;
    }
    final change = await _repo.toggleSubtask(subtask.id);
    if (change == null || !change.finishesTask) return SubtaskOutcome.toggled;
    _completion.complete(
      task.id,
      after: completeAfter,
      tickedBefore: [subtask.id],
    );
    return SubtaskOutcome.completedTask;
  }

  /// Persists a drag inside one section. [section] is the order the user
  /// saw; [oldIndex] / [newIndex] follow ReorderableList semantics (the new
  /// index counts the dragged item's old slot). In smart sort the whole
  /// section's visible order is written first, so switching to manual
  /// keeps what the user saw. Returns true when anything changed.
  Future<bool> reorder(
    List<TaskItem> section,
    int oldIndex,
    int newIndex, {
    required TaskSort sort,
    List<TaskItem> visible = const [],
  }) async {
    if (newIndex > oldIndex) newIndex -= 1;
    if (oldIndex == newIndex ||
        oldIndex < 0 ||
        oldIndex >= section.length ||
        newIndex < 0 ||
        newIndex >= section.length) {
      return false;
    }
    final order = [...section];
    final moved = order.removeAt(oldIndex);
    order.insert(newIndex, moved);
    if (sort == TaskSort.smart) {
      // The list switches to manual after this drop: seed sortOrder from
      // what is on screen for *every* section ([visible], flat in display
      // order), not only the dragged one, so the other sections keep their
      // order instead of jumping to stale sortOrders. Only the order within
      // a section matters, so the dragged section goes first.
      final inSection = {for (final t in order) t.id};
      String? previous;
      for (final t in [
        ...order,
        for (final v in visible)
          if (!inSection.contains(v.id)) v,
      ]) {
        await _repo.reorder(t.id, afterId: previous);
        previous = t.id;
      }
      return true;
    }
    await _repo.reorder(
      moved.id,
      afterId: newIndex == 0 ? null : order[newIndex - 1].id,
      beforeId: newIndex == order.length - 1 ? null : order[newIndex + 1].id,
    );
    return true;
  }

  /// Board columns: 0 To do · 1 Doing · 2 Done (= completed). Moving a
  /// repeating task out of Done reopens it the way Undo does: the next
  /// occurrence its completion spawned (still open) is discarded, so the
  /// board never shows two open copies.
  Future<void> moveOnBoard(TaskItem task, int column) async {
    final target = column.clamp(0, 2);
    if (target == 2) {
      if (!task.isCompleted) await _completion.completeNow(task.id);
      return;
    }
    if (task.isCompleted) await _completion.reopen(task.id);
    if (task.boardStatus != target) {
      final fresh = await _repo.getTask(task.id);
      if (fresh != null) await _repo.save(fresh.copyWith(boardStatus: target));
    }
  }
}

final taskActionsProvider = Provider<TaskActions>(
  (ref) => TaskActions(
    ref.watch(tasksRepositoryProvider),
    ref.watch(taskCompletionProvider.notifier),
  ),
);
