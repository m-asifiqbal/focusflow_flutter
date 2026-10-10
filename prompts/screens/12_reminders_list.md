# Screen 12 — Reminders list (timeline)

**Design file:** `design/12_reminders_list.png`  ·  **Route:** `/library/reminders`  ·  **Feature folder:** `lib/features/reminders/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 12 — Reminders list (timeline) in Flutter exactly as shown in `design/12_reminders_list.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
See all reminders in a time-ordered timeline with quick toggles, snooze and done.

## Layout (top → bottom)
1. Large header 'Reminders' + '3 today · next in 25 min'; calendar + more buttons.
2. Week card: 7 days M–S; selected day orange circle filled; dots for days with reminders.
3. Chips: Today, Upcoming, Recurring, Location, Snoozed.
4. Sections MORNING / AFTERNOON & EVENING / TOMORROW.
5. Timeline rows: left column time (15 w700) + AM/PM; card with 4px left border in reminder colour, soft icon tile, title, meta (repeat/linked/location), toggle switch. Done items at 45% opacity with check icon.
6. Next-due reminder card shows inline actions 'SNOOZE 10m' and 'MARK DONE'.

## Interactions & behaviour
- Toggle → enable/disable (cancel/reschedule notification).
- Tap → editor (13). Swipe → Archive/Delete; long-press → actions sheet.
- Overdue (missed) reminders appear in a red 'Missed' section at top with 'Reschedule'.

## States
- Empty state screen 29.
- Notification permission denied → banner 'Notifications are off — Enable'.

## Data & state
- `remindersTimelineProvider(date, filter)`.
- `notificationPermissionProvider`.

## Navigation
- From Library, Home 'All Reminders', notification taps.

## Acceptance checklist
- [ ] Times shown in local timezone; DST-safe scheduling (`timezone` package).
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
