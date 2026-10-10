# Screen 23 — Archive

**Design file:** `design/23_archive.png`  ·  **Route:** `/library/archive`  ·  **Feature folder:** `lib/features/archive/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 23 — Archive in Flutter exactly as shown in `design/23_archive.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
All archived items across modules — hidden from normal lists but kept safe and synced; restorable.

## Layout (top → bottom)
1. Nav header '‹ Library' · 'Archive' · 'Select'.
2. Search 'Search 37 archived items…'.
3. Chips with counts: All 37, Notes 15, Tasks 12, Habits 4, Vault 3.
4. Info banner (emerald-100): explains archive behaviour.
5. Grouped sections by time (THIS MONTH, EARLIER): rows with module icon tile, title, 'Type · archived date', restore button (box-open icon).
6. Bottom: Restore all / Delete all.

## Interactions & behaviour
- Restore → clears archivedAt (habits keep streak; reminders ask to reschedule if past).
- Swipe → Restore / Delete. Select → bulk.
- Vault items require unlock to open/restore.

## States
- Empty: 'Nothing archived yet — swipe left on any item to archive it.'

## Data & state
- `archiveProvider(filter)`.

## Navigation
- From Library or Settings › Archive.

## Acceptance checklist
- [ ] Archived items excluded from search, Home, notifications.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
