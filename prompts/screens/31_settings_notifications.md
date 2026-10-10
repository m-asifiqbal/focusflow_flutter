# Screen 31 — Settings › Notifications & Reminders

**Design file:** `design/31_settings_notifications.png`  ·  **Route:** `/settings/notifications`  ·  **Feature folder:** `lib/features/settings/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 31 — Settings › Notifications & Reminders in Flutter exactly as shown in `design/31_settings_notifications.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Control all notification types and behaviour.

## Layout (top → bottom)
1. Gradient card 'Allow notifications' + system permission status + switch.
2. DAILY DIGEST: Morning briefing 8:00 AM, Evening review 9:00 PM, Weekly report Sun.
3. BY MODULE switches with subtitles: Reminders, Task due & overdue, Habit check-ins, Streak at risk, Vault security alerts, Backup & sync status.
4. BEHAVIOUR: Quiet hours (two time pills), Default snooze, Show on lock screen (Title only), App icon badge (Overdue count).
5. Footnote about offline scheduling.

## Interactions & behaviour
- Toggling master switch when OS permission denied → open system settings.
- Quiet hours delay non-alarm notifications.
- Time pills open wheel picker sheet.

## States
- Permission denied banner.

## Data & state
- `settingsProvider.notifications`.

## Navigation
- Back to Settings.

## Acceptance checklist
- [ ] Changing digest time reschedules immediately.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
