# Screen 34 — Settings › Backup & Sync

**Design file:** `design/34_backup_sync.png`  ·  **Route:** `/settings/backup`  ·  **Feature folder:** `lib/features/backup/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 34 — Settings › Backup & Sync in Flutter exactly as shown in `design/34_backup_sync.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Google Drive connection, sync status, automatic and local backups, history and restore.

## Layout (top → bottom)
1. Drive card: Drive logo tile, 'Google Drive', account email, CONNECTED badge; status box 'Everything is backed up · Last sync 2 min ago · 113 items'; app-folder usage bar; buttons **Sync now** (primary) and **Restore**.
2. AUTOMATIC BACKUP: Auto backup to Drive, Frequency (Daily · 9:00 PM), Wi-Fi only, Encrypt backups, Keep last 10 backups.
3. LOCAL BACKUP: Back up to device now, Backup location (Documents/FocusFlow), Auto local backup (Weekly).
4. HISTORY: rows (Drive/local icon, date, location · size · auto) with ⋯ menu (Restore, Download, Delete).
5. 'Disconnect Google account' (rose).

## Interactions & behaviour
- Sync now: build .ffbackup → upload to appDataFolder → prune old → merge remote changes (LWW per item). Show progress states: Preparing… Uploading 40%… Done.
- Restore: pick backup → preview counts → choose Merge or Replace → requires PIN if encrypted.
- Errors: offline, token expired (re-auth silently, else prompt), quota.

## States
- Not connected: big 'Connect Google Drive' card with benefits.
- Syncing, error, conflict summary ('3 items updated from another device').

## Data & state
- `backupServiceProvider`, `driveClientProvider`, `syncStatusProvider` (stream).

## Navigation
- From Settings / Account card.

## Acceptance checklist
- [ ] Round-trip test: backup → wipe → restore yields identical DB.
- [ ] Background auto-backup runs via workmanager.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
