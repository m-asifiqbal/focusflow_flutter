# Screen 27 — Notification center

**Design file:** `design/27_notification_center.png`  ·  **Route:** `/notifications`  ·  **Feature folder:** `lib/features/notifications_center/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 27 — Notification center in Flutter exactly as shown in `design/27_notification_center.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
In-app inbox of reminders, overdue tasks, habit nudges, security and sync events with inline actions.

## Layout (top → bottom)
1. Nav header back · 'Notifications' · 'Read all'.
2. Chips: All, Reminders, Tasks, Habits, Security, Sync.
3. TODAY group: unread rows tinted emerald-50 with dot; module tile; title + time; body; inline action buttons (Done / Snooze 10m, Reschedule / View).
4. EARLIER group.

## Interactions & behaviour
- Every fired local notification is also written to `inbox` table.
- Swipe to dismiss; tap opens target item.

## States
- Empty: 'You're all caught up'.

## Data & state
- `inboxProvider(filter)`; unread count drives Home bell dot.

## Navigation
- From Home bell.

## Acceptance checklist
- [ ] Actions perform the same logic as system notification actions.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
