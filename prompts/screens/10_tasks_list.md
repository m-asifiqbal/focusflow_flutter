# Screen 10 — Tasks list

**Design file:** `design/10_tasks_list.png`  ·  **Route:** `/library/tasks`  ·  **Feature folder:** `lib/features/tasks/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 10 — Tasks list in Flutter exactly as shown in `design/10_tasks_list.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Manage tasks with smart sections (Overdue, Today, Upcoming, Completed), priorities, subtasks progress and swipe actions.

## Layout (top → bottom)
1. Large header 'Tasks' + '7 due today · 2 overdue'; view toggle (list/board) + More.
2. Search field.
3. 4 stat tiles (radius 16, tinted): Today (blue), Overdue (red), Upcoming (emerald), Done (slate) — tappable filters.
4. Chips: Today, Upcoming, Work, Personal, (lists…).
5. Section 'OVERDUE · 2' + 'Reschedule all' (rose).
6. Task rows (radius 20): 4px priority bar on left, check circle (module blue), title, meta (time/date, tag, repeat icon, reminder bell), optional subtask progress bar 'n/m subtasks', drag handle.
7. Example of swiped row showing **Archive** (slate) and **Delete** (rose) actions.
8. Sections 'TODAY · 5', 'COMPLETED · 2' (collapsible).

## Interactions & behaviour
- Tap check → complete (strike + move to Completed after 1.2 s; repeating tasks spawn next occurrence).
- Tap row → Task editor (11). Swipe left → Archive/Delete; swipe right → Complete. Long-press → actions sheet; drag handle reorders within section (manual sort).
- 'Reschedule all' → date picker sheet (Today, Tomorrow, Next week, Pick).
- Board view toggle (optional v1.1): columns To do / Doing / Done.

## States
- Empty, all-done celebration ('All done for today 🎉'), filter empty.

## Data & state
- `tasksSectionsProvider(filter)` → {overdue, today, upcoming, completed}.
- `taskStatsProvider`.

## Navigation
- From Library/Home. Back to Library.

## Acceptance checklist
- [ ] Overdue computed in user's timezone.
- [ ] Repeating tasks generate next instance correctly (RRULE unit tests).
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
