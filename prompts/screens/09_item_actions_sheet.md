# Screen 09 — Item actions sheet (long-press)

**Design file:** `design/09_item_actions_sheet.png`  ·  **Route:** `modal`  ·  **Feature folder:** `lib/features/core/widgets/`
**Read first:** `prompts/00_MASTER_PROMPT.md`, `prompts/01_DESIGN_SYSTEM.md`

> Prompt for Claude Code: *"Implement Screen 09 — Item actions sheet (long-press) in Flutter exactly as shown in `design/09_item_actions_sheet.png`, following the spec below and the shared design-system widgets. Wire it to real Riverpod providers and the Drift repositories (no mock data except in widget tests). Add a widget test and a golden test."*

## Purpose
Shared contextual action sheet used for any item in any list (notes shown).

## Layout (top → bottom)
1. Dimmed list behind. Sheet: handle; header row with module icon tile, item title, meta ('Note · Ideas · Edited today'); divider.
2. Action rows (icon in soft tinted tile 38 + label 15.5 w600): Pin to top, Add to favourites, Duplicate, Change colour, Edit tags / move to folder, Set reminder, Share / export (PDF, TXT, MD), Lock with Vault PIN.
3. Two buttons: **Archive** (slate-100 bg) and **Delete** (rose-50 bg, rose-600).

## Interactions & behaviour
- Actions adapt per module: Task → Complete, Change due date, Priority; Reminder → Snooze, Disable; Habit → Log today, Pause; Vault → Copy username/password, Favourite.
- Pin/Favourite toggles label (Unpin…). Archive → Undo snackbar. Delete → confirm dialog (28).
- Implement as `showItemActions(context, ItemRef)` returning results via repository calls.

## States
- Single item and multi-select variant (header '3 items selected').

## Data & state
- `itemActionsProvider(ItemRef)` builds the action list.

## Navigation
- Modal; closes after action.

## Acceptance checklist
- [ ] One reusable widget used by all 5 modules.
- [ ] Visually matches the PNG (spacing, radius, colours, fonts, icons) in light mode; dark mode works from tokens.
- [ ] No overflow at text scale 1.3 and on 360-pt-wide devices; semantics labels on icon buttons.
- [ ] `flutter analyze` clean; widget + golden test added.
