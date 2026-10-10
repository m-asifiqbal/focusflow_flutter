# FocusFlow — Design Kit & Claude Code Prompts

All-in-one productivity app (Flutter · Android + iOS): **Notes · Tasks · Reminders · Habits · Password Vault · Insights · Calendar · Archive/Trash · Settings · Google Drive + local backup**.

Built on the original FocusFlow design language (emerald + mint, Lexend Deca / Nunito Sans, rounded white cards, centre-FAB tab bar, dark-emerald vault) and extended with list screens for every module, archive & trash, global search, calendar, notification centre, full settings and backup/import/export.

## What's inside

```
design/                  37 hi-fi screens, 1170 px wide (390 pt @3x), full-length PNG
design/00_overview_board.png   all screens on one board
prompts/00_MASTER_PROMPT.md    product, stack, architecture, data model, security, sync, build order  ← give this to Claude Code first
prompts/01_DESIGN_SYSTEM.md    colours, type, spacing, radii, shadows, components, motion, dark mode
prompts/screens/NN_*.md        one prompt per screen (layout, behaviour, states, data, navigation, acceptance)
```

## How to use with Claude Code

1. Create the Flutter repo and copy `design/` and `prompts/` into its root.
2. Session 1: *"Read prompts/00_MASTER_PROMPT.md and prompts/01_DESIGN_SYSTEM.md. Do Phase 1 (Foundation)."*
3. Each next session: *"Read the master + design system prompts, then implement screens NN–NN from prompts/screens, matching the PNGs in design/."* Follow the phase order in section 9 of the master prompt.

## Refinements vs. the original concept

- Tab bar is now **Home · Library · [+] · Insights · Settings** — Library is the hub that lists every module (the "list view for all features").
- Every module has a full list screen with search, filter chips, sort, swipe (Archive / Delete), long-press action sheet, multi-select and empty states.
- Shared item lifecycle: Active → **Archive** → **Recently Deleted (30 days)** → gone, with Undo everywhere.
- Quick Add gained **Reminder** and natural-language quick capture ("Pay rent tomorrow 9am").
- Habits got a detail screen (heatmap, streaks, monthly chart); Vault got TOTP codes, card/Wi-Fi types, strength badges and a security score.
- Backup: Google Drive (app-private folder only), encrypted `.ffbackup`, auto backup, local backup, history and restore, plus import from Keep, Todoist, Bitwarden, 1Password, Loop Habit and Evernote.

## Screen index

| # | Screen | Design | Prompt |
|---|---|---|---|
| 01 | Onboarding | `design/01_onboarding.png` | `prompts/screens/01_onboarding.md` |
| 02 | Sign In / Welcome | `design/02_sign_in.png` | `prompts/screens/02_sign_in.md` |
| 03 | Home (Today dashboard) | `design/03_home.png` | `prompts/screens/03_home.md` |
| 04 | Quick Add sheet ('What's next?') | `design/04_quick_add_sheet.png` | `prompts/screens/04_quick_add_sheet.md` |
| 05 | Library (all spaces hub) | `design/05_library.png` | `prompts/screens/05_library.md` |
| 06 | Global Search | `design/06_global_search.png` | `prompts/screens/06_global_search.md` |
| 07 | Notes list | `design/07_notes_list.png` | `prompts/screens/07_notes_list.md` |
| 08 | Note editor | `design/08_note_editor.png` | `prompts/screens/08_note_editor.md` |
| 09 | Item actions sheet (long-press) | `design/09_item_actions_sheet.png` | `prompts/screens/09_item_actions_sheet.md` |
| 10 | Tasks list | `design/10_tasks_list.png` | `prompts/screens/10_tasks_list.md` |
| 11 | Task editor (add / edit) | `design/11_task_editor.png` | `prompts/screens/11_task_editor.md` |
| 12 | Reminders list (timeline) | `design/12_reminders_list.png` | `prompts/screens/12_reminders_list.md` |
| 13 | Reminder editor | `design/13_reminder_editor.png` | `prompts/screens/13_reminder_editor.md` |
| 14 | Habits list | `design/14_habits_list.png` | `prompts/screens/14_habits_list.md` |
| 15 | Habit editor (new / edit) | `design/15_habit_editor.png` | `prompts/screens/15_habit_editor.md` |
| 16 | Habit detail & stats | `design/16_habit_detail.png` | `prompts/screens/16_habit_detail.md` |
| 17 | Vault — locked | `design/17_vault_locked.png` | `prompts/screens/17_vault_locked.md` |
| 18 | Vault — item list | `design/18_vault_list.png` | `prompts/screens/18_vault_list.md` |
| 19 | Vault — item detail | `design/19_vault_item_detail.png` | `prompts/screens/19_vault_item_detail.md` |
| 20 | Vault — add / edit item | `design/20_vault_item_editor.png` | `prompts/screens/20_vault_item_editor.md` |
| 21 | Password generator | `design/21_password_generator.png` | `prompts/screens/21_password_generator.md` |
| 22 | Vault security dashboard | `design/22_security_dashboard.png` | `prompts/screens/22_security_dashboard.md` |
| 23 | Archive | `design/23_archive.png` | `prompts/screens/23_archive.md` |
| 24 | Recently Deleted (Trash) | `design/24_trash.png` | `prompts/screens/24_trash.md` |
| 25 | Insights (analytics) | `design/25_insights.png` | `prompts/screens/25_insights.md` |
| 26 | Calendar | `design/26_calendar.png` | `prompts/screens/26_calendar.md` |
| 27 | Notification center | `design/27_notification_center.png` | `prompts/screens/27_notification_center.md` |
| 28 | Delete confirmation & Undo snackbar | `design/28_delete_confirm.png` | `prompts/screens/28_delete_confirm.md` |
| 29 | Empty state pattern | `design/29_empty_state.png` | `prompts/screens/29_empty_state.md` |
| 30 | Settings (main) | `design/30_settings.png` | `prompts/screens/30_settings.md` |
| 31 | Settings › Notifications & Reminders | `design/31_settings_notifications.png` | `prompts/screens/31_settings_notifications.md` |
| 32 | Settings › Appearance | `design/32_settings_appearance.png` | `prompts/screens/32_settings_appearance.md` |
| 33 | Settings › Vault security | `design/33_settings_vault_security.png` | `prompts/screens/33_settings_vault_security.md` |
| 34 | Settings › Backup & Sync | `design/34_backup_sync.png` | `prompts/screens/34_backup_sync.md` |
| 35 | Settings › Import & Export | `design/35_import_export.png` | `prompts/screens/35_import_export.md` |
| 36 | Settings › Account & profile | `design/36_account_profile.png` | `prompts/screens/36_account_profile.md` |
| 37 | Home — Dark mode reference | `design/37_home_dark.png` | `prompts/screens/37_home_dark.md` |

## Name ideas (FocusFlow is already used by several apps)

| Name | Why it fits |
|---|---|
| **Nestly** | Everything nested in one calm, safe place |
| **Orbit** | Your notes, tasks, habits and secrets all orbit around you |
| **Evergreen** | Matches the emerald look; habits and notes that keep growing |
| **Haven** | Calm workspace with a secure vault at its centre |
| **Daywise** | Smart about your day: tasks, reminders, habits |
| **Mintly** | Fresh, light, ties to the mint palette |
| **OneNest** | Says "all-in-one" directly |
| **Keepwell** | Keep your notes and passwords, and live well with habits |
| **Sprout** | Habits and ideas that grow; friendly and short |
| **Lumo** | Short, brandable, sounds like "light" and clarity |

Check Play Store, App Store, domain and trademark availability before you pick one. To rename, change `app_info.dart` and the strings in the design.
