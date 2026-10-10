# Screen 02 — Sign In / Welcome

**Design file:** `design/02_sign_in.png`  ·  **Route:** `/sign-in`  ·  **Feature folder:** `lib/features/auth/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 02 — Sign In / Welcome in Flutter exactly as shown in `design/02_sign_in.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Let the user connect Google (for Drive backup/sync), Apple (iOS only), or continue fully offline.

## Layout (top → bottom)
1. App tile 64×64 radius 20 gradient with bolt.
2. Title 'Welcome to FocusFlow' 30 w700 two lines; body 15.5 inkMuted.
3. White card with 3 benefit rows (soft emerald icon tile 34 + text): encrypted Drive backup, Android & iOS sync, E2E encrypted vault.
4. Buttons stacked (gap 14): **Continue with Google** (white, 1px border, Google 'G' logo), **Continue with Apple** (emerald-950 bg, white; iOS only), **Use offline (local only)** (emerald-50 bg, emerald-700 text).
5. Legal footnote 12.5 with Terms/Privacy links and 'We only request access to the app's own Drive folder.'

## Interactions & behaviour
- Google: `google_sign_in` with scope `drive.appdata` + email/profile. On success store account in secure storage, then check Drive appDataFolder for existing backups → if found show bottom sheet 'Backup found (date, item count) — Restore / Start fresh'.
- Apple sign-in only creates the profile (no Drive); show info that Drive backup needs Google later (Settings › Backup).
- Offline: create local profile with name prompt (optional) and go Home.
- Show loading spinner inside the pressed button; disable others.

## States
- Idle, loading (per button), error snackbar (network / cancelled — cancelled is silent), restore-found sheet.

## Data & state
- `authControllerProvider` (AsyncNotifier) exposing `GoogleAccount?`.
- `driveBackupServiceProvider.listBackups()`.

## Navigation
- → `/home` after success; → `/settings/backup/restore` when user chooses Restore.

## Acceptance checklist
- [ ] Works on Android & iOS with correct OAuth client IDs (document setup in README).
- [ ] Only `drive.appdata` scope requested.
- [ ] Apple button hidden on Android.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
