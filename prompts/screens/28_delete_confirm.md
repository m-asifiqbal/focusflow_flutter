# Screen 28 — Delete confirmation & Undo snackbar

**Design file:** `design/28_delete_confirm.png`  ·  **Route:** `dialog`  ·  **Feature folder:** `lib/features/core/widgets/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 28 — Delete confirmation & Undo snackbar in Flutter exactly as shown in `design/28_delete_confirm.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Standard confirm dialog for deletion and the dark Undo snackbar pattern.

## Layout (top → bottom)
1. Dimmed screen; dialog (radius 30, white) with rose trash icon in ringed circle, title 'Delete 2 notes?', explanation mentioning Recently Deleted + 30 days.
2. Buttons: Delete (rose solid), Archive instead (emerald-50), Cancel (text).
3. Snackbar (emerald-950, radius 16): archive icon, '"Shopping List" archived', 'UNDO' in emerald-400.

## Interactions & behaviour
- Use one `confirmDelete(context, count, type)` helper.
- Permanent delete (from trash) variant: title 'Delete forever?', no 'Archive instead'.
- Snackbar 5 s, single at a time.

## States
- Single / multiple / permanent.

## Data & state
- —

## Navigation
- Modal.

## Acceptance checklist
- [ ] Used everywhere a delete happens.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
