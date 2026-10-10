# Screen 13 — Reminder editor

**Design file:** `design/13_reminder_editor.png`  ·  **Route:** `/reminders/:id | /reminders/new`  ·  **Feature folder:** `lib/features/reminders/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 13 — Reminder editor in Flutter exactly as shown in `design/13_reminder_editor.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Create or edit a reminder: when, repeat, alert style and links.

## Layout (top → bottom)
1. Nav header Cancel · 'New Reminder' · Save.
2. Card: orange bell tile + title (19 w600) + 'Add a note…'.
3. WHEN: quick chips Today (selected orange) / Tomorrow / Next week / Pick date; iOS-style wheel time picker (hours, minutes, AM/PM) with orange highlight band.
4. REPEAT chips: Once, Daily, Weekdays, Weekly, Monthly, Custom.
5. ALERT grouped list: Sound (Chime), Alarm-style full screen (switch), Default snooze (10 min), Location trigger (Off).
6. LINK TO: Task or note (None).

## Interactions & behaviour
- Alarm-style uses full-screen intent on Android (USE_FULL_SCREEN_INTENT permission) and time-sensitive notification on iOS.
- Location trigger: geofence picker (map + radius slider) — v1.1 behind feature flag.
- Notification actions: Done, Snooze (default), Open.

## States
- New, edit, permission-missing banner, exact-alarm permission prompt on Android 12+.

## Data & state
- `reminderEditorController(id)`; `ReminderScheduler.schedule(reminder)`.

## Navigation
- From Quick Add, Reminders list, Task/Note 'Set reminder'.

## Acceptance checklist
- [ ] Scheduled notification fires at exact time, survives reboot (`RECEIVE_BOOT_COMPLETED` reschedule).
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
