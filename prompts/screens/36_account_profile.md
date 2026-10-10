# Screen 36 — Settings › Account & profile

**Design file:** `design/36_account_profile.png`  ·  **Route:** `/settings/account`  ·  **Feature folder:** `lib/features/settings/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 36 — Settings › Account & profile in Flutter exactly as shown in `design/36_account_profile.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Profile, linked devices and account-level actions.

## Layout (top → bottom)
1. Nav header with Edit.
2. Avatar 96 with camera badge, name, Google email.
3. Stats card: 113 Items · 45 Best streak · 142 Days active.
4. PROFILE: Display name, Daily focus goal (7 tasks — drives Home hero), Time zone.
5. LINKED DEVICES: rows with device icon, name, OS/last sync, ACTIVE tag or Remove.
6. DANGER ZONE: Sign out, Erase local data (orange), Delete account & Drive data (rose).

## Interactions & behaviour
- Devices list stored in Drive manifest (deviceId, name, lastSync).
- Erase / Delete require typing 'DELETE' + PIN.

## States
- Signed-out variant.

## Data & state
- `accountProvider`.

## Navigation
- From Settings account card.

## Acceptance checklist
- [ ] Delete removes appDataFolder files and local DB.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
