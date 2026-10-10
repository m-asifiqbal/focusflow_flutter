# Screen 24 — Recently Deleted (Trash)

**Design file:** `design/24_trash.png`  ·  **Route:** `/library/trash`  ·  **Feature folder:** `lib/features/archive/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 24 — Recently Deleted (Trash) in Flutter exactly as shown in `design/24_trash.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Soft-deleted items with days-left countdown; recover or delete permanently.

## Layout (top → bottom)
1. Nav header Cancel · 'Recently Deleted' · All.
2. Rose info card 'Auto-deletes after 30 days' + explanation.
3. '2 SELECTED · 5 ITEMS' label.
4. Rows with selection circles (selected rows tinted emerald-50), module tile, title, 'Type · deleted when', right red 'N days'.
5. Sticky bottom bar: Recover (2) (emerald-50) and Delete (2) (rose solid).

## Interactions & behaviour
- Daily purge job deletes items where deletedAt < now-30d (also removes attachments, Drive copy on next sync).
- Permanent delete → confirmation dialog (no undo).

## States
- Empty trash state.

## Data & state
- `trashProvider`.

## Navigation
- From Library / Settings.

## Acceptance checklist
- [ ] Purge job tested with fake clock.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
