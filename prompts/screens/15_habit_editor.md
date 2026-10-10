# Screen 15 — Habit editor (new / edit)

**Design file:** `design/15_habit_editor.png`  ·  **Route:** `/habits/:id/edit | /habits/new`  ·  **Feature folder:** `lib/features/habits/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 15 — Habit editor (new / edit) in Flutter exactly as shown in `design/15_habit_editor.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Create/customise a habit: template, icon & colour, category, type, goal, frequency and reminders.

## Layout (top → bottom)
1. Nav header Cancel · 'New Habit' · Create.
2. Preview card: icon tile 64 (habit colour soft), name 21 w600, category tag + '• 8 glasses daily'.
3. QUICK START horizontal templates: Meditate, Read, Exercise, Sleep… (tile 92 wide).
4. DETAILS: Name, Colour (5–8 swatches inline, selected ring), Category (Health), Habit type (Build / Quit).
5. GOAL & SCHEDULE card: Daily target stepper (– 8 + glasses, unit editable), Frequency (Weekdays ›) and day circles M–S (selected filled emerald).
6. REMINDERS: Remind me switch, Times (multiple chips), Start date.

## Interactions & behaviour
- Icon picker bottom sheet: searchable grid of ~150 FA icons + colour palette ('Customize Habit' sheet from original design).
- Frequency options: Every day, Specific days, X times per week, Every N days.
- Template tap fills all fields. Create schedules reminders for each time.

## States
- New, edit (adds Archive/Delete at bottom + 'Reset history').

## Data & state
- `habitEditorController(id)`.

## Navigation
- From Quick Add, Habits list, Habit detail edit.

## Acceptance checklist
- [ ] Changing schedule doesn't corrupt existing logs/streaks.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
