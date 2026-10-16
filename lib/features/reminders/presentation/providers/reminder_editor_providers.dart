/// ============================================================
/// REMINDER EDITOR PROVIDERS — live lookups for the editor's pickers
/// ============================================================
///
/// What: tasks the "Link to › Task or note" picker can link (live,
/// filtered by the search text). Notes reuse `linkableNotesProvider` from
/// the task editor.
/// Why: pickers read repositories only through providers.
/// ============================================================
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:focusflow/features/tasks/domain/entities/task_item.dart';
import 'package:focusflow/features/tasks/domain/repository/tasks_repository.dart';
import 'package:focusflow/shared/providers/repository_providers.dart';

/// Active tasks matching the search text (open and completed).
final linkableTasksProvider = StreamProvider.autoDispose
    .family<List<TaskItem>, String>(
      (ref, text) => ref
          .watch(tasksRepositoryProvider)
          .watchTasks(TasksQuery(text: text.trim(), limit: 60)),
    );
