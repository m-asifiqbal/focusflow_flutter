# Screen 11 — Task editor (add / edit)

**Design file:** `design/11_task_editor.png`  ·  **Route:** `/tasks/:id | /tasks/new`  ·  **Feature folder:** `lib/features/tasks/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 11 — Task editor (add / edit) in Flutter exactly as shown in `design/11_task_editor.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Create or edit a task with schedule, repeat, reminder, priority, list/tags, linked note and subtasks.

## Layout (top → bottom)
1. Nav header: Cancel · 'Edit Task' / 'New Task' · Save (disabled until title).
2. Card: title field 20 w600 + notes field (multi-line).
3. SCHEDULE grouped list: Date (emerald value), Time, Repeat ('Weekly · Tue'), Remind me ('15 min before').
4. PRIORITY segmented: Low / Medium (selected = amber-50 bg + amber ring) / High with coloured dots.
5. ORGANISE: List (Work), Tags (#q3 #strategy), Linked note (Q3 Roadmap).
6. SUBTASKS · 2/3 + '+ Add': rows with check circles, drag handles, inline editing.
7. Bottom: Archive & Delete buttons (edit mode only).

## Interactions & behaviour
- Date/time use bottom-sheet pickers in FocusFlow style (not raw Material).
- Repeat sheet: None, Daily, Weekdays, Weekly (choose days), Monthly, Yearly, Custom (every N units, ends never/on date/after N).
- Remind me creates/updates a linked Reminder (scheduled notification).
- Swipe subtask to delete; Enter adds next subtask.
- Cancel with unsaved changes → discard confirmation.

## States
- New (empty), edit, validation (title required).

## Data & state
- `taskEditorController(id)` with form state (freezed).
- `TasksRepository.save(task, subtasks)`; `ReminderScheduler` for notifications.

## Navigation
- Push from Tasks list / Quick Add / Home; pop on save.

## Acceptance checklist
- [ ] Saving updates lists live.
- [ ] Notification scheduled & cancelled correctly when reminder changes.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
