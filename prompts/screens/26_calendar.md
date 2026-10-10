# Screen 26 — Calendar

**Design file:** `design/26_calendar.png`  ·  **Route:** `/calendar`  ·  **Feature folder:** `lib/features/calendar/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 26 — Calendar in Flutter exactly as shown in `design/26_calendar.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Month/week/agenda view of tasks, reminders, habits and notes by date.

## Layout (top → bottom)
1. Header: back, 'June 2023', search, + (accent).
2. Segmented Week / Month / Agenda.
3. Month grid card: weekday header, day cells with up to 3 coloured dots (module colours), today filled emerald circle; legend row.
4. Selected-day title 'Tuesday, June 13' + '4 items'.
5. Agenda list: time column + cards with module-colour left border and type label.

## Interactions & behaviour
- Swipe months; tap day → agenda below; long-press day → Quick Add with that date.
- Drag an agenda item to another day in week view (reschedule).

## States
- Empty day: 'Nothing planned · Add'.

## Data & state
- `calendarMonthProvider(month)`, `agendaProvider(date)`.

## Navigation
- From Home 'View Monthly' / Reminders calendar icon.

## Acceptance checklist
- [ ] Week start honours settings.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
